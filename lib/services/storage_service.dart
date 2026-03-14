import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/server_profile.dart';
import '../models/credential_preset.dart';

class StorageService {
  static const _profilesKey = 'server_profiles';
  static const _presetsKey = 'credential_presets';
  static const _deployLogsKey = 'deploy_logs';
  static const _onboardingKey = 'onboarding_done';
  static const _appLockKey = 'app_lock_enabled';

  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // --- Server Profiles ---

  Future<List<ServerProfile>> getProfiles() async {
    final data = await _secure.read(key: _profilesKey);
    if (data == null || data.isEmpty) return [];
    final list = jsonDecode(data) as List<dynamic>;
    return list
        .map((e) => ServerProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveProfile(ServerProfile profile) async {
    final profiles = await getProfiles();
    final index = profiles.indexWhere((p) => p.id == profile.id);
    if (index >= 0) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }
    await _saveAllProfiles(profiles);
  }

  Future<void> deleteProfile(String id) async {
    final profiles = await getProfiles();
    profiles.removeWhere((p) => p.id == id);
    await _saveAllProfiles(profiles);
  }

  Future<void> _saveAllProfiles(List<ServerProfile> profiles) async {
    final data = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await _secure.write(key: _profilesKey, value: data);
  }

  // --- Credential Presets ---

  Future<List<CredentialPreset>> getPresets() async {
    final data = await _secure.read(key: _presetsKey);
    if (data == null || data.isEmpty) return [];
    final list = jsonDecode(data) as List<dynamic>;
    return list
        .map((e) => CredentialPreset.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> savePreset(CredentialPreset preset) async {
    final presets = await getPresets();
    final index = presets.indexWhere((p) => p.id == preset.id);
    if (index >= 0) {
      presets[index] = preset;
    } else {
      presets.add(preset);
    }
    await _saveAllPresets(presets);
  }

  Future<void> deletePreset(String id) async {
    final presets = await getPresets();
    presets.removeWhere((p) => p.id == id);
    await _saveAllPresets(presets);
  }

  Future<void> _saveAllPresets(List<CredentialPreset> presets) async {
    final data = jsonEncode(presets.map((p) => p.toJson()).toList());
    await _secure.write(key: _presetsKey, value: data);
  }

  // --- Deploy Logs ---

  Future<Map<String, List<String>>> getDeployLogs() async {
    final data = await _secure.read(key: _deployLogsKey);
    if (data == null || data.isEmpty) return {};
    final map = jsonDecode(data) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, List<String>.from(v as List)));
  }

  Future<void> saveDeployLog(String profileId, List<String> log) async {
    final logs = await getDeployLogs();
    logs[profileId] = log;
    // Keep only last 5 per server
    if (logs[profileId]!.length > 5000) {
      logs[profileId] = logs[profileId]!.sublist(logs[profileId]!.length - 5000);
    }
    await _secure.write(key: _deployLogsKey, value: jsonEncode(logs));
  }

  // --- Settings ---

  Future<bool> isOnboardingDone() async {
    return (await _secure.read(key: _onboardingKey)) == 'true';
  }

  Future<void> setOnboardingDone() async {
    await _secure.write(key: _onboardingKey, value: 'true');
  }

  Future<bool> isAppLockEnabled() async {
    return (await _secure.read(key: _appLockKey)) == 'true';
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    await _secure.write(key: _appLockKey, value: enabled.toString());
  }

  static const _pinKey = 'app_pin';

  Future<String?> getPin() async {
    return await _secure.read(key: _pinKey);
  }

  Future<void> setPin(String pin) async {
    await _secure.write(key: _pinKey, value: pin);
  }

  Future<void> clearPin() async {
    await _secure.delete(key: _pinKey);
  }

  // --- Export / Import ---

  Future<String> exportAll() async {
    final profiles = await getProfiles();
    final presets = await getPresets();
    return jsonEncode({
      'version': 1,
      'profiles': profiles.map((p) => p.toJson()).toList(),
      'presets': presets.map((p) => p.toJson()).toList(),
    });
  }

  Future<void> importAll(String jsonData) async {
    final data = jsonDecode(jsonData) as Map<String, dynamic>;
    if (data['profiles'] != null) {
      final profiles = (data['profiles'] as List)
          .map((e) => ServerProfile.fromJson(e as Map<String, dynamic>))
          .toList();
      await _saveAllProfiles(profiles);
    }
    if (data['presets'] != null) {
      final presets = (data['presets'] as List)
          .map((e) => CredentialPreset.fromJson(e as Map<String, dynamic>))
          .toList();
      await _saveAllPresets(presets);
    }
  }
}
