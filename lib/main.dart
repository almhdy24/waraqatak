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
import 'services/access/session_manager.dart';
import 'services/access/user_session_scope.dart';
import 'services/accounting/journal_backfill_service.dart';
import 'services/analytics/analytics_service.dart';
import 'services/app_diagnostics_service.dart';
import 'services/app_update_service.dart';
import 'services/license_service.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';
import 'utils/quick_sale_settings.dart';

Future<void> main() async {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      final previousFlutterOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        previousFlutterOnError?.call(details);
        FlutterError.presentError(details);
        developer.log(
          'FlutterError',
          error: details.exception,
          stackTrace: details.stack,
        );
        AnalyticsService.instance.recordError(
          details.exception,
          details.stack,
          'flutter_error',
        );
      };

      final previousPlatformOnError = PlatformDispatcher.instance.onError;
      PlatformDispatcher.instance.onError = (error, stack) {
        developer.log('PlatformDispatcher', error: error, stackTrace: stack);
        AnalyticsService.instance.recordError(
          error,
          stack,
          'platform_dispatcher',
        );
        if (previousPlatformOnError != null) {
          return previousPlatformOnError(error, stack);
        }
        return true;
      };

      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      final prefs = await SharedPreferences.getInstance();
      final lastRecordedDbVersion = prefs.getInt('last_app_db_version');
      await DatabaseHelper.instance.database;
      if (lastRecordedDbVersion != null &&
          lastRecordedDbVersion < DatabaseHelper.dbVersion) {
        await AnalyticsService.recordMigrationResult(
          fromVersion: lastRecordedDbVersion,
          toVersion: DatabaseHelper.dbVersion,
          ok: true,
        );
      }
      await prefs.setInt('last_app_db_version', DatabaseHelper.dbVersion);

      await AppDiagnosticsService.instance.init();
      await SessionManager.instance.init();
      await QuickSaleSettings.instance.load(prefs);
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
      AnalyticsService.instance.recordError(
        error,
        stack,
        'zoned_guarded',
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
  DateTime? _pausedAt;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedAt != null) {
        final elapsed = DateTime.now().difference(_pausedAt!);
        final autoLockMinutes = SessionManager.instance.autoLockMinutes;
        if (autoLockMinutes > 0 && elapsed.inMinutes >= autoLockMinutes) {
          SessionManager.instance.lock();
        }
        _pausedAt = null;
      }
      _recheckLicense();
      unawaited(AppUpdateService.instance.checkForUpdate());
    }
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
    return UserSessionScope(
      notifier: SessionManager.instance,
      child: LanguageProvider(
        langCode: _langCode,
        onChangeLanguage: changeLanguage,
        child: ThemeModeScope(
          themeMode: _themeMode,
          onChangeThemeMode: changeThemeMode,
          child: MaterialApp(
            navigatorKey: SessionManager.navigatorKey,
            scaffoldMessengerKey: AppUpdateService.scaffoldMessengerKey,
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
            builder: (context, child) => UserSessionScope(
              notifier: SessionManager.instance,
              child: Listener(
                onPointerDown: (_) => SessionManager.instance.recordActivity(),
                behavior: HitTestBehavior.translucent,
                child: _SystemInsets(child: child!),
              ),
            ),
            home: const SplashScreen(),
          ),
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
