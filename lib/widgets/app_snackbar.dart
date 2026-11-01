import 'dart:async';
import 'package:flutter/material.dart';
import 'package:warqatek/widgets/app_design_tokens.dart';

/// Semantic severity levels for [AppSnackBar].
enum AppSnackBarSeverity {
  info,
  success,
  warning,
  error,
}

/// Centralized SnackBar helper enforcing a strict 5-second auto-dismissal,
/// Telegram-style circular countdown for interactive actions, accessible navigation scaling,
/// and a robust fallback dismissal timer.
class AppSnackBar {
  AppSnackBar._();

  /// Default SnackBar display duration (5 seconds).
  static const Duration defaultDuration = Duration(seconds: 5);

  /// Extended SnackBar display duration for accessible navigation (10 seconds).
  static const Duration accessibleDuration = Duration(seconds: 10);

  /// Fallback timer buffer to guarantee dismissal even if animation/event pump lags.
  static const Duration fallbackBuffer = Duration(milliseconds: 300);

  /// Shows an auto-dismissing floating SnackBar.
  ///
  /// - Clears any existing SnackBars first.
  /// - Strictly uses `persist: false`.
  /// - When [actionLabel] and [onAction] are provided, displays a Telegram-style circular countdown
  ///   animating over the same duration next to the action button.
  /// - Tap on action invokes [onAction] exactly once and immediately closes the SnackBar.
  /// - When `accessibleNavigation` is active and an action exists, the duration extends to 10 seconds.
  /// - A fallback timer dismisses the SnackBar at `duration + 300ms` if still visible.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? show(
    BuildContext context,
    String message, {
    AppSnackBarSeverity? severity,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!context.mounted) return null;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return null;

    final hasAction = actionLabel != null && onAction != null;
    final accessibleNavigation =
        MediaQuery.maybeAccessibleNavigationOf(context) ?? false;
    final effectiveDuration =
        (accessibleNavigation && hasAction) ? accessibleDuration : defaultDuration;

    final theme = Theme.of(context);
    Color? backgroundColor;
    Color? textColor;
    late final Color actionColor;

    switch (severity) {
      case AppSnackBarSeverity.error:
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
        actionColor = theme.snackBarTheme.actionTextColor ?? theme.colorScheme.inversePrimary;
        break;
    }

    var actionExecuted = false;
    void handleAction() {
      if (actionExecuted) return;
      actionExecuted = true;
      onAction?.call();
    }

    final contentWidget = hasAction
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Text(
                  message,
                  style: textColor != null ? TextStyle(color: textColor) : null,
                ),
              ),
              const SizedBox(width: AppDesignTokens.space8),
              _SnackBarCountdown(
                duration: effectiveDuration,
                color: actionColor,
              ),
            ],
          )
        : Text(
            message,
            style: textColor != null ? TextStyle(color: textColor) : null,
          );

    final snackBar = SnackBar(
      content: contentWidget,
      duration: effectiveDuration,
      persist: false,
      behavior: SnackBarBehavior.floating,
      backgroundColor: backgroundColor,
      action: hasAction
          ? SnackBarAction(
              label: actionLabel,
              textColor: actionColor,
              onPressed: handleAction,
            )
          : null,
    );

    // Clear previous snackbars first
    messenger.clearSnackBars();
    final controller = messenger.showSnackBar(snackBar);

    // Fallback timer: close controller at duration + 300 ms if still open
    Timer? fallbackTimer;
    fallbackTimer = Timer(effectiveDuration + fallbackBuffer, () {
      try {
        controller.close();
      } catch (_) {
        // Guard against already closed or unmounted
      }
    });

    controller.closed.then((_) {
      fallbackTimer?.cancel();
    }).catchError((_) {});

    return controller;
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final remainingSeconds =
            (_controller.value * widget.duration.inSeconds).ceil().clamp(1, widget.duration.inSeconds);
        return Semantics(
          label: '$remainingSeconds',
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
