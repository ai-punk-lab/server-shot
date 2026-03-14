import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';

enum SSHConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class SSHService {
  SSHClient? _client;
  SSHConnectionState _state = SSHConnectionState.disconnected;
  String? _lastError;

  SSHConnectionState get state => _state;
  String? get lastError => _lastError;
  bool get isConnected => _state == SSHConnectionState.connected;

  Future<bool> connect({
    required String host,
    required int port,
    required String username,
    String? password,
    String? privateKey,
  }) async {
    try {
      _state = SSHConnectionState.connecting;
      _lastError = null;

      final socket = await SSHSocket.connect(host, port,
          timeout: const Duration(seconds: 15));

      _client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: password != null ? () => password : null,
        identities: privateKey != null
            ? [
                ...SSHKeyPair.fromPem(privateKey),
              ]
            : null,
      );

      // Wait for authentication
      await _client!.authenticated;
      _state = SSHConnectionState.connected;
      return true;
    } catch (e) {
      _state = SSHConnectionState.error;
      _lastError = e.toString();
      return false;
    }
  }

  Future<void> disconnect() async {
    _client?.close();
    _client = null;
    _state = SSHConnectionState.disconnected;
  }

  /// Execute a command and stream output line by line
  Stream<String> executeStream(String command) async* {
    if (_client == null) {
      yield '[ERROR] Not connected to SSH server';
      return;
    }

    try {
      final session = await _client!.execute(command);

      // Stream stdout
      final stdoutStream = session.stdout
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter());

      final stderrStream = session.stderr
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter());

      // Merge stdout and stderr
      await for (final line in _mergeStreams(stdoutStream, stderrStream)) {
        yield line;
      }

      // Wait for exit
      await session.done;
      final exitCode = session.exitCode;
      if (exitCode != null && exitCode != 0) {
        yield '[EXIT CODE: $exitCode]';
      }
    } catch (e) {
      yield '[ERROR] ${e.toString()}';
    }
  }

  /// Execute a command and return full output
  Future<String> execute(String command) async {
    final buffer = StringBuffer();
    await for (final line in executeStream(command)) {
      buffer.writeln(line);
    }
    return buffer.toString().trim();
  }

  /// Test connection
  Future<String?> testConnection({
    required String host,
    required int port,
    required String username,
    String? password,
    String? privateKey,
  }) async {
    try {
      final connected = await connect(
        host: host,
        port: port,
        username: username,
        password: password,
        privateKey: privateKey,
      );

      if (!connected) {
        return _lastError ?? 'Connection failed';
      }

      await execute('uname -a');
      await disconnect();
      return null; // null means success
    } catch (e) {
      await disconnect();
      return e.toString();
    }
  }

  Stream<String> _mergeStreams(
      Stream<String> stream1, Stream<String> stream2) {
    final controller = StreamController<String>();
    int activeStreams = 2;

    void onDone() {
      activeStreams--;
      if (activeStreams == 0) {
        controller.close();
      }
    }

    stream1.listen(
      controller.add,
      onError: controller.addError,
      onDone: onDone,
    );

    stream2.listen(
      controller.add,
      onError: controller.addError,
      onDone: onDone,
    );

    return controller.stream;
  }
}
