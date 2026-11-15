import 'dart:async';
import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../services/access/session_manager.dart';
import '../services/access/user_session_scope.dart';
import '../services/analytics/analytics_service.dart';
import '../services/app_update_service.dart';
import '../widgets/analytics_notice_dialog.dart';
import '../widgets/responsive.dart';
import 'access/pin_lock_screen.dart';
import 'customers_screen.dart';
import 'documents_screen.dart';
import 'home_screen.dart';
import 'products_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// Global notifier to trigger a full refresh across all tabs and session state.
  static final ValueNotifier<int> globalRefreshNotifier = ValueNotifier<int>(0);

  /// Triggers a full refresh of all IndexedStack screens, data tokens, and session state.
  static void triggerGlobalRefresh() {
    globalRefreshNotifier.value++;
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final Set<int> _built = {0};
  int _documentsRefreshToken = 0;
  int _customersRefreshToken = 0;
  int _productsRefreshToken = 0;
  late final GlobalKey<HomeScreenState> _homeKey;
  bool _noticeChecked = false;

  void _triggerNoticeCheck() {
    if (_noticeChecked) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (SessionManager.instance.isLocked) return;
      _noticeChecked = true;
      AnalyticsNoticeDialog.checkAndShow(
        context,
        onOpenSettings: () => _select(4),
      );
    });
  }

  void _handleGlobalRefresh() {
    if (!mounted) return;
    unawaited(SessionManager.instance.retryInit());
    setState(() {
      _documentsRefreshToken++;
      _customersRefreshToken++;
      _productsRefreshToken++;
    });
    _homeKey.currentState?.reload();
  }

  @override
  void initState() {
    super.initState();
    MainShell.globalRefreshNotifier.addListener(_handleGlobalRefresh);
    _homeKey = GlobalKey<HomeScreenState>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppUpdateService.instance.checkForUpdate(
          context: context,
          manual: false,
        );
        try {
          final lang = Localizations.localeOf(context).languageCode == 'ar'
              ? 'ar'
              : 'en';
          final brightness = MediaQuery.of(context).platformBrightness;
          final theme = brightness == Brightness.dark ? 'dark' : 'light';
          AnalyticsService.instance.track(AnalyticsEvent.appOpened, {
            'language': lang,
            'theme': theme,
            'multi_user': SessionManager.instance.isMultiUserEnabled,
          });
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    MainShell.globalRefreshNotifier.removeListener(_handleGlobalRefresh);
    super.dispose();
  }

  void _select(int i) {
    _built.add(i);
    setState(() => _index = i);
    const screens = ['home', 'invoices', 'customers', 'products', 'settings'];
    if (i >= 0 && i < screens.length) {
      try {
        AnalyticsService.instance.track(AnalyticsEvent.screenViewed, {
          'screen': screens[i],
        });
      } catch (_) {}
    }
    switch (i) {
      case 0:
        _homeKey.currentState?.reload();
      case 1:
        _documentsRefreshToken++;
      case 2:
        _customersRefreshToken++;
      case 3:
        _productsRefreshToken++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = UserSessionScope.of(context);
    if (session.isLocked) {
      return const PinLockScreen();
    }

    _triggerNoticeCheck();

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _index != 0) _select(0);
      },
      child: _buildShell(context),
    );
  }

  Widget _buildShell(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destinations = [
      (Icons.home_outlined, Icons.home, l10n.home),
      (Icons.description_outlined, Icons.description, l10n.documents),
      (Icons.people_outline, Icons.people, l10n.customers),
      (Icons.inventory_2_outlined, Icons.inventory_2, l10n.products),
      (Icons.settings_outlined, Icons.settings, l10n.settings),
    ];
    final pages = IndexedStack(
      index: _index,
      children: [
        HomeScreen(key: _homeKey),
        _built.contains(1)
            ? DocumentsScreen(refreshToken: _documentsRefreshToken)
            : const SizedBox.shrink(),
        _built.contains(2)
            ? CustomersScreen(refreshToken: _customersRefreshToken)
            : const SizedBox.shrink(),
        _built.contains(3)
            ? ProductsScreen(refreshToken: _productsRefreshToken)
            : const SizedBox.shrink(),
        _built.contains(4) ? const SettingsScreen() : const SizedBox.shrink(),
      ],
    );

    // Tablets, foldables and landscape phones: side navigation rail.
    if (Breakpoints.useRail(context)) {
      final extended =
          MediaQuery.sizeOf(context).width >= Breakpoints.extendedRail;
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              right: false,
              left: false,
              child: NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: _select,
                extended: extended,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                groupAlignment: -0.85,
                destinations: [
                  for (final d in destinations)
                    NavigationRailDestination(
                      icon: Icon(d.$1),
                      selectedIcon: Icon(d.$2),
                      label: Text(d.$3),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: pages),
          ],
        ),
      );
    }

    return Scaffold(
      body: pages,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.$1),
              selectedIcon: Icon(d.$2),
              label: d.$3,
            ),
        ],
      ),
    );
  }
}
