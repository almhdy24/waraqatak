import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../localization/app_localizations.dart';
import '../services/access/session_manager.dart';
import '../services/analytics/analytics_service.dart';
import '../services/license_service.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AnalyticsService.instance.initialize());
    });
  }

  Future<void> _init() async {
    // Pre-warm the entitlement cache while the splash is visible.
    // HomeScreen reads the cache on load; no blocking gate here — the app
    // is never fully locked, only paid creation actions are gated.
    await Future.wait([
      Future<void>(() async {
        try {
          await LicenseService.instance.checkEntitlement();
        } catch (_) {}
      }),
      Future<void>(() async {
        try {
          await SessionManager.instance.init();
        } catch (_) {}
      }),
      Future<void>.delayed(const Duration(milliseconds: 1200)),
    ]);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/logo.svg', width: 110, height: 110),
            const SizedBox(height: 24),
            Text(
              l10n.appTitle,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tagline,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
