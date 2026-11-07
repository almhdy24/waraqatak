import 'dart:async';
import 'package:flutter/material.dart';
import 'package:warqatek/widgets/app_design_tokens.dart';

/// Semantic severity levels for [AppSnackBar].
enum AppSnackBarSeverity {
  info,
  success,
  warning,
  error,
  critical,
}

/// Centralized SnackBar helper providing context-aware, accessible, and
/// non-intrusive notifications with robust lifecycle cleanup.
class AppSnackBar {
  AppSnackBar._();

  /// Default duration for successful operations (2 seconds).
  static const Duration durationSuccess = Duration(seconds: 2);

  /// Default duration for informational notices (2.5 seconds).
  static const Duration durationInfo = Duration(milliseconds: 2500);

  /// Default duration for warning notices (3.5 seconds).
  static const Duration durationWarning = Duration(milliseconds: 3500);

  /// Default duration for recoverable error notices (4 seconds).
  static const Duration durationError = Duration(seconds: 4);

  /// Default duration for time-limited destructive actions (Undo/Restore) (5 seconds).
  static const Duration durationUndo = Duration(seconds: 5);

  /// Extended SnackBar display duration for accessible navigation (10 seconds).
  static const Duration durationAccessible = Duration(seconds: 10);

  /// Fallback duration for persistent/critical notices that remain until dismissed.
  static const Duration durationPersistent = Duration(days: 1);

  /// Backwards-compatible alias for default duration (3 seconds).
  @Deprecated('Use semantic duration constants such as durationInfo or durationSuccess')
  static const Duration defaultDuration = Duration(seconds: 3);

  /// Backwards-compatible alias for accessible duration (10 seconds).
  static const Duration accessibleDuration = durationAccessible;

  /// Fallback timer buffer to guarantee dismissal even if animation/event pump lags.
  static const Duration fallbackBuffer = Duration(milliseconds: 300);

  // Active singleton timer holders to prevent duplicate/competing timers
  static Timer? _activeFallbackTimer;
  static Timer? _activeExpirationTimer;

  /// Resolves the effective duration based on explicit overrides, accessibility settings,
  /// action expiration deadlines, and semantic severity.
  static Duration resolveDuration({
    Duration? explicitDuration,
    required bool accessibleNavigation,
    required bool hasAction,
    required bool actionExpires,
    required bool persistent,
    AppSnackBarSeverity? severity,
  }) {
    if (explicitDuration != null) {
      if (accessibleNavigation && hasAction && explicitDuration < durationAccessible) {
        return durationAccessible;
      }
      return explicitDuration;
    }

    if (persistent || severity == AppSnackBarSeverity.critical) {
      return durationPersistent;
    }

    if (accessibleNavigation && hasAction) {
      return durationAccessible;
    }

    if (actionExpires) {
      return durationUndo;
    }

    switch (severity) {
      case AppSnackBarSeverity.success:
        return durationSuccess;
      case AppSnackBarSeverity.warning:
        return durationWarning;
      case AppSnackBarSeverity.error:
        return durationError;
      case AppSnackBarSeverity.info:
      case null:
        return durationInfo;
      case AppSnackBarSeverity.critical:
        return durationPersistent;
    }
  }

  /// Shows an auto-dismissing or persistent floating SnackBar.
  ///
  /// - Automatically clears any existing SnackBars.
  /// - Sets default durations context-aware by severity:
  ///   * Success: 2 seconds ([durationSuccess])
  ///   * Informational: 2.5 seconds ([durationInfo])
  ///   * Warning: 3.5 seconds ([durationWarning])
  ///   * Recoverable error: 4 seconds ([durationError])
  ///   * Critical / actionable error: persistent until dismissed ([durationPersistent])
  ///   * Time-limited destructive action (Undo/Restore): 5 seconds ([durationUndo])
  /// - Supports explicit [duration] override when justified.
  /// - Circular countdown appears ONLY when [actionExpires] is true and an action is provided.
  /// - When `accessibleNavigation` is active and an interactive action exists, duration extends to 10 seconds.
  /// - A reliable fallback timer guarantees dismissal for non-persistent notices without competing timers.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? show(
    BuildContext context,
    String message, {
    AppSnackBarSeverity? severity,
    String? actionLabel,
    VoidCallback? onAction,
    bool actionExpires = false,
    VoidCallback? onActionExpired,
    Duration? duration,
    bool persistent = false,
    bool? showCloseIcon,
    IconData? icon,
  }) {
    if (!context.mounted) return null;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return null;

    final hasAction = actionLabel != null && onAction != null;
    final isPersistent = persistent || severity == AppSnackBarSeverity.critical;
    final accessibleNavigation =
        MediaQuery.maybeAccessibleNavigationOf(context) ?? false;

    final effectiveDuration = resolveDuration(
      explicitDuration: duration,
      accessibleNavigation: accessibleNavigation,
      hasAction: hasAction,
      actionExpires: actionExpires,
      persistent: isPersistent,
      severity: severity,
    );

    // Cancel any active singleton timers from previous snackbars
    _activeFallbackTimer?.cancel();
    _activeFallbackTimer = null;
    _activeExpirationTimer?.cancel();
    _activeExpirationTimer = null;

    final theme = Theme.of(context);
    Color? backgroundColor;
    Color? textColor;
    late final Color actionColor;

    switch (severity) {
      case AppSnackBarSeverity.error:
      case AppSnackBarSeverity.critical:
        backgroundColor = AppDesignTokens.semanticDanger(context);
        textColor = Colors.white;
        actionColor = Colors.white;
        break;
      case AppSnackBarSeverity.success:
        backgroundColor = AppDesignTokens.semanticSuccess(context);
        textColor = Colors.white;
        actionColor = Colors.white;
        break;
      case AppSnackBarSeverity.warning:
        backgroundColor = AppDesignTokens.semanticWarning(context);
        textColor = Colors.black87;
        actionColor = Colors.black87;
        break;
      case AppSnackBarSeverity.info:
        backgroundColor = AppDesignTokens.semanticInfo(context);
        textColor = Colors.white;
        actionColor = Colors.white;
        break;
      case null:
        backgroundColor = null;
        textColor = null;
        actionColor =
            theme.snackBarTheme.actionTextColor ?? theme.colorScheme.inversePrimary;
        break;
    }

    var actionExecuted = false;
    ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? controller;

    void handleAction() {
      if (actionExecuted) return;
      actionExecuted = true;
      _activeExpirationTimer?.cancel();
      _activeExpirationTimer = null;
      try {
        controller?.close();
      } catch (_) {}
      onAction?.call();
    }

    // Circular countdown appears ONLY when action genuinely expires and is not persistent
    final showCountdown = hasAction && actionExpires && !isPersistent;

    final messageWidget = Text(
      message,
      style: textColor != null ? TextStyle(color: textColor) : null,
    );

    final contentChildren = <Widget>[
      if (icon != null) ...[
        Icon(icon, size: 20, color: actionColor),
        const SizedBox(width: AppDesignTokens.space12),
      ],
      Expanded(child: messageWidget),
      if (showCountdown) ...[
        const SizedBox(width: AppDesignTokens.space8),
        _SnackBarCountdown(
          duration: effectiveDuration,
          color: actionColor,
        ),
      ],
    ];

    final Widget contentWidget = (icon != null || showCountdown)
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: contentChildren,
          )
        : messageWidget;

    final shouldShowCloseIcon = showCloseIcon ?? isPersistent;

    final snackBar = SnackBar(
      content: contentWidget,
      duration: effectiveDuration,
      persist: false,
      behavior: SnackBarBehavior.floating,
      backgroundColor: backgroundColor,
      showCloseIcon: shouldShowCloseIcon,
      closeIconColor: shouldShowCloseIcon ? actionColor : null,
      action: hasAction
          ? SnackBarAction(
              label: actionLabel,
              textColor: actionColor,
              onPressed: handleAction,
            )
          : null,
    );

    messenger.clearSnackBars();
    controller = messenger.showSnackBar(snackBar);

    // Fallback timer: guarantees dismissal for non-persistent snackbars even if
    // the frame scheduler lags or is stalled.
    if (!isPersistent) {
      _activeFallbackTimer = Timer(effectiveDuration + fallbackBuffer, () {
        try {
          controller?.close();
        } catch (_) {}
      });
    }

    // Action expiration timer: decoupled from visual dismissal so manual swipe
    // or transient dismissals do not corrupt or prematurely trigger business operations.
    if (hasAction && actionExpires && onActionExpired != null) {
      _activeExpirationTimer = Timer(effectiveDuration, () {
        if (!actionExecuted) {
          onActionExpired();
        }
      });
    }

    controller.closed.then((reason) {
      _activeFallbackTimer?.cancel();
      _activeFallbackTimer = null;
      if (actionExecuted) {
        _activeExpirationTimer?.cancel();
        _activeExpirationTimer = null;
      }
    }).catchError((_) {});

    return controller;
  }

  /// Shows a time-limited destructive action notification (e.g. Undo/Restore)
  /// with a circular countdown and default 5-second deadline.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showUndo(
    BuildContext context,
    String message, {
    required String actionLabel,
    required VoidCallback onUndo,
    VoidCallback? onActionExpired,
    Duration? duration,
    AppSnackBarSeverity? severity,
  }) {
    return show(
      context,
      message,
      severity: severity,
      actionLabel: actionLabel,
      onAction: onUndo,
      actionExpires: true,
      onActionExpired: onActionExpired,
      duration: duration,
    );
  }

  /// Dismisses any currently visible SnackBar and clears pending fallback timers.
  static void hide(BuildContext context) {
    _activeFallbackTimer?.cancel();
    _activeFallbackTimer = null;
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
  }

  /// Resets internal timer states for test isolation.
  @visibleForTesting
  static void resetForTest() {
    _activeFallbackTimer?.cancel();
    _activeFallbackTimer = null;
    _activeExpirationTimer?.cancel();
    _activeExpirationTimer = null;
  }
}

/// Telegram-style circular animated countdown indicator for action SnackBars.
class _SnackBarCountdown extends StatefulWidget {
  final Duration duration;
  final Color color;

  const _SnackBarCountdown({
    required this.duration,
    required this.color,
  });

  @override
  State<_SnackBarCountdown> createState() => _SnackBarCountdownState();
}

class _SnackBarCountdownState extends State<_SnackBarCountdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _controller.reverse(from: 1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds =
        widget.duration.inSeconds > 0 ? widget.duration.inSeconds : 1;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final remainingSeconds =
            (_controller.value * totalSeconds).ceil().clamp(1, totalSeconds);
        return ExcludeSemantics(
          child: SizedBox(
            width: 22,
            height: 22,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _controller.value,
                  strokeWidth: 2.0,
                  backgroundColor: widget.color.withValues(alpha: 0.25),
                  valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                ),
                Text(
                  '$remainingSeconds',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: widget.color,
                    height: 1.0,
                  ),
                  textScaler: TextScaler.noScaling,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
