import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:local_auth/local_auth.dart';
import '../providers/app_provider.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'pin_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _storage = StorageService();
  final _localAuth = LocalAuthentication();
  bool _appLockEnabled = false;
  bool _canBiometric = false;
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _appLockEnabled = await _storage.isAppLockEnabled();
    _canBiometric = await _localAuth.canCheckBiometrics ||
        await _localAuth.isDeviceSupported();
    final pin = await _storage.getPin();
    _hasPin = pin != null && pin.isNotEmpty;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('SECURITY'),

          // Biometric lock (if supported)
          if (_canBiometric)
            _settingTile(
              icon: Icons.fingerprint_rounded,
              title: 'Biometric Lock',
              subtitle: 'Fingerprint or face to unlock',
              trailing: Switch(
                value: _appLockEnabled && !_hasPin,
                onChanged: (v) async {
                  if (v) {
                    final authed = await _localAuth.authenticate(
                      localizedReason: 'Enable app lock',
                    );
                    if (!authed) return;
                    await _storage.clearPin();
                  }
                  await _storage.setAppLockEnabled(v);
                  await _loadSettings();
                },
              ),
            ),

          // PIN lock (always available)
          _settingTile(
            icon: Icons.pin_rounded,
            title: 'PIN Lock',
            subtitle: _hasPin ? 'PIN is set' : 'Set a 4-digit PIN to lock the app',
            trailing: Switch(
              value: _hasPin,
              onChanged: (v) async {
                if (v) {
                  // Set new PIN
                  if (!mounted) return;
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PinScreen(
                        title: 'Set PIN',
                        subtitle: 'Choose a 4-digit PIN',
                        isSetup: true,
                        onSubmit: (pin) async {
                          await _storage.setPin(pin);
                          await _storage.setAppLockEnabled(true);
                          if (context.mounted) Navigator.pop(context, true);
                          return true;
                        },
                      ),
                    ),
                  );
                  if (result == true) await _loadSettings();
                } else {
                  // Remove PIN
                  await _storage.clearPin();
                  await _storage.setAppLockEnabled(false);
                  await _loadSettings();
                }
              },
            ),
          ),

          const SizedBox(height: 24),
          _sectionHeader('DATA'),
          _settingTile(
            icon: Icons.upload_rounded,
            title: 'Export Profiles',
            subtitle: 'Save all servers & presets to file',
            onTap: _exportProfiles,
          ),
          _settingTile(
            icon: Icons.download_rounded,
            title: 'Import Profiles',
            subtitle: 'Load servers & presets from file',
            onTap: _importProfiles,
          ),

          const SizedBox(height: 24),
          _sectionHeader('ABOUT'),
          _settingTile(
            icon: Icons.info_outline_rounded,
            title: 'ServerShot',
            subtitle: 'v1.0.0 — Built with Claude Code',
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1A1A2E),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.seedColor, size: 22),
        title: Text(title, style: const TextStyle(fontSize: 14)),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withValues(alpha: 0.4)))
            : null,
        trailing: trailing,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _exportProfiles() async {
    try {
      final json = await _storage.exportAll();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/servershot_backup.json');
      await file.writeAsString(json);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported to ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _importProfiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      final json = await file.readAsString();
      await _storage.importAll(json);

      if (!mounted) return;
      final provider = context.read<AppProvider>();
      await provider.init();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profiles imported successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }
}
