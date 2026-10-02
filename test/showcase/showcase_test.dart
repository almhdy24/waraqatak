// Feature showcase screenshots, rendered from a real (SQLite) demo store.
//
// Skipped unless SHOWCASE is set. To regenerate docs/showcase/:
//   SHOWCASE=1 flutter test test/showcase/showcase_test.dart --update-goldens
//   SHOWCASE=1 flutter test test/showcase/showcase_test.dart --update-goldens --dart-define=LANG=en
// then rasterize the sample PDFs (see docs/showcase/README.md).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/core/theme_mode_scope.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/screens/about_screen.dart';
import 'package:warqatek/screens/customer_detail_screen.dart';
import 'package:warqatek/screens/customers_screen.dart';
import 'package:warqatek/screens/document_detail_screen.dart';
import 'package:warqatek/screens/documents_screen.dart';
import 'package:warqatek/screens/inventory_screen.dart';
import 'package:warqatek/screens/invoice_screen.dart';
import 'package:warqatek/screens/main_shell.dart';
import 'package:warqatek/screens/pdf_customize_screen.dart';
import 'package:warqatek/screens/products_screen.dart';
import 'package:warqatek/screens/quick_sale_screen.dart';
import 'package:warqatek/screens/reports/accounting_screen.dart';
import 'package:warqatek/screens/reports/sales_report_screen.dart';
import 'package:warqatek/screens/reports_screen.dart';
import 'package:warqatek/screens/settings_screen.dart';
import 'package:warqatek/services/accounting/ledger.dart';
import 'package:warqatek/services/accounting/ledger_service.dart';
import 'package:warqatek/models/date_range_filter.dart';
import 'package:warqatek/services/pdf_service.dart';
import 'package:warqatek/utils/pdf_settings.dart';
import 'package:warqatek/utils/print_settings.dart';
import 'package:warqatek/theme.dart';

import 'store_seed.dart';

final bool enabled = Platform.environment.containsKey('SHOWCASE');
const lang = String.fromEnvironment('LANG', defaultValue: 'ar');
const outDir = '../../docs/showcase/$lang';

const phone = Size(786, 1702); // 393 × 851 dp at 2×
const tablet = Size(1920, 1200); // 1280 × 800 dp at 1.5×

Future<void> loadFonts() async {
  final tajawal = FontLoader('Tajawal')
    ..addFont(rootBundle.load('assets/fonts/Tajawal-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
  await tajawal.load();
  // Material icons ship with the Flutter SDK, next to the test engine.
  final root = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final iconFile = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(iconFile.readAsBytesSync())));
  await icons.load();
}

void mockPlugins() {
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  m.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (call) async => null);
  m.setMockMethodCallHandler(const MethodChannel('com.elmahdi.waraqatak/device'), (call) async => null);
  m.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (call) async => {
            'appName': 'ورقتك',
            'packageName': 'com.elmahdi.waraqatak',
            'version': '1.1.0',
            'buildNumber': '4',
          });
}

Widget app(Widget home, {ThemeMode mode = ThemeMode.light}) => LanguageProvider(
      langCode: lang,
      onChangeLanguage: (_) async {},
      child: ThemeModeScope(
        themeMode: mode,
        onChangeThemeMode: (_) async {},
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          locale: const Locale(lang),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: home,
        ),
      ),
    );

/// Lets real database I/O finish, then renders frames.
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await t.pump(const Duration(milliseconds: 250));
  }
}

Future<void> capture(WidgetTester t, String name) async {
  // Real elevation shadows instead of the test renderer's black outlines;
  // restored before the test ends (flutter_test checks it).
  debugDisableShadows = false;
  try {
    // Repaint everything so cached layers pick up the shadow setting.
    void repaint(RenderObject r) {
      r.markNeedsPaint();
      r.visitChildren(repaint);
    }
    for (final view in t.binding.renderViews) {
      repaint(view);
    }
    await t.pump();
    await settle(t);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('$outDir/$name.png'));
  } finally {
    debugDisableShadows = true;
  }
}

Future<void> open(WidgetTester t, Widget home,
    {Size size = phone, ThemeMode mode = ThemeMode.light}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = size == phone ? 2 : 1.5;
  addTearDown(t.view.reset);
  await t.pumpWidget(app(home, mode: mode));
  await settle(t);
}

Future<void> shot(WidgetTester t, String name, Widget home,
    {Size size = phone, ThemeMode mode = ThemeMode.light}) async {
  await open(t, home, size: size, mode: mode);
  await capture(t, name);
}

/// The demo store's whole history (the seed goes back 45 days).
DateRangeFilter demoPeriod() {
  final now = DateTime.now();
  return DateRangeFilter.custom(now.subtract(const Duration(days: 45)), now);
}

Future<void> tapText(WidgetTester t, String text) async {
  await t.tap(find.text(text).first);
  await settle(t);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = AppLocalizations(lang);
  late StoreSeed store;

  group('showcase', skip: !enabled, () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({'language': lang});
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
      final dir = Directory.systemTemp.createTempSync('showcase');
      await databaseFactory.setDatabasesPath(dir.path);
      mockPlugins();
      await loadFonts();
      store = await seedStore(lang: lang);
      await PdfSettings.save(const PdfStyleSettings().copyWith(
          footerText: lang == 'ar' ? 'شكراً لتسوقكم معنا' : 'Thank you for shopping with us'));
    });

    testWidgets('home', (t) => shot(t, '01_home', const MainShell()));
    testWidgets('home dark', (t) => shot(t, '02_home_dark', const MainShell(), mode: ThemeMode.dark));

    testWidgets('quick sale', (t) async {
      await open(t, const QuickSaleScreen());
      await capture(t, '03_quick_sale');
      for (final k in ['chg', 'chg', 'cbl', 'scr', 'ins']) {
        await t.tap(find.text(store.products[k]!.name).first);
        await t.pump();
      }
      await capture(t, '04_quick_sale_items');
      await tapText(t, l10n.posViewCart);
      await capture(t, '05_quick_sale_cart');
    });

    testWidgets('invoice form', (t) => shot(t, '06_new_invoice', const InvoiceScreen()));
    testWidgets('documents', (t) => shot(t, '07_documents', const DocumentsScreen()));
    testWidgets('invoice details', (t) =>
        shot(t, '08_invoice_details', DocumentDetailScreen(documentId: store.documents['nileInvoice']!)));
    testWidgets('customers', (t) => shot(t, '09_customers', const CustomersScreen()));
    testWidgets('customer account', (t) =>
        shot(t, '10_customer_account', CustomerDetailScreen(contact: store.contacts['nile']!)));
    testWidgets('products', (t) => shot(t, '11_products', const ProductsScreen()));
    testWidgets('inventory', (t) => shot(t, '12_inventory', const InventoryScreen()));
    testWidgets('reports', (t) => shot(t, '13_reports', const ReportsScreen()));
    testWidgets('sales report', (t) => shot(t, '14_sales_report', const SalesReportScreen()));

    testWidgets('accounting', (t) async {
      await open(t, AccountingScreen(initialRange: demoPeriod()));
      await capture(t, '15_income_statement');
      await tapText(t, l10n.balanceSheet);
      await capture(t, '16_balance_sheet');
      await tapText(t, l10n.trialBalance);
      await capture(t, '17_trial_balance');
      await tapText(t, l10n.chartOfAccounts);
      await capture(t, '18_accounts');
    });

    testWidgets('account ledger', (t) async {
      final book = await t.runAsync(LedgerService.load);
      await shot(
        t,
        '19_account_ledger',
        AccountLedgerScreen(
          entries: book!.entries,
          account: Accounts.cash,
          range: demoPeriod(),
          symbol: 'ج.س',
        ),
      );
    });

    testWidgets('pdf design', (t) => shot(t, '20_pdf_design', const PdfCustomizeScreen()));
    testWidgets('settings', (t) => shot(t, '21_settings', const SettingsScreen()));
    testWidgets('about', (t) => shot(t, '22_about', const AboutScreen()));

    testWidgets('tablet home', (t) => shot(t, '23_tablet_home', const MainShell(), size: tablet));
    testWidgets('tablet quick sale', (t) async {
      await open(t, const QuickSaleScreen(), size: tablet);
      for (final k in ['ear', 'cse', 'scr', 'ins', 'ins']) {
        await t.tap(find.text(store.products[k]!.name).first);
        await t.pump();
      }
      await capture(t, '24_tablet_quick_sale');
    });
    testWidgets('tablet accounting', (t) => shot(t, '25_tablet_accounting', AccountingScreen(initialRange: demoPeriod()), size: tablet));

    test('sample PDFs', () async {
      final db = DatabaseHelper.instance;
      Future<void> pdf(String key, String name, PaperSize size) async {
        final doc = (await db.getDocumentById(store.documents[key]!))!;
        final bytes = await PdfService.generateDocumentPdf(
          doc: doc,
          business: store.business,
          contact: doc.contactId == null ? null : await db.getContactById(doc.contactId!),
          items: await db.getDocumentItems(doc.id!),
          l10n: l10n,
          paperSize: size,
        );
        File('docs/showcase/$lang/$name.pdf')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes);
      }

      await pdf('nileInvoice', 'pdf_invoice_a4', PaperSize.a4);
      await pdf('schoolQuote', 'pdf_quotation_a4', PaperSize.a4);
      await pdf('sale11', 'pdf_receipt_80mm', PaperSize.thermal80mm);
    });
  });
}
