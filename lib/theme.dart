import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/app_design_tokens.dart';

class AppTheme {
  static const primary = Color(0xFF155E63);
  static const accent = Color(0xFF6FC3B8);
  static const background = Color(0xFFF8F7F3);
  static const surface = Colors.white;
  static const text = Color(0xFF202124);
  static const secondaryText = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const danger = Color(0xFFDC2626);

  // Dark palette (same brand family).
  static const darkBackground = Color(0xFF0F1716);
  static const darkSurface = Color(0xFF17211F);
  static const darkBorder = Color(0xFF2A3634);
  static const darkPrimary = Color(0xFF6FC3B8);
  static const darkText = Color(0xFFE6EAE9);
  static const darkSecondaryText = Color(0xFF9CA3AF);

  static ThemeData get lightTheme => _build(
        brightness: Brightness.light,
        scheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: accent,
          surface: surface,
          error: danger,
          outlineVariant: border,
        ),
        background: background,
        textColor: text,
      );

  static ThemeData get darkTheme => _build(
        brightness: Brightness.dark,
        scheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.dark,
          primary: darkPrimary,
          onPrimary: const Color(0xFF00201E),
          secondary: accent,
          surface: darkSurface,
          error: const Color(0xFFFF8A80),
          outlineVariant: darkBorder,
        ),
        background: darkBackground,
        textColor: darkText,
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color background,
    required Color textColor,
  }) {
    final isDark = brightness == Brightness.dark;
    final overlay = (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
        .copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    );
    final radius12 = AppDesignTokens.br12;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Tajawal',
      visualDensity: VisualDensity.standard,
      textTheme: TextTheme(
        displayLarge: TextStyle(fontFamily: 'Tajawal', height: 1.3, color: textColor),
        displayMedium: TextStyle(fontFamily: 'Tajawal', height: 1.3, color: textColor),
        displaySmall: TextStyle(fontFamily: 'Tajawal', height: 1.3, color: textColor),
        headlineLarge: TextStyle(fontFamily: 'Tajawal', height: 1.35, fontWeight: FontWeight.bold, color: textColor),
        headlineMedium: TextStyle(fontFamily: 'Tajawal', height: 1.35, fontWeight: FontWeight.bold, color: textColor),
        headlineSmall: TextStyle(fontFamily: 'Tajawal', height: 1.35, fontWeight: FontWeight.bold, color: textColor),
        titleLarge: TextStyle(fontFamily: 'Tajawal', height: 1.35, fontWeight: FontWeight.bold, fontSize: 20, color: textColor),
        titleMedium: TextStyle(fontFamily: 'Tajawal', height: 1.35, fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
        titleSmall: TextStyle(fontFamily: 'Tajawal', height: 1.35, fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
        bodyLarge: TextStyle(fontFamily: 'Tajawal', height: 1.45, fontSize: 16, color: textColor),
        bodyMedium: TextStyle(fontFamily: 'Tajawal', height: 1.45, fontSize: 14, color: textColor),
        bodySmall: TextStyle(fontFamily: 'Tajawal', height: 1.45, fontSize: 12, color: scheme.onSurfaceVariant),
        labelLarge: TextStyle(fontFamily: 'Tajawal', height: 1.4, fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
        labelMedium: TextStyle(fontFamily: 'Tajawal', height: 1.4, fontWeight: FontWeight.w600, fontSize: 12, color: textColor),
        labelSmall: TextStyle(fontFamily: 'Tajawal', height: 1.4, fontSize: 11, color: scheme.onSurfaceVariant),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        systemOverlayStyle: overlay,
        titleTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: textColor,
          height: 1.35,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(64, AppDesignTokens.minTouchTarget),
          shape: RoundedRectangleBorder(borderRadius: radius12),
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
            height: 1.35,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppDesignTokens.minTouchTarget),
          shape: RoundedRectangleBorder(borderRadius: radius12),
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
            height: 1.35,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppDesignTokens.minTouchTarget),
          shape: RoundedRectangleBorder(borderRadius: radius12),
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, AppDesignTokens.minTouchTarget),
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            AppDesignTokens.minTouchTarget,
            AppDesignTokens.minTouchTarget,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          color: scheme.onSurfaceVariant,
          height: 1.35,
        ),
        hintStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
          height: 1.35,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: radius12),
        minVerticalPadding: 10,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surface,
        selectedColor: scheme.primary.withValues(alpha: 0.15),
        labelStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 13,
          color: scheme.onSurface,
          height: 1.35,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.onPrimary;
          }
          return scheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return scheme.outlineVariant;
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontFamily: 'Tajawal', fontSize: 12, height: 1.35),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.15),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          fontWeight: FontWeight.bold,
          color: scheme.primary,
          height: 1.35,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          color: scheme.onSurfaceVariant,
          height: 1.35,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
    );
  }
}
