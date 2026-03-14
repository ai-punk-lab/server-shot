import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdate {
  final String version;
  final String downloadUrl;
  final String releaseName;
  final String body;

  AppUpdate({
    required this.version,
    required this.downloadUrl,
    required this.releaseName,
    required this.body,
  });
}

class UpdateService {
  static const _repo = 'ai-punk-lab/server-shot';
  static const _currentVersion = '1.0.0';

  /// Check GitHub releases for a newer version
  static Future<AppUpdate?> checkForUpdate() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final request = await client.getUrl(
        Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
      );
      request.headers.set('Accept', 'application/vnd.github.v3+json');
      request.headers.set('User-Agent', 'ServerShot/$_currentVersion');

      final response = await request.close();
      if (response.statusCode != 200) return null;

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final tagName = json['tag_name'] as String? ?? '';
      final remoteVersion = tagName.replaceAll('v', '');

      if (!_isNewer(remoteVersion, _currentVersion)) return null;

      // Find the right APK — prefer arm64, fallback to universal
      final assets = json['assets'] as List<dynamic>? ?? [];
      String? downloadUrl;

      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.contains('arm64')) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
      // Fallback to universal
      downloadUrl ??= assets
          .cast<Map<String, dynamic>>()
          .where((a) => (a['name'] as String).contains('universal'))
          .map((a) => a['browser_download_url'] as String)
          .firstOrNull;

      if (downloadUrl == null) return null;

      return AppUpdate(
        version: remoteVersion,
        downloadUrl: downloadUrl,
        releaseName: json['name'] as String? ?? 'v$remoteVersion',
        body: json['body'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('Update check failed: $e');
      return null;
    }
  }

  /// Download APK and trigger install
  static Future<void> downloadAndInstall(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      final contentLength = response.contentLength;
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/servershot_update.apk');

      final sink = file.openWrite();
      int received = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          onProgress?.call(received / contentLength);
        }
      }

      await sink.close();

      // Open APK with system installer
      final uri = Uri.parse(file.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback: open in browser
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      // Fallback: open download URL in browser
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  /// Open release page in browser as fallback
  static Future<void> openReleasePage() async {
    await launchUrl(
      Uri.parse('https://github.com/$_repo/releases/latest'),
      mode: LaunchMode.externalApplication,
    );
  }

  static bool _isNewer(String remote, String current) {
    final remoteParts = remote.split('.').map(int.tryParse).toList();
    final currentParts = current.split('.').map(int.tryParse).toList();

    for (int i = 0; i < 3; i++) {
      final r = (i < remoteParts.length ? remoteParts[i] : 0) ?? 0;
      final c = (i < currentParts.length ? currentParts[i] : 0) ?? 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }
}
