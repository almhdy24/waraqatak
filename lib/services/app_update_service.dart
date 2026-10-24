import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/app_localizations.dart';

/// Abstract platform wrapper to allow mock testing of Google Play in-app updates
/// without calling native Android platform channels.
abstract class PlayUpdatePlatform {
  Future<AppUpdateInfo> checkForUpdate();
  Future<AppUpdateResult> startFlexibleUpdate();
  Future<void> completeFlexibleUpdate();
  Future<AppUpdateResult> performImmediateUpdate();
  Stream<InstallStatus> get installUpdateListener;
}

class DefaultPlayUpdatePlatform implements PlayUpdatePlatform {
  @override
  Future<AppUpdateInfo> checkForUpdate() => InAppUpdate.checkForUpdate();

  @override
  Future<AppUpdateResult> startFlexibleUpdate() =>
      InAppUpdate.startFlexibleUpdate();

  @override
  Future<void> completeFlexibleUpdate() => InAppUpdate.completeFlexibleUpdate();

  @override
  Future<AppUpdateResult> performImmediateUpdate() =>
      InAppUpdate.performImmediateUpdate();

  @override
  Stream<InstallStatus> get installUpdateListener =>
      InAppUpdate.installUpdateListener;
}

/// Result status of an update check operation.
enum AppUpdateCheckResult {
  unsupportedPlatform,
  throttled,
  noUpdateAvailable,
  flexibleUpdateStarted,
  immediateUpdateStarted,
  updateAlreadyDownloaded,
  userDenied,
  failed,
}

/// Service managing Google Play In-App Updates in Waraqatak.
///
/// Features:
/// - Offline-safe: never interrupts user or crashes when offline or sideloaded.
/// - Flexible by default: downloads in background and prompts user to restart.
/// - Immediate support: triggers only for critical staleness (e.g. >= 14 days) or force flag.
/// - Frequency throttling: prevents repeated checks on every app resume (default 24h).
/// - Manual trigger support for Settings screen.
class AppUpdateService extends ChangeNotifier {
  static AppUpdateService? _instance;
  static AppUpdateService get instance => _instance ??= AppUpdateService();

  static const String _prefLastCheckMs = 'app_update_last_check_ms';
  static const Duration defaultThrottleInterval = Duration(hours: 24);

  PlayUpdatePlatform _platform;
  StreamSubscription<InstallStatus>? _installSubscription;

  bool _isChecking = false;
  bool _isDownloaded = false;
  AppUpdateInfo? _lastUpdateInfo;

  bool get isChecking => _isChecking;
  bool get isDownloaded => _isDownloaded;
  AppUpdateInfo? get lastUpdateInfo => _lastUpdateInfo;

  AppUpdateService({PlayUpdatePlatform? platform})
    : _platform = platform ?? DefaultPlayUpdatePlatform() {
    _initListener();
  }

  @visibleForTesting
  void setPlatformForTesting(PlayUpdatePlatform platform) {
    _installSubscription?.cancel();
    _platform = platform;
    _initListener();
  }

  void _initListener() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        _installSubscription = _platform.installUpdateListener.listen(
          (status) {
            if (status == InstallStatus.downloaded) {
              _isDownloaded = true;
              notifyListeners();
            }
          },
          onError: (e) {
            developer.log('AppUpdateService listener error: $e');
          },
        );
      } catch (e) {
        developer.log('AppUpdateService installListener unavailable: $e');
      }
    }
  }

  @override
  void dispose() {
    _installSubscription?.cancel();
    super.dispose();
  }

  /// Checks for available updates on Google Play.
  ///
  /// [manual]: If true, ignores 24-hour throttling and shows user feedback in [context].
  /// [forceImmediate]: If true, forces an immediate update if allowed.
  /// [criticalStalenessDays]: Threshold of staleness to trigger immediate update (default: 14).
  Future<AppUpdateCheckResult> checkForUpdate({
    BuildContext? context,
    bool manual = false,
    bool forceImmediate = false,
    int criticalStalenessDays = 14,
    SharedPreferences? prefs,
  }) async {
    // In-app updates are Android-only.
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
      return AppUpdateCheckResult.unsupportedPlatform;
    }

    if (_isChecking) return AppUpdateCheckResult.throttled;

    // Throttle automatic checks
    if (!manual) {
      final sp = prefs ?? await SharedPreferences.getInstance();
      final lastCheckMs = sp.getInt(_prefLastCheckMs) ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - lastCheckMs < defaultThrottleInterval.inMilliseconds) {
        return AppUpdateCheckResult.throttled;
      }
    }

    _isChecking = true;
    notifyListeners();

    try {
      final info = await _platform.checkForUpdate();
      _lastUpdateInfo = info;

      final sp = prefs ?? await SharedPreferences.getInstance();
      await sp.setInt(_prefLastCheckMs, DateTime.now().millisecondsSinceEpoch);

      // 1. If update was already downloaded in previous session
      if (info.installStatus == InstallStatus.downloaded) {
        _isDownloaded = true;
        _isChecking = false;
        notifyListeners();
        if (context != null && context.mounted) {
          _showDownloadedNotification(context);
        }
        return AppUpdateCheckResult.updateAlreadyDownloaded;
      }

      // 2. Check if an update is available
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        final staleness = info.clientVersionStalenessDays ?? 0;
        final shouldBeImmediate =
            info.immediateUpdateAllowed &&
            (forceImmediate || staleness >= criticalStalenessDays);

        if (shouldBeImmediate) {
          final result = await _platform.performImmediateUpdate();
          _isChecking = false;
          notifyListeners();
          if (result == AppUpdateResult.userDeniedUpdate) {
            return AppUpdateCheckResult.userDenied;
          }
          return AppUpdateCheckResult.immediateUpdateStarted;
        } else if (info.flexibleUpdateAllowed) {
          final result = await _platform.startFlexibleUpdate();
          _isChecking = false;
          notifyListeners();
          if (result == AppUpdateResult.userDeniedUpdate) {
            return AppUpdateCheckResult.userDenied;
          }
          // Listen for completion
          if (context != null && context.mounted) {
            _listenForFlexibleDownload(context);
          }
          return AppUpdateCheckResult.flexibleUpdateStarted;
        }
      }

      _isChecking = false;
      notifyListeners();

      if (manual && context != null && context.mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.appUpToDate)));
      }
      return AppUpdateCheckResult.noUpdateAvailable;
    } catch (e, stack) {
      _isChecking = false;
      notifyListeners();
      developer.log(
        'AppUpdateService check failed',
        error: e,
        stackTrace: stack,
      );

      if (manual && context != null && context.mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.updateCheckFailed)));
      }
      return AppUpdateCheckResult.failed;
    }
  }

  void _listenForFlexibleDownload(BuildContext context) {
    // If already downloaded, notify immediately
    if (_isDownloaded) {
      if (context.mounted) _showDownloadedNotification(context);
      return;
    }

    void listener() {
      if (_isDownloaded) {
        removeListener(listener);
        if (context.mounted) {
          _showDownloadedNotification(context);
        }
      }
    }

    addListener(listener);
  }

  void _showDownloadedNotification(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.updateDownloadedRestart),
        duration: const Duration(seconds: 15),
        action: SnackBarAction(
          label: l10n.restartNow,
          onPressed: () => completeFlexibleUpdate(context: context),
        ),
      ),
    );
  }

  /// Completes the flexible update and restarts the application.
  Future<void> completeFlexibleUpdate({BuildContext? context}) async {
    try {
      await _platform.completeFlexibleUpdate();
    } catch (e) {
      developer.log('AppUpdateService completeFlexibleUpdate failed: $e');
      if (context != null && context.mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.updateFailed)));
      }
    }
  }
}
