import 'package:flutter_test/flutter_test.dart';
import 'package:servershot/services/service_registry.dart';

void main() {
  group('ServiceRegistry', () {
    test('all services are defined', () {
      final services = ServiceRegistry.all;
      expect(services.length, greaterThanOrEqualTo(14));
    });

    test('each service has required fields', () {
      for (final service in ServiceRegistry.all) {
        expect(service.id, isNotEmpty);
        expect(service.name, isNotEmpty);
        expect(service.description, isNotEmpty);
        expect(service.iconChar, isNotEmpty);
      }
    });

    test('getById returns correct service', () {
      final docker = ServiceRegistry.getById('docker');
      expect(docker, isNotNull);
      expect(docker!.name, 'Docker');

      final claude = ServiceRegistry.getById('claude_code');
      expect(claude, isNotNull);
      expect(claude!.name, 'Claude Code');
    });

    test('getById returns null for unknown id', () {
      expect(ServiceRegistry.getById('nonexistent'), isNull);
    });

    test('grouped returns all categories', () {
      final grouped = ServiceRegistry.grouped;
      expect(grouped.isNotEmpty, true);
      // Every service should be in a group
      final totalInGroups =
          grouped.values.fold<int>(0, (sum, list) => sum + list.length);
      expect(totalInGroups, ServiceRegistry.all.length);
    });

    test('resolveDependencies includes deps before dependents', () {
      // claude_code depends on nothing now (native installer)
      // github_cli depends on git
      final resolved = ServiceRegistry.resolveDependencies(['github_cli']);
      expect(resolved.contains('git'), true);
      expect(resolved.indexOf('git'), lessThan(resolved.indexOf('github_cli')));
    });

    test('resolveDependencies handles empty list', () {
      final resolved = ServiceRegistry.resolveDependencies([]);
      expect(resolved, isEmpty);
    });

    test('resolveDependencies deduplicates', () {
      final resolved =
          ServiceRegistry.resolveDependencies(['git', 'github_cli']);
      final gitCount = resolved.where((id) => id == 'git').length;
      expect(gitCount, 1);
    });

    test('install scripts are generated without errors', () {
      for (final service in ServiceRegistry.all) {
        final script = service.installScript({});
        expect(script, isNotEmpty);
        expect(script, contains('echo'));
      }
    });

    test('install scripts inject credentials', () {
      final ghCli = ServiceRegistry.getById('github_cli')!;
      final script =
          ghCli.installScript({'github_token': 'ghp_testtoken123'});
      expect(script, contains('ghp_testtoken123'));
    });

    test('claude_code uses native installer', () {
      final claude = ServiceRegistry.getById('claude_code')!;
      final script = claude.installScript({});
      expect(script, contains('claude.ai/install.sh'));
      expect(script, isNot(contains('npm install')));
    });

    test('claude_code configures OAuth token', () {
      final claude = ServiceRegistry.getById('claude_code')!;
      final script =
          claude.installScript({'claude_oauth_token': 'sk-ant-oat01-test'});
      expect(script, contains('CLAUDE_CODE_OAUTH_TOKEN'));
      expect(script, contains('sk-ant-oat01-test'));
    });

    test('ruby installs via rbenv', () {
      final ruby = ServiceRegistry.getById('ruby');
      expect(ruby, isNotNull);
      final script = ruby!.installScript({});
      expect(script, contains('rbenv'));
      expect(script, contains('ruby-build'));
    });

    test('scripts use cross-platform package manager variables', () {
      // These services should use $PKG_INSTALL or pkg_install
      final crossPlatformServices = ['git', 'python', 'zsh', 'tmux', 'redis'];
      for (final id in crossPlatformServices) {
        final service = ServiceRegistry.getById(id)!;
        final script = service.installScript({});
        final usesPkgVar = script.contains('\$PKG_INSTALL') ||
            script.contains('pkg_install') ||
            script.contains('\$PKG_UPDATE');
        expect(usesPkgVar, true, reason: '$id should use cross-platform pkg vars');
      }
    });

    test('github_cli handles different package managers', () {
      final gh = ServiceRegistry.getById('github_cli')!;
      final script = gh.installScript({});
      expect(script, contains('apt)'));
      expect(script, contains('dnf|yum)'));
      expect(script, contains('pacman)'));
    });

    test('caddy handles different package managers', () {
      final caddy = ServiceRegistry.getById('caddy')!;
      final script = caddy.installScript({});
      expect(script, contains('apt)'));
      expect(script, contains('dnf|yum)'));
      expect(script, contains('pacman)'));
    });

    test('postgresql handles RHEL init', () {
      final pg = ServiceRegistry.getById('postgresql')!;
      final script = pg.installScript({'pg_password': 'test123'});
      expect(script, contains('postgresql-setup'));
      expect(script, contains('test123'));
    });
  });
}
