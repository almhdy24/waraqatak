import 'package:flutter/material.dart';

/// Semantic status used for badges, banners and tinted cards.
enum AppStatus { success, warning, danger, info, neutral }

/// Brightness-aware status colors. Replaces hardcoded Colors.green/red/orange/...
/// Light values are dark enough for text on a 12% tinted background (WCAG AA),
/// dark values are light enough for text on a dark surface.
class AppStatusColors {
  const AppStatusColors._();

  static bool _dark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  /// Foreground (text / icon) color.
  static Color fg(BuildContext c, AppStatus s) {
    final cs = Theme.of(c).colorScheme;
    final dark = _dark(c);
    switch (s) {
      case AppStatus.success:
        return dark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
      case AppStatus.warning:
        return dark ? const Color(0xFFFFB74D) : const Color(0xFFB45309);
      case AppStatus.danger:
        return cs.error;
      case AppStatus.info:
        return dark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0);
      case AppStatus.neutral:
        return cs.onSurfaceVariant;
    }
  }

  /// Soft tinted background.
  static Color bg(BuildContext c, AppStatus s) =>
      fg(c, s).withValues(alpha: _dark(c) ? 0.18 : 0.10);

  /// Border color for tinted containers.
  static Color border(BuildContext c, AppStatus s) =>
      fg(c, s).withValues(alpha: 0.35);

  /// Makes an arbitrary brand/category color readable in dark mode
  /// (lifts lightness to >= 0.68). Light mode returns the color unchanged.
  static Color adapt(BuildContext c, Color base) {
    if (!_dark(c)) return base;
    final hsl = HSLColor.fromColor(base);
    if (hsl.lightness >= 0.68) return base;
    return hsl.withLightness(0.68).toColor();
  }
}

/// Small pill used for status / category labels.
class AppStatusBadge extends StatelessWidget {
  final String label;
  final AppStatus status;
  final IconData? icon;
  final double fontSize;

  const AppStatusBadge({
    super.key,
    required this.label,
    required this.status,
    this.icon,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final fg = AppStatusColors.fg(context, status);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppStatusColors.bg(context, status),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppStatusColors.border(context, status)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
