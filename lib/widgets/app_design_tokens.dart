import 'package:flutter/material.dart';

/// Central design tokens for Waraqatak, providing consistent spacing,
/// radii, elevation, icon sizes, and semantic tints across the entire application.
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
  static const double space48 = 48.0;

  // Radii
  static const double radius4 = 4.0;
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

  static final BorderRadius br4 = BorderRadius.circular(radius4);
  static final BorderRadius br6 = BorderRadius.circular(radius6);
  static final BorderRadius br8 = BorderRadius.circular(radius8);
  static final BorderRadius br12 = BorderRadius.circular(radius12);
  static final BorderRadius br16 = BorderRadius.circular(radius16);
  static final BorderRadius br20 = BorderRadius.circular(radius20);
  static final BorderRadius br24 = BorderRadius.circular(radius24);
  static final BorderRadius brPill = BorderRadius.circular(radiusPill);

  // Icon Sizes
  static const double icon14 = 14.0;
  static const double icon16 = 16.0;
  static const double icon18 = 18.0;
  static const double icon20 = 20.0;
  static const double icon24 = 24.0;
  static const double icon28 = 28.0;
  static const double icon32 = 32.0;
  static const double icon48 = 48.0;

  // Accessibility Touch Target Minimum
  static const double minTouchTarget = 48.0;

  // Elevations
  static const double elevation0 = 0.0;
  static const double elevation1 = 1.0;
  static const double elevation2 = 2.0;
  static const double elevation4 = 4.0;

  // Semantic Colors - Light Theme
  static const Color success = Color(0xFF0D9488); // Deep Teal / Emerald
  static const Color successLight = Color(0xFFE6F4F1);
  static const Color danger = Color(0xFFDC2626); // Ruby Red
  static const Color dangerLight = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFD97706); // Warm Amber
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF2563EB); // Royal Blue
  static const Color infoLight = Color(0xFFEFF6FF);
  static const Color neutralMuted = Color(0xFF6B7280);
  static const Color neutralMutedLight = Color(0xFFF3F4F6);

  // Semantic Colors - Dark Theme (High contrast on dark surfaces)
  static const Color successDark = Color(0xFF2DD4BF); // Bright Teal
  static const Color successDarkContainer = Color(0xFF042F2E);
  static const Color dangerDark = Color(0xFFF87171); // Soft Red
  static const Color dangerDarkContainer = Color(0xFF450A0A);
  static const Color warningDark = Color(0xFFFBBF24); // Amber 400
  static const Color warningDarkContainer = Color(0xFF451A03);
  static const Color infoDark = Color(0xFF60A5FA); // Blue 400
  static const Color infoDarkContainer = Color(0xFF172554);
  static const Color neutralMutedDark = Color(0xFF9CA3AF);
  static const Color neutralMutedDarkContainer = Color(0xFF1F2937);

  // Dynamic Semantic Color Resolvers based on Theme Brightness
  static Color semanticSuccess(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? successDark
        : success;
  }

  static Color semanticSuccessContainer(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? successDarkContainer
        : successLight;
  }

  static Color semanticDanger(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? dangerDark
        : danger;
  }

  static Color semanticDangerContainer(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? dangerDarkContainer
        : dangerLight;
  }

  static Color semanticWarning(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? warningDark
        : warning;
  }

  static Color semanticWarningContainer(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? warningDarkContainer
        : warningLight;
  }

  static Color semanticInfo(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? infoDark : info;
  }

  static Color semanticInfoContainer(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? infoDarkContainer
        : infoLight;
  }

  static Color semanticNeutral(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? neutralMutedDark
        : neutralMuted;
  }

  static Color semanticNeutralContainer(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? neutralMutedDarkContainer
        : neutralMutedLight;
  }

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

  // Typography tokens with Tajawal font family and optimal Arabic line height
  static const TextStyle arabicTitleLarge = TextStyle(
    fontFamily: 'Tajawal',
    fontWeight: FontWeight.bold,
    fontSize: 22.0,
    height: 1.35,
  );

  static const TextStyle arabicTitleMedium = TextStyle(
    fontFamily: 'Tajawal',
    fontWeight: FontWeight.bold,
    fontSize: 18.0,
    height: 1.35,
  );

  static const TextStyle arabicTitleSmall = TextStyle(
    fontFamily: 'Tajawal',
    fontWeight: FontWeight.bold,
    fontSize: 15.0,
    height: 1.35,
  );

  static const TextStyle arabicBodyLarge = TextStyle(
    fontFamily: 'Tajawal',
    fontWeight: FontWeight.normal,
    fontSize: 16.0,
    height: 1.45,
  );

  static const TextStyle arabicBodyMedium = TextStyle(
    fontFamily: 'Tajawal',
    fontWeight: FontWeight.normal,
    fontSize: 14.0,
    height: 1.45,
  );

  static const TextStyle arabicBodySmall = TextStyle(
    fontFamily: 'Tajawal',
    fontWeight: FontWeight.normal,
    fontSize: 12.0,
    height: 1.45,
  );

  static const TextStyle arabicLabel = TextStyle(
    fontFamily: 'Tajawal',
    fontWeight: FontWeight.w600,
    fontSize: 13.0,
    height: 1.4,
  );
}
