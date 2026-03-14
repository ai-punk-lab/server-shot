import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/server_profile.dart';
import '../models/credential_preset.dart';
import '../services/storage_service.dart';

class AppProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  List<ServerProfile> _profiles = [];
  List<CredentialPreset> _presets = [];
  bool _initialized = false;

  List<ServerProfile> get profiles => _profiles;
  List<CredentialPreset> get presets => _presets;
  bool get initialized => _initialized;

  Future<void> init() async {
    _profiles = await _storage.getProfiles();
    _presets = await _storage.getPresets();
    _initialized = true;
    notifyListeners();
  }

  // --- Profiles ---

  Future<ServerProfile> createProfile({
    required String name,
    required String host,
    required int port,
    required String username,
    required String password,
    String? privateKey,
  }) async {
    final profile = ServerProfile(
      id: const Uuid().v4(),
      name: name,
      host: host,
      port: port,
      username: username,
      password: password,
      privateKey: privateKey,
    );
    await _storage.saveProfile(profile);
    _profiles = await _storage.getProfiles();
    notifyListeners();
    return profile;
  }

  Future<void> updateProfile(ServerProfile profile) async {
    await _storage.saveProfile(profile);
    _profiles = await _storage.getProfiles();
    notifyListeners();
  }

  Future<void> deleteProfile(String id) async {
    await _storage.deleteProfile(id);
    _profiles = await _storage.getProfiles();
    notifyListeners();
  }

  ServerProfile? getProfile(String id) {
    try {
      return _profiles.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // --- Credential Presets ---

  Future<void> savePreset(CredentialPreset preset) async {
    await _storage.savePreset(preset);
    _presets = await _storage.getPresets();
    notifyListeners();
  }

  Future<void> deletePreset(String id) async {
    await _storage.deletePreset(id);
    _presets = await _storage.getPresets();
    notifyListeners();
  }
}
