import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme_mode_scope.dart';
import 'database/database_helper.dart';
import 'localization/app_localizations.dart';
import 'services/accounting/journal_backfill_service.dart';
import 'services/app_diagnostics_service.dart';
import 'services/license_service.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

Future<void> main() async {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        developer.log(
          'FlutterError',
          error: details.exception,
          stackTrace: details.stack,
        );
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        developer.log('PlatformDispatcher', error: error, stackTrace: stack);
        return true;
      };

      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await DatabaseHelper.instance.database;
      await AppDiagnosticsService.instance.init();
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('language') ?? 'ar';
      final themeMode = ThemeModeScope.decode(prefs.getString('theme_mode'));
      runApp(WarqatekApp(initialLanguage: lang, initialThemeMode: themeMode));

      // Asynchronously trigger journal backfill in background after UI renders
      unawaited(
        JournalBackfillService.backfillIfNeeded().catchError((e, st) {
          developer.log('Startup backfill error', error: e, stackTrace: st);
          return 0;
        }),
      );
    },
    (error, stack) {
      developer.log('Uncaught zone error', error: error, stackTrace: stack);
      AppDiagnosticsService.instance.recordError(
        error,
        stack,
        operation: 'unhandled_exception',
      );
    },
  );
}

class WarqatekApp extends StatefulWidget {
  final String initialLanguage;
  final ThemeMode initialThemeMode;
  const WarqatekApp({
    super.key,
    required this.initialLanguage,
    this.initialThemeMode = ThemeMode.light,
  });

  @override
  State<WarqatekApp> createState() => _WarqatekAppState();
}

class _WarqatekAppState extends State<WarqatekApp> with WidgetsBindingObserver {
  late String _langCode;
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _langCode = widget.initialLanguage;
    _themeMode = widget.initialThemeMode;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-evaluates the entitlement when the app returns to the foreground, so
  /// an expiry that passed while it was in the background takes effect.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recheckLicense();
  }

  Future<void> _recheckLicense() async {
    try {
      await LicenseService.instance.checkEntitlement(force: true);
    } catch (_) {}
  }

  Future<void> changeThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', ThemeModeScope.encode(mode));
    setState(() => _themeMode = mode);
  }

  Future<void> changeLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
    setState(() => _langCode = lang);
  }

  @override
  Widget build(BuildContext context) {
    return LanguageProvider(
      langCode: _langCode,
      onChangeLanguage: changeLanguage,
      child: ThemeModeScope(
        themeMode: _themeMode,
        onChangeThemeMode: changeThemeMode,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _themeMode,
          locale: Locale(_langCode),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => _SystemInsets(child: child!),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}

/// Keeps every route clear of the system navigation bar and of display
/// cutouts in landscape (Android 15+ always draws edge-to-edge).
///
/// App bars still extend under the status bar; the bottom inset is painted
/// with the surface color so it blends with the navigation bar.
class _SystemInsets extends StatelessWidget {
  final Widget child;
  const _SystemInsets({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          ),
      child: ColoredBox(
        color: theme.colorScheme.surface,
        child: SafeArea(top: false, child: child),
      ),
    );
  }
}
