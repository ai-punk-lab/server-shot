import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/service_definition.dart';
import '../models/credential_preset.dart';
import '../providers/app_provider.dart';
import '../services/service_registry.dart';
import '../theme/app_theme.dart';

class CredentialsScreen extends StatefulWidget {
  final List<String> selectedServices;
  final Map<String, Map<String, String>> currentCredentials;

  const CredentialsScreen({
    super.key,
    required this.selectedServices,
    required this.currentCredentials,
  });

  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<CredentialsScreen> {
  late Map<String, Map<String, TextEditingController>> _controllers;

  @override
  void initState() {
    super.initState();
    _initControllers(widget.currentCredentials);
  }

  void _initControllers(Map<String, Map<String, String>> creds) {
    _controllers = {};
    for (final id in widget.selectedServices) {
      final service = ServiceRegistry.getById(id);
      if (service == null || service.credentialFields.isEmpty) continue;

      _controllers[id] = {};
      for (final field in service.credentialFields) {
        final existing = creds[id]?[field.key] ?? '';
        _controllers[id]![field.key] = TextEditingController(text: existing);
      }
    }
  }

  void _loadPreset(CredentialPreset preset) {
    for (final entry in _controllers.entries) {
      final serviceId = entry.key;
      final presetCreds = preset.credentials[serviceId];
      if (presetCreds == null) continue;
      for (final fieldEntry in entry.value.entries) {
        final value = presetCreds[fieldEntry.key];
        if (value != null && value.isNotEmpty) {
          fieldEntry.value.text = value;
        }
      }
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loaded "${preset.name}"')),
    );
  }

  Map<String, Map<String, String>> _buildResult() {
    final result = <String, Map<String, String>>{};
    for (final entry in _controllers.entries) {
      result[entry.key] = {};
      for (final fieldEntry in entry.value.entries) {
        result[entry.key]![fieldEntry.key] = fieldEntry.value.text;
      }
    }
    return result;
  }

  @override
  void dispose() {
    for (final map in _controllers.values) {
      for (final ctrl in map.values) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servicesWithCreds = widget.selectedServices
        .map((id) => ServiceRegistry.getById(id))
        .where((s) => s != null && s.credentialFields.isNotEmpty)
        .cast<ServiceDefinition>()
        .toList();

    final presets = context.watch<AppProvider>().presets;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credentials'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _buildResult()),
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Preset buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: presets.isEmpty ? null : () => _showLoadPreset(presets),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: Text(
                    'Load Preset${presets.isNotEmpty ? ' (${presets.length})' : ''}',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentColor,
                    side: BorderSide(color: AppTheme.accentColor.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saveAsPreset,
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Save as Preset'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.seedColor,
                    side: BorderSide(color: AppTheme.seedColor.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            'Global presets let you reuse credentials across servers.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 20),

          ...servicesWithCreds.map((service) {
            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF1A1A2E),
                border: Border.all(
                  color: service.accentColor.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(service.iconChar,
                          style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Text(
                        service.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...service.credentialFields.map((field) {
                    final ctrl = _controllers[service.id]?[field.key];
                    if (ctrl == null) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: ctrl,
                        obscureText: field.isSecret,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          labelText: field.label,
                          hintText: field.hint,
                          prefixIcon: Icon(
                            field.isSecret
                                ? Icons.key_rounded
                                : Icons.text_fields_rounded,
                            size: 18,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showLoadPreset(List<CredentialPreset> presets) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Load Credential Preset',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Existing values will be overwritten',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            ...presets.map((preset) {
              final credCount = preset.credentials.values
                  .expand((m) => m.values)
                  .where((v) => v.isNotEmpty)
                  .length;
              return GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _loadPreset(preset);
                },
                onLongPress: () {
                  Navigator.pop(ctx);
                  _confirmDeletePreset(preset);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppTheme.accentColor.withValues(alpha: 0.08),
                    border: Border.all(
                      color: AppTheme.accentColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.vpn_key_rounded,
                          color: AppTheme.accentColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              preset.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '$credCount credentials configured',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded,
                          color: AppTheme.accentColor.withValues(alpha: 0.5),
                          size: 18),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _saveAsPreset() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Save as Preset'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Save current credentials as a reusable preset for other servers.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Preset Name',
                hintText: 'e.g. Personal, Work, Project X',
                prefixIcon: Icon(Icons.label_rounded, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () {
              if (nameCtrl.text.isEmpty) return;
              final preset = CredentialPreset(
                id: const Uuid().v4(),
                name: nameCtrl.text,
                credentials: _buildResult(),
              );
              context.read<AppProvider>().savePreset(preset);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Preset "${preset.name}" saved')),
              );
            },
            child: Text('Save', style: TextStyle(color: AppTheme.seedColor)),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePreset(CredentialPreset preset) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Preset'),
        content: Text('Delete "${preset.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () {
              context.read<AppProvider>().deletePreset(preset.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );
  }
}
