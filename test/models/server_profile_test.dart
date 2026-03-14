import 'package:flutter_test/flutter_test.dart';
import 'package:servershot/models/server_profile.dart';

void main() {
  group('ServerProfile', () {
    test('creates with required fields', () {
      final profile = ServerProfile(
        id: 'test-1',
        name: 'My Server',
        host: '192.168.1.1',
        username: 'root',
      );

      expect(profile.name, 'My Server');
      expect(profile.host, '192.168.1.1');
      expect(profile.port, 22);
      expect(profile.username, 'root');
      expect(profile.password, '');
      expect(profile.selectedServices, isEmpty);
      expect(profile.createUser, false);
      expect(profile.sshUsers, isEmpty);
    });

    test('serializes and deserializes correctly', () {
      final profile = ServerProfile(
        id: 'test-2',
        name: 'Dev Box',
        host: '10.0.0.5',
        port: 2222,
        username: 'admin',
        password: 'secret',
        selectedServices: ['docker', 'git', 'nodejs'],
        credentials: {
          'github_cli': {'github_token': 'ghp_test123'},
        },
        createUser: true,
        deployUsername: 'devuser',
        deployPassword: 'devpass',
        deploySudo: true,
        deploySudoNoPassword: false,
        sshUsers: [
          {'username': 'user1', 'password': 'pass1'},
          {'username': 'user2', 'password': 'pass2'},
        ],
      );

      final json = profile.toJson();
      final restored = ServerProfile.fromJson(json);

      expect(restored.id, profile.id);
      expect(restored.name, profile.name);
      expect(restored.host, profile.host);
      expect(restored.port, profile.port);
      expect(restored.username, profile.username);
      expect(restored.password, profile.password);
      expect(restored.selectedServices, profile.selectedServices);
      expect(restored.credentials['github_cli']!['github_token'], 'ghp_test123');
      expect(restored.createUser, true);
      expect(restored.deployUsername, 'devuser');
      expect(restored.deployPassword, 'devpass');
      expect(restored.deploySudo, true);
      expect(restored.deploySudoNoPassword, false);
      expect(restored.sshUsers.length, 2);
      expect(restored.sshUsers[0]['username'], 'user1');
      expect(restored.sshUsers[1]['password'], 'pass2');
    });

    test('serialize/deserialize roundtrip via string', () {
      final profile = ServerProfile(
        id: 'test-3',
        name: 'Prod',
        host: 'prod.example.com',
        username: 'deploy',
        password: 'p@ss',
        selectedServices: ['docker'],
      );

      final serialized = profile.serialize();
      final restored = ServerProfile.deserialize(serialized);

      expect(restored.id, 'test-3');
      expect(restored.name, 'Prod');
      expect(restored.host, 'prod.example.com');
      expect(restored.password, 'p@ss');
    });

    test('effectiveDeployUser returns deploy user when configured', () {
      final profile = ServerProfile(
        id: 'test-4',
        name: 'Test',
        host: 'host',
        username: 'root',
        createUser: true,
        deployUsername: 'appuser',
      );

      expect(profile.effectiveDeployUser, 'appuser');
    });

    test('effectiveDeployUser returns SSH user when no deploy user', () {
      final profile = ServerProfile(
        id: 'test-5',
        name: 'Test',
        host: 'host',
        username: 'root',
      );

      expect(profile.effectiveDeployUser, 'root');
    });

    test('copyWith creates modified copy', () {
      final original = ServerProfile(
        id: 'test-6',
        name: 'Original',
        host: 'host1',
        username: 'user1',
      );

      final copy = original.copyWith(
        name: 'Modified',
        host: 'host2',
        sshUsers: [
          {'username': 'extra', 'password': 'pass'}
        ],
      );

      expect(copy.id, original.id);
      expect(copy.name, 'Modified');
      expect(copy.host, 'host2');
      expect(copy.username, 'user1');
      expect(copy.sshUsers.length, 1);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'test-7',
        'name': 'Minimal',
        'host': '1.2.3.4',
        'username': 'root',
      };

      final profile = ServerProfile.fromJson(json);
      expect(profile.port, 22);
      expect(profile.password, '');
      expect(profile.selectedServices, isEmpty);
      expect(profile.createUser, false);
      expect(profile.sshUsers, isEmpty);
      expect(profile.deploySudo, true);
      expect(profile.deploySudoNoPassword, true);
    });
  });
}
