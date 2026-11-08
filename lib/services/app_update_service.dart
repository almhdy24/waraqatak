import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/app_localizations.dart';
import '../widgets/app_snackbar.dart';

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
  updateNotAllowed,
  alreadyChecking,
}

/// Service managing Google Play In-App Updates in Waraqatak.
///
/// Features:
/// - Offline-safe: never interrupts user or crashes when offline or sideloaded.
/// - Flexible by default: downloads in background and prompts user to restart.
/// - Immediate support: triggers for critical priority (>= 4), critical staleness (>= 14 days), or force flag.
/// - Frequency throttling: prevents repeated checks on every app resume (default 24h).
/// - Failure backoff: backs off automatic checks for 1h after failures.
/// - Decline cooldown: respects user denial for 3 days unless priority >= 4.
/// - Manual trigger support for Settings screen.
class AppUpdateService extends ChangeNotifier {
  static AppUpdateService? _instance;
  static AppUpdateService get instance => _instance ??= AppUpdateService();

  /// Global key to show update SnackBars without leaking BuildContext.
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static const String _prefLastCheckMs = 'app_update_last_check_ms';
  static const String _prefLastFailureMs = 'app_update_last_failure_ms';
  static const String _prefDeclinedVersion = 'app_update_declined_version';
  static const String _prefDeclinedTimestampMs =
      'app_update_declined_timestamp_ms';

  static const Duration defaultThrottleInterval = Duration(hours: 24);
  static const Duration failureBackoffInterval = Duration(hours: 1);
  static const Duration declineCooldownInterval = Duration(days: 3);

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
              _showDownloadedNotification();
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
  /// [manual]: If true, ignores 24-hour throttling and 1h failure backoff, and shows user feedback.
  /// [forceImmediate]: If true, forces an immediate update if allowed.
  /// [criticalStalenessDays]: Threshold of staleness to trigger immediate update fallback (default: 14).
  Future<AppUpdateCheckResult> checkForUpdate({
    BuildContext? context,
    bool manual = false,
    bool forceImmediate = false,
    int criticalStalenessDays = 14,
    SharedPreferences? prefs,
  }) async {
    // In-app updates are Android-only.
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) {
      if (manual && context != null && context.mounted) {
        final l10n = AppLocalizations.of(context);
        AppSnackBar.show(
          context,
          l10n.updateNonPlayInstall,
          severity: AppSnackBarSeverity.info,
        );
      }
      return AppUpdateCheckResult.unsupportedPlatform;
    }

    if (_isChecking) return AppUpdateCheckResult.alreadyChecking;

    _isChecking = true;
    notifyListeners();

    try {
      final sp = prefs ?? await SharedPreferences.getInstance();
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // 1h backoff after a failed check (automatic checks only)
      if (!manual) {
        final lastFailureMs = sp.getInt(_prefLastFailureMs) ?? 0;
        if (nowMs - lastFailureMs < failureBackoffInterval.inMilliseconds) {
          _isChecking = false;
          notifyListeners();
          return AppUpdateCheckResult.throttled;
        }
      }
      final info = await _platform.checkForUpdate();
      _lastUpdateInfo = info;

      // Successful check clears failure backoff
      await sp.remove(_prefLastFailureMs);

      // 1. If update was already downloaded in previous session or background.
      // Checked on every resume, independent of the 24h throttle.
      if (info.installStatus == InstallStatus.downloaded) {
        _isDownloaded = true;
        _isChecking = false;
        notifyListeners();
        if (context != null && context.mounted) {
          _showDownloadedNotification(context: context);
        } else {
          _showDownloadedNotification();
        }
        return AppUpdateCheckResult.updateAlreadyDownloaded;
      }

      // 2. If an immediate update is already in progress, resume it.
      if (info.updateAvailability ==
          UpdateAvailability.developerTriggeredUpdateInProgress) {
        final result = await _platform.performImmediateUpdate();
        _isChecking = false;
        notifyListeners();
        if (result == AppUpdateResult.userDeniedUpdate) {
          await _recordDeclinedVersion(sp, info.availableVersionCode);
          return AppUpdateCheckResult.userDenied;
        } else if (result == AppUpdateResult.inAppUpdateFailed) {
          if (manual && context != null && context.mounted) {
            final l10n = AppLocalizations.of(context);
            AppSnackBar.show(
              context,
              l10n.updateFailed,
              severity: AppSnackBarSeverity.error,
            );
          }
          return AppUpdateCheckResult.failed;
        }
        return AppUpdateCheckResult.immediateUpdateStarted;
      }

      // 3. Update-availability flow: throttled for automatic checks (default 24h)
      if (!manual) {
        final lastCheckMs = sp.getInt(_prefLastCheckMs) ?? 0;
        if (nowMs - lastCheckMs < defaultThrottleInterval.inMilliseconds) {
          _isChecking = false;
          notifyListeners();
          return AppUpdateCheckResult.throttled;
        }
      }

      await sp.setInt(_prefLastCheckMs, DateTime.now().millisecondsSinceEpoch);

      // 4. Check if an update is available
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        final staleness = info.clientVersionStalenessDays ?? 0;
        final isPriorityCritical = info.updatePriority >= 4;
        final isCritical =
            isPriorityCritical || (staleness >= criticalStalenessDays);

        // Cooldown on declined version (3 days) unless priority >= 4
        if (!manual &&
            !isPriorityCritical &&
            info.availableVersionCode != null) {
          final declinedVersion = sp.getInt(_prefDeclinedVersion);
          final declinedTimestamp = sp.getInt(_prefDeclinedTimestampMs) ?? 0;
          if (info.availableVersionCode == declinedVersion &&
              nowMs - declinedTimestamp <
                  declineCooldownInterval.inMilliseconds) {
            _isChecking = false;
            notifyListeners();
            return AppUpdateCheckResult.throttled;
          }
        }

        final shouldBeImmediate =
            info.immediateUpdateAllowed && (forceImmediate || isCritical);

        if (shouldBeImmediate) {
          final result = await _platform.performImmediateUpdate();
          _isChecking = false;
          notifyListeners();
          if (result == AppUpdateResult.userDeniedUpdate) {
            await _recordDeclinedVersion(sp, info.availableVersionCode);
            return AppUpdateCheckResult.userDenied;
          } else if (result == AppUpdateResult.inAppUpdateFailed) {
            if (manual && context != null && context.mounted) {
              final l10n = AppLocalizations.of(context);
              AppSnackBar.show(
                context,
                l10n.updateFailed,
                severity: AppSnackBarSeverity.error,
              );
            }
            return AppUpdateCheckResult.failed;
          }
          return AppUpdateCheckResult.immediateUpdateStarted;
        } else if (info.flexibleUpdateAllowed) {
          final result = await _platform.startFlexibleUpdate();
          _isChecking = false;
          notifyListeners();
          if (result == AppUpdateResult.userDeniedUpdate) {
            await _recordDeclinedVersion(sp, info.availableVersionCode);
            return AppUpdateCheckResult.userDenied;
          } else if (result == AppUpdateResult.inAppUpdateFailed) {
            if (manual && context != null && context.mounted) {
              final l10n = AppLocalizations.of(context);
              AppSnackBar.show(
                context,
                l10n.updateFailed,
                severity: AppSnackBarSeverity.error,
              );
            }
            return AppUpdateCheckResult.failed;
          }
          return AppUpdateCheckResult.flexibleUpdateStarted;
        } else {
          // Update exists but neither immediate nor flexible is allowed
          _isChecking = false;
          notifyListeners();
          if (manual && context != null && context.mounted) {
            final l10n = AppLocalizations.of(context);
            AppSnackBar.show(
              context,
              l10n.updateNotAllowed,
              severity: AppSnackBarSeverity.warning,
            );
          }
          return AppUpdateCheckResult.updateNotAllowed;
        }
      }

      _isChecking = false;
      notifyListeners();

      if (manual && context != null && context.mounted) {
        final l10n = AppLocalizations.of(context);
        AppSnackBar.show(context, l10n.appUpToDate);
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

      // Record failure timestamp for 1h backoff
      try {
        final failureSp = prefs ?? await SharedPreferences.getInstance();
        await failureSp.setInt(
          _prefLastFailureMs,
          DateTime.now().millisecondsSinceEpoch,
        );
      } catch (_) {}

      if (manual && context != null && context.mounted) {
        final l10n = AppLocalizations.of(context);
        final errStr = e.toString().toLowerCase();
        final isNonPlay =
            errStr.contains('not_owned') ||
            errStr.contains('not owned') ||
            errStr.contains('sideload') ||
            errStr.contains('error(-10)');
        if (isNonPlay) {
          AppSnackBar.show(
            context,
            l10n.updateNonPlayInstall,
            severity: AppSnackBarSeverity.info,
          );
        } else {
          AppSnackBar.show(
            context,
            l10n.updateCheckFailed,
            severity: AppSnackBarSeverity.error,
          );
        }
      }
      return AppUpdateCheckResult.failed;
    }
  }

  Future<void> _recordDeclinedVersion(
    SharedPreferences sp,
    int? versionCode,
  ) async {
    if (versionCode != null) {
      await sp.setInt(_prefDeclinedVersion, versionCode);
      await sp.setInt(
        _prefDeclinedTimestampMs,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  void _showDownloadedNotification({BuildContext? context}) {
    final ctx = (context != null && context.mounted)
        ? context
        : scaffoldMessengerKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final l10n = AppLocalizations.of(ctx);
    AppSnackBar.show(
      ctx,
      l10n.updateDownloadedRestart,
      actionLabel: l10n.restartNow,
      onAction: () => completeFlexibleUpdate(context: ctx),
    );
  }

  /// Completes the flexible update and restarts the application.
  Future<void> completeFlexibleUpdate({BuildContext? context}) async {
    try {
      _isDownloaded = false;
      notifyListeners();
      await _platform.completeFlexibleUpdate();
    } catch (e) {
      _isDownloaded = true;
      notifyListeners();
      developer.log('AppUpdateService completeFlexibleUpdate failed: $e');
      final ctx = context ?? scaffoldMessengerKey.currentContext;
      if (ctx != null && ctx.mounted) {
        final l10n = AppLocalizations.of(ctx);
        AppSnackBar.show(
          ctx,
          l10n.updateFailed,
          severity: AppSnackBarSeverity.error,
        );
      }
    }
  }
}
