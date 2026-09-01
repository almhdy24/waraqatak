import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/database_helper.dart';
import 'localization/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  final prefs = await SharedPreferences.getInstance();
  final lang = prefs.getString('language') ?? 'ar';
  runApp(WarqatekApp(initialLanguage: lang));
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