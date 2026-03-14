import 'package:flutter_test/flutter_test.dart';
import 'package:servershot/services/script_helpers.dart';

void main() {
  group('Script Helpers', () {
    test('osDetectPreamble is not empty', () {
      expect(osDetectPreamble, isNotEmpty);
    });

    test('osDetectPreamble contains detect_pkg_manager function', () {
      expect(osDetectPreamble, contains('detect_pkg_manager'));
    });

    test('osDetectPreamble supports apt', () {
      expect(osDetectPreamble, contains('apt-get'));
    });

    test('osDetectPreamble supports dnf', () {
      expect(osDetectPreamble, contains('dnf'));
    });

    test('osDetectPreamble supports yum', () {
      expect(osDetectPreamble, contains('yum'));
    });

    test('osDetectPreamble supports pacman', () {
      expect(osDetectPreamble, contains('pacman'));
    });

    test('osDetectPreamble supports apk (Alpine)', () {
      expect(osDetectPreamble, contains('apk'));
    });

    test('osDetectPreamble supports zypper', () {
      expect(osDetectPreamble, contains('zypper'));
    });

    test('osDetectPreamble has pkg_install helper', () {
      expect(osDetectPreamble, contains('pkg_install'));
    });

    test('osDetectPreamble has pkg_name mapper', () {
      expect(osDetectPreamble, contains('pkg_name'));
    });

    test('osDetectPreamble maps build-essential for different distros', () {
      expect(osDetectPreamble, contains('build-essential'));
      expect(osDetectPreamble, contains('base-devel'));
      expect(osDetectPreamble, contains('build-base'));
    });

    test('osDetectPreamble maps libssl-dev for different distros', () {
      expect(osDetectPreamble, contains('libssl-dev'));
      expect(osDetectPreamble, contains('openssl-devel'));
    });
  });
}
