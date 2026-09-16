import 'package:flutter/foundation.dart';
import '../services/update_service.dart';

class UpdateProvider extends ChangeNotifier {
  ReleaseInfo? _releaseInfo;
  bool _isChecking = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _error;

  ReleaseInfo? get releaseInfo => _releaseInfo;
  bool get updateAvailable => _releaseInfo != null;
  String get latestVersion => _releaseInfo?.version ?? '';
  String get releaseNotes => _releaseInfo?.changelog ?? '';
  bool get isChecking => _isChecking;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String? get error => _error;

  Future<void> checkForUpdate({bool force = false}) async {
    if (_isChecking) return;

    if (!force) {
      final shouldCheck = await UpdateService.shouldAutoCheck();
      if (!shouldCheck) return;
    }

    _isChecking = true;
    _error = null;
    notifyListeners();

    try {
      final info = await UpdateService.checkForUpdate();
      if (info != null) {
        final skipped = await UpdateService.getSkippedVersion();
        if (skipped != info.version || force) {
          _releaseInfo = info;
        }
      }
    } catch (e) {
      _error = 'Failed to check for updates';
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<void> downloadAndInstall() async {
    if (_isDownloading || _releaseInfo == null) return;

    _isDownloading = true;
    _downloadProgress = 0.0;
    _error = null;
    notifyListeners();

    try {
      final filePath = await UpdateService.downloadApk(
        _releaseInfo!.downloadUrl,
        (progress) {
          _downloadProgress = progress;
          notifyListeners();
        },
      );

      final installed = await UpdateService.installApk(filePath);
      if (!installed) {
        _error = 'Could not launch installer';
      }
    } catch (e) {
      _error = 'Download failed: $e';
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }

  Future<void> skipVersion() async {
    if (_releaseInfo != null) {
      await UpdateService.setSkippedVersion(_releaseInfo!.version);
      _releaseInfo = null;
      notifyListeners();
    }
  }

  void dismiss() {
    _releaseInfo = null;
    notifyListeners();
  }
}
