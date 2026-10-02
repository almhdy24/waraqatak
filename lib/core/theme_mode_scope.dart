import 'package:flutter/material.dart';

/// Exposes the selected [ThemeMode] and a setter to the widget tree.
class ThemeModeScope extends InheritedWidget {
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onChangeThemeMode;

  const ThemeModeScope({
    super.key,
    required this.themeMode,
    required this.onChangeThemeMode,
    required super.child,
  });

  static ThemeModeScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeModeScope>();

  /// Stored value for [mode] in SharedPreferences.
  static String encode(ThemeMode mode) => mode.name;

  static ThemeMode decode(String? value) => ThemeMode.values.firstWhere(
        (m) => m.name == value,
        orElse: () => ThemeMode.light,
      );

  @override
  bool updateShouldNotify(ThemeModeScope oldWidget) =>
      themeMode != oldWidget.themeMode;
}
