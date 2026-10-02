import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/database_helper.dart';
import 'localization/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
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
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    await DatabaseHelper.instance.database;
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('language') ?? 'ar';
    runApp(WarqatekApp(initialLanguage: lang));
  }, (error, stack) {
    developer.log('Uncaught zone error', error: error, stackTrace: stack);
  });
}

class WarqatekApp extends StatefulWidget {
  final String initialLanguage;
  const WarqatekApp({super.key, required this.initialLanguage});

  @override
  State<WarqatekApp> createState() => _WarqatekAppState();
}

class _WarqatekAppState extends State<WarqatekApp> {
  late String _langCode;

  @override
  void initState() {
    super.initState();
    _langCode = widget.initialLanguage;
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
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ورقتك',
        theme: AppTheme.lightTheme,
        locale: Locale(_langCode),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SplashScreen(),
      ),
    );
  }
}