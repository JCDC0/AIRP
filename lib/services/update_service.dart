import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReleaseInfo {
  final String version;
  final String changelog;
  final String downloadUrl;
  final int fileSize;

  const ReleaseInfo({
    required this.version,
    required this.changelog,
    required this.downloadUrl,
    required this.fileSize,
  });
}

class UpdateService {
  static const String _prefLastCheck = 'airp_update_last_check';
  static const String _prefSkippedVersion = 'airp_update_skipped_version';
  static const String _repoOwner = 'JCDC0';
  static const String _repoName = 'AIRP';
  static const Duration _checkInterval = Duration(hours: 24);

  static const _channel = MethodChannel('com.airp/updater');

  static Future<ReleaseInfo?> checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
        ),
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'AIRP-Android-App',
        },
      );

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = (json['tag_name'] as String?)?.replaceAll(RegExp(r'^[vV]'), '');
      if (tagName == null) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      if (!isNewerVersion(tagName, packageInfo.version)) return null;

      final assets = json['assets'] as List<dynamic>? ?? [];
      final apkAsset = assets.cast<Map<String, dynamic>>().where(
        (a) => (a['name'] as String? ?? '').endsWith('.apk'),
      );
      if (apkAsset.isEmpty) return null;

      final asset = apkAsset.first;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefLastCheck,
        DateTime.now().toIso8601String(),
      );

      return ReleaseInfo(
        version: tagName,
        changelog: json['body'] as String? ?? '',
        downloadUrl: asset['browser_download_url'] as String,
        fileSize: asset['size'] as int? ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  static bool isNewerVersion(String remote, String local) {
    final cleanRemote = remote.replaceAll(RegExp(r'^[vV]'), '').trim();
    final cleanLocal = local.replaceAll(RegExp(r'^[vV]'), '').trim();

    final remoteBase = cleanRemote.split('-').first.split('+').first;
    final localBase = cleanLocal.split('-').first.split('+').first;

    final remoteParts = remoteBase.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final localParts = localBase.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    final maxLen = remoteParts.length > localParts.length
        ? remoteParts.length
        : localParts.length;

    for (int i = 0; i < maxLen; i++) {
      final r = i < remoteParts.length ? remoteParts[i] : 0;
      final l = i < localParts.length ? localParts[i] : 0;
      if (r > l) return true;
      if (r < l) return false;
    }

    final localHasPreRelease =
        cleanLocal.contains('-') || RegExp(r'[a-zA-Z]').hasMatch(cleanLocal);
    final remoteHasPreRelease =
        cleanRemote.contains('-') || RegExp(r'[a-zA-Z]').hasMatch(cleanRemote);
    if (localHasPreRelease && !remoteHasPreRelease) {
      return true;
    }

    return false;
  }

  static Future<bool> shouldAutoCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckStr = prefs.getString(_prefLastCheck);
    if (lastCheckStr == null) return true;

    final lastCheck = DateTime.tryParse(lastCheckStr);
    if (lastCheck == null) return true;

    return DateTime.now().difference(lastCheck) >= _checkInterval;
  }

  static Future<String?> getSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefSkippedVersion);
  }

  static Future<void> setSkippedVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSkippedVersion, version);
  }

  static Future<String> downloadApk(
    String url,
    void Function(double progress) onProgress,
  ) async {
    final request = http.Request('GET', Uri.parse(url));
    request.headers['User-Agent'] = 'AIRP-Android-App';
    final client = http.Client();

    try {
      final response = await client.send(request);
      final contentLength = response.contentLength ?? 0;
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/update.apk';
      final file = File(filePath);
      final sink = file.openWrite();

      int received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          onProgress(received / contentLength);
        }
      }

      await sink.flush();
      await sink.close();
      return filePath;
    } finally {
      client.close();
    }
  }

  static Future<bool> installApk(String filePath) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'installApk',
        {'filePath': filePath},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}
