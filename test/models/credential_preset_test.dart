import 'package:flutter_test/flutter_test.dart';
import 'package:servershot/models/credential_preset.dart';

void main() {
  group('CredentialPreset', () {
    test('creates with required fields', () {
      final preset = CredentialPreset(
        id: 'p1',
        name: 'Personal',
      );
      expect(preset.name, 'Personal');
      expect(preset.credentials, isEmpty);
    });

    test('serializes and deserializes', () {
      final preset = CredentialPreset(
        id: 'p2',
        name: 'Work',
        credentials: {
          'github_cli': {'github_token': 'ghp_test'},
          'claude_code': {'claude_oauth_token': 'sk-ant-oat01-xxx'},
        },
      );

      final json = preset.toJson();
      final restored = CredentialPreset.fromJson(json);

      expect(restored.id, 'p2');
      expect(restored.name, 'Work');
      expect(restored.credentials['github_cli']!['github_token'], 'ghp_test');
      expect(restored.credentials['claude_code']!['claude_oauth_token'],
          'sk-ant-oat01-xxx');
    });

    test('string roundtrip', () {
      final preset = CredentialPreset(
        id: 'p3',
        name: 'Test',
        credentials: {
          'tailscale': {'tailscale_authkey': 'tskey-xxx'},
        },
      );

      final s = preset.serialize();
      final restored = CredentialPreset.deserialize(s);
      expect(restored.name, 'Test');
      expect(restored.credentials['tailscale']!['tailscale_authkey'], 'tskey-xxx');
    });

    test('handles empty credentials', () {
      final json = {'id': 'p4', 'name': 'Empty'};
      final preset = CredentialPreset.fromJson(json);
      expect(preset.credentials, isEmpty);
    });
  });
}
