import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
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
  late final GlobalKey<HomeScreenState> _homeKey;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _homeKey = GlobalKey<HomeScreenState>();
    _screens = [
      HomeScreen(key: _homeKey),
      const DocumentsScreen(),
      const CustomersScreen(),
      const ProductsScreen(),
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (i == 0) {
            _homeKey.currentState?.reload();
          }
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: l10n.home),
          NavigationDestination(icon: const Icon(Icons.description_outlined), selectedIcon: const Icon(Icons.description), label: l10n.documents),
          NavigationDestination(icon: const Icon(Icons.people_outline), selectedIcon: const Icon(Icons.people), label: l10n.customers),
          NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2), label: l10n.products),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: l10n.settings),
        ],
      ),
    );
  }
}