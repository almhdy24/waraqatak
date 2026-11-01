import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/theme.dart';
import 'package:warqatek/widgets/app_design_tokens.dart';

double _relativeLuminance(Color c) {
  double chan(double v) {
    final v8 = v / 255.0;
    return v8 <= 0.03928
        ? v8 / 12.92
        : math.pow((v8 + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = chan((c.r * 255).toDouble());
  final g = chan((c.g * 255).toDouble());
  final b = chan((c.b * 255).toDouble());
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('Theme WCAG AA Contrast Tests', () {
    test('Light theme: body text vs background and surface >= 4.5:1', () {
      final light = AppTheme.lightTheme;
      final bg = light.scaffoldBackgroundColor;
      final surface = light.colorScheme.surface;
      const text = AppTheme.text;

      final bgRatio = _contrastRatio(text, bg);
      final surfaceRatio = _contrastRatio(text, surface);

      expect(bgRatio, greaterThanOrEqualTo(4.5),
          reason: 'Text vs Background contrast should be >= 4.5:1');
      expect(surfaceRatio, greaterThanOrEqualTo(4.5),
          reason: 'Text vs Surface contrast should be >= 4.5:1');
    });

    test('Light theme: primary on surface/background >= 3:1 for UI elements', () {
      final light = AppTheme.lightTheme;
      final bg = light.scaffoldBackgroundColor;
      final surface = light.colorScheme.surface;
      final primary = light.colorScheme.primary;

      expect(_contrastRatio(primary, bg), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(primary, surface), greaterThanOrEqualTo(4.5));
    });

    test('Light theme: onPrimary vs primary >= 4.5:1', () {
      final light = AppTheme.lightTheme;
      final onPrimary = light.colorScheme.onPrimary;
      final primary = light.colorScheme.primary;

      expect(_contrastRatio(onPrimary, primary), greaterThanOrEqualTo(4.5));
    });

    test('Dark theme: text vs darkBackground and darkSurface >= 4.5:1', () {
      final dark = AppTheme.darkTheme;
      final bg = dark.scaffoldBackgroundColor;
      final surface = dark.colorScheme.surface;
      const text = AppTheme.darkText;

      final bgRatio = _contrastRatio(text, bg);
      final surfaceRatio = _contrastRatio(text, surface);

      expect(bgRatio, greaterThanOrEqualTo(4.5),
          reason: 'Dark text vs Dark Background contrast should be >= 4.5:1');
      expect(surfaceRatio, greaterThanOrEqualTo(4.5),
          reason: 'Dark text vs Dark Surface contrast should be >= 4.5:1');
    });

    test('Dark theme: onPrimary vs primary >= 4.5:1', () {
      final dark = AppTheme.darkTheme;
      final onPrimary = dark.colorScheme.onPrimary;
      final primary = dark.colorScheme.primary;

      expect(_contrastRatio(onPrimary, primary), greaterThanOrEqualTo(4.5));
    });

    test('Dark theme: primary vs darkSurface >= 3.0:1 for large text/icons', () {
      final dark = AppTheme.darkTheme;
      final surface = dark.colorScheme.surface;
      final primary = dark.colorScheme.primary;

      expect(_contrastRatio(primary, surface), greaterThanOrEqualTo(3.0));
    });

    test('Semantic status colors: Light theme contrast vs white surface', () {
      // Body or badge text threshold: at least 3.0:1 for large/bold text, 4.5:1 for body
      expect(_contrastRatio(AppDesignTokens.danger, Colors.white),
          greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppDesignTokens.success, Colors.white),
          greaterThanOrEqualTo(3.0));
      expect(_contrastRatio(AppDesignTokens.warning, Colors.white),
          greaterThanOrEqualTo(3.0));
      expect(_contrastRatio(AppDesignTokens.info, Colors.white),
          greaterThanOrEqualTo(4.5));
    });

    test('Semantic status colors: Dark theme contrast vs dark surface', () {
      const darkSurface = AppTheme.darkSurface;
      expect(_contrastRatio(AppDesignTokens.dangerDark, darkSurface),
          greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppDesignTokens.successDark, darkSurface),
          greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppDesignTokens.warningDark, darkSurface),
          greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(AppDesignTokens.infoDark, darkSurface),
          greaterThanOrEqualTo(4.5));
    });
  });
}
