import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../localization/app_localizations.dart';
import '../services/license_service.dart';
import '../services/subscription_service.dart';
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
  }

  Future<void> _init() async {
    // Background server re-check of a stored license (at most once a day).
    // Never blocks startup; offline users keep their current state.
    unawaited(SubscriptionService.revalidateStoredLicense());

    // Pre-warm the entitlement cache while the splash is visible.
    // HomeScreen reads the cache on load; no blocking gate here — the app
    // is never fully locked, only paid creation actions are gated.
    await Future.wait([
      Future<void>(() async {
        try {
          await LicenseService.instance.checkEntitlement();
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
      backgroundColor: const Color(0xFFF8F7F3),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/logo.svg',
              width: 110,
              height: 110,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.appTitle,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF202124),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tagline,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
