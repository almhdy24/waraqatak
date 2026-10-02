import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../widgets/responsive.dart';
import 'customers_screen.dart';
import 'documents_screen.dart';
import 'home_screen.dart';
import 'products_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  int _documentsRefreshToken = 0;
  int _customersRefreshToken = 0;
  int _productsRefreshToken = 0;
  late final GlobalKey<HomeScreenState> _homeKey;

  @override
  void initState() {
    super.initState();
    _homeKey = GlobalKey<HomeScreenState>();
  }

  void _select(int i) {
    setState(() => _index = i);
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
        DocumentsScreen(refreshToken: _documentsRefreshToken),
        CustomersScreen(refreshToken: _customersRefreshToken),
        ProductsScreen(refreshToken: _productsRefreshToken),
        const SettingsScreen(),
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
