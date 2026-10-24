import 'package:flutter/material.dart';

/// Central design tokens for Waraqatak, providing consistent spacing,
/// radii, elevation, and semantic tints across the entire application.
class AppDesignTokens {
  AppDesignTokens._();

  // Spacing
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;

  // Radii
  static const double radius6 = 6.0;
  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius20 = 20.0;
  static const double radius24 = 24.0;
  static const double radiusPill = 999.0;

  // Semantic Radii
  static const double cardRadius = radius16;
  static const double buttonRadius = radius12;
  static const double smallRadius = radius8;

  static final BorderRadius br6 = BorderRadius.circular(radius6);
  static final BorderRadius br8 = BorderRadius.circular(radius8);
  static final BorderRadius br12 = BorderRadius.circular(radius12);
  static final BorderRadius br16 = BorderRadius.circular(radius16);
  static final BorderRadius br20 = BorderRadius.circular(radius20);
  static final BorderRadius brPill = BorderRadius.circular(radiusPill);

  // Semantic Colors (Accounting & Operations)
  static const Color success = Color(0xFF0D9488); // Deep Teal / Emerald
  static const Color successLight = Color(0xFFE6F4F1);
  static const Color danger = Color(0xFFDC2626); // Ruby Red
  static const Color dangerLight = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFD97706); // Warm Amber
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF2563EB); // Royal Blue
  static const Color infoLight = Color(0xFFEFF6FF);
  static const Color neutralMuted = Color(0xFF6B7280);

  // Subtle shadows for elevated cards
  static List<BoxShadow> softShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) return const [];
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.03),
        offset: const Offset(0, 2),
        blurRadius: 8,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.02),
        offset: const Offset(0, 1),
        blurRadius: 3,
      ),
    ];
  }
}
