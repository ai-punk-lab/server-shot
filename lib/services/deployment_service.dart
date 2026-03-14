import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/server_profile.dart';
import 'ssh_service.dart';
import 'service_registry.dart';
import 'script_helpers.dart';
import 'storage_service.dart';

enum DeploymentStatus {
  idle,
  connecting,
  deploying,
  completed,
  failed,
}

class ServiceDeploymentState {
  final String serviceId;
  final String serviceName;
  DeploymentStatus status;
  String output;
  String? error;
  DateTime? startedAt;
  DateTime? completedAt;

  ServiceDeploymentState({
    required this.serviceId,
    required this.serviceName,
    this.status = DeploymentStatus.idle,
    this.output = '',
    this.error,
    this.startedAt,
    this.completedAt,
  });

  Duration? get duration {
    if (startedAt == null) return null;
    final end = completedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }
}

class DeploymentState {
  DeploymentStatus overallStatus;
  List<ServiceDeploymentState> services;
  String? currentServiceId;
  int completedCount;
  int totalCount;
  final List<String> globalLog;

  DeploymentState({
    this.overallStatus = DeploymentStatus.idle,
    this.services = const [],
    this.currentServiceId,
    this.completedCount = 0,
    this.totalCount = 0,
    List<String>? globalLog,
  }) : globalLog = globalLog ?? [];

  double get progress =>
      totalCount > 0 ? completedCount / totalCount : 0.0;

  String? get currentServiceName {
    if (currentServiceId == null) return null;
    try {
      return services
          .firstWhere((s) => s.serviceId == currentServiceId)
          .serviceName;
    } catch (_) {
      return null;
    }
  }
}

class DeploymentService extends ChangeNotifier {
  final SSHService _ssh = SSHService();
  DeploymentState _state = DeploymentState();
  final StreamController<String> _logController =
      StreamController<String>.broadcast();

  DeploymentState get state => _state;
  Stream<String> get logStream => _logController.stream;

  void _log(String message) {
    _state.globalLog.add(message);
    _logController.add(message);
    notifyListeners();
  }

  Future<void> deploy(ServerProfile profile) async {
    // Resolve dependencies and order
    final orderedIds =
        ServiceRegistry.resolveDependencies(profile.selectedServices);

    _state = DeploymentState(
      overallStatus: DeploymentStatus.connecting,
      totalCount: orderedIds.length,
      services: orderedIds.map((id) {
        final svc = ServiceRegistry.getById(id);
        return ServiceDeploymentState(
          serviceId: id,
          serviceName: svc?.name ?? id,
        );
      }).toList(),
    );
    notifyListeners();

    _log('🔌 Connecting to ${profile.host}:${profile.port}...');

    // Connect
    final connected = await _ssh.connect(
      host: profile.host,
      port: profile.port,
      username: profile.username,
      password: profile.password,
      privateKey: profile.privateKey,
    );

    if (!connected) {
      _state.overallStatus = DeploymentStatus.failed;
      _log('❌ Connection failed: ${_ssh.lastError}');
      notifyListeners();
      return;
    }

    _log('✅ Connected to ${profile.host}');

    // Get system info
    final sysInfo = await _ssh.execute('uname -a');
    _log('📋 System: $sysInfo');

    // Ensure prerequisites (cross-platform)
    _log('📦 Ensuring prerequisites (curl, wget, sudo)...');
    final prereqScript = '$osDetectPreamble\n\$PKG_UPDATE\npkg_install curl wget sudo ca-certificates gnupg';
    final prereqCmd = 'echo "${base64Encode(utf8.encode(prereqScript))}" | base64 -d | bash';
    await _ssh.execute(prereqCmd);

    _state.overallStatus = DeploymentStatus.deploying;
    notifyListeners();

    // Create user if requested
    final deployUser = profile.effectiveDeployUser;
    if (profile.createUser &&
        profile.deployUsername != null &&
        profile.deployUsername!.isNotEmpty) {
      _log('');
      _log('━━━ 👤 Creating user "${profile.deployUsername}" ━━━');
      notifyListeners();

      try {
        final user = profile.deployUsername!;
        final pass = profile.deployPassword ?? '';

        // Create user with home directory and bash shell
        final createScript = StringBuffer();
        createScript.writeln('set -e');
        createScript.writeln('if id "$user" &>/dev/null; then');
        createScript.writeln('  echo "User $user already exists"');
        createScript.writeln('else');
        createScript.writeln('  useradd -m -s /bin/bash "$user"');
        createScript.writeln('  echo "User $user created"');
        createScript.writeln('fi');

        if (pass.isNotEmpty) {
          createScript.writeln('echo "$user:$pass" | chpasswd');
          createScript.writeln('echo "Password set for $user"');
        }

        if (profile.deploySudo) {
          createScript.writeln('usermod -aG sudo "$user" 2>/dev/null || usermod -aG wheel "$user" 2>/dev/null || true');
          if (profile.deploySudoNoPassword) {
            createScript.writeln('echo "$user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$user');
            createScript.writeln('chmod 440 /etc/sudoers.d/$user');
            createScript.writeln('echo "Passwordless sudo configured for $user"');
          } else {
            createScript.writeln('echo "$user ALL=(ALL) ALL" > /etc/sudoers.d/$user');
            createScript.writeln('chmod 440 /etc/sudoers.d/$user');
            createScript.writeln('echo "Sudo with password configured for $user"');
          }
        }

        createScript.writeln('echo "User setup complete for $user"');

        final encoded = base64Encode(utf8.encode(createScript.toString()));
        final cmd = 'echo "$encoded" | base64 -d | bash';
        await for (final line in _ssh.executeStream(cmd)) {
          _log(line);
        }
        _log('✅ User "$user" ready');
      } catch (e) {
        _log('❌ User creation failed: $e');
        _state.overallStatus = DeploymentStatus.failed;
        await _ssh.disconnect();
        _log('🔌 Disconnected');
        notifyListeners();
        return;
      }
    }

    // Determine if we run as a different user
    final bool runAsOtherUser = profile.createUser &&
        profile.deployUsername != null &&
        profile.deployUsername!.isNotEmpty &&
        profile.username != profile.deployUsername;

    // Helper to encode script as base64 and execute safely
    // Prepends OS detection preamble to every script
    String wrapScript(String script) {
      final fullScript = '$osDetectPreamble\n$script';
      final encoded = base64Encode(utf8.encode(fullScript));
      if (runAsOtherUser) {
        return 'echo "$encoded" | base64 -d | sudo -i -u ${profile.deployUsername} -- bash';
      } else {
        return 'echo "$encoded" | base64 -d | bash';
      }
    }

    // Deploy each service
    bool hadError = false;
    for (int i = 0; i < orderedIds.length; i++) {
      final serviceId = orderedIds[i];
      final service = ServiceRegistry.getById(serviceId);
      if (service == null) continue;

      final serviceState =
          _state.services.firstWhere((s) => s.serviceId == serviceId);
      serviceState.status = DeploymentStatus.deploying;
      serviceState.startedAt = DateTime.now();
      _state.currentServiceId = serviceId;

      _log('');
      _log('━━━ ${service.iconChar} Installing ${service.name} [${i + 1}/${orderedIds.length}] ━━━');
      if (runAsOtherUser) {
        _log('    (as user: $deployUser)');
      }
      notifyListeners();

      try {
        final creds = profile.credentials[serviceId] ?? {};
        final script = service.installScript(creds);
        final command = wrapScript(script);

        await for (final line in _ssh.executeStream(command)) {
          serviceState.output += '$line\n';
          _log(line);
        }

        serviceState.status = DeploymentStatus.completed;
        serviceState.completedAt = DateTime.now();
        _state.completedCount++;
        _log('✅ ${service.name} installed (${serviceState.duration?.inSeconds}s)');
      } catch (e) {
        serviceState.status = DeploymentStatus.failed;
        serviceState.error = e.toString();
        serviceState.completedAt = DateTime.now();
        _state.completedCount++;
        hadError = true;
        _log('❌ ${service.name} failed: $e');
      }
      notifyListeners();
    }

    _state.overallStatus =
        hadError ? DeploymentStatus.failed : DeploymentStatus.completed;
    _state.currentServiceId = null;

    _log('');
    if (hadError) {
      _log('⚠️ Deployment completed with errors');
    } else {
      _log('🎉 All services deployed successfully!');
    }

    await _ssh.disconnect();
    _log('🔌 Disconnected');
    notifyListeners();

    // Save deploy log
    try {
      final storage = StorageService();
      await storage.saveDeployLog(profile.id, _state.globalLog);
    } catch (_) {}
  }

  Future<void> reset() async {
    await _ssh.disconnect();
    _state = DeploymentState();
    notifyListeners();
  }

  @override
  void dispose() {
    _logController.close();
    _ssh.disconnect();
    super.dispose();
  }
}
