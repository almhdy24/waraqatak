import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/stock_movement.dart';
import 'package:warqatek/screens/database_diagnostic_screen.dart';

Widget _buildTestApp({String langCode = 'ar', required Widget child}) {
  return LanguageProvider(
    langCode: langCode,
    onChangeLanguage: (_) async {},
    child: MaterialApp(locale: Locale(langCode), home: child),
  );
}

Future<void> _pumpUntilDiagnosticsLoaded(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late DatabaseExecutor rawDb;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('diagnostic_ui_test');
    await databaseFactory.setDatabasesPath(tempDir.path);

    final db = DatabaseHelper.instance;
    await db.insertBusiness(
      const Business(
        name: 'مؤسسة الاختبار للواجهة',
        ownerName: 'فاحص الواجهة',
        phone: '0123456789',
        address: 'الخرطوم',
        taxRate: 0,
      ),
    );
    rawDb = await db.database;
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  testWidgets('1. Clean report rendering using actual report semantics', (
    tester,
  ) async {
    final l10n = AppLocalizations('ar');

    await tester.pumpWidget(
      _buildTestApp(
        langCode: 'ar',
        child: DatabaseDiagnosticScreen(db: rawDb),
      ),
    );
    await _pumpUntilDiagnosticsLoaded(tester);

    // Clean state title and description must be rendered
    expect(find.text(l10n.diagnosticsCleanTitle), findsOneWidget);
    expect(find.text(l10n.diagnosticsCleanDesc), findsOneWidget);

    // Total checks label should be visible
    expect(find.textContaining(l10n.diagnosticsTotalChecks), findsOneWidget);

    // Zero error summary cards
    expect(find.text(l10n.diagnosticsSummaryErrors), findsNothing);
  });

  testWidgets('2. Error, warning, and informational findings rendering', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final l10n = AppLocalizations('ar');

    late int brokenDocMovementId;
    late int uncostedProdId;
    late int zeroCostProdId;

    await tester.runAsync(() async {
      await rawDb.execute('PRAGMA foreign_keys = OFF');
      // A. Insert an error finding: broken document reference in stock movement
      brokenDocMovementId = await rawDb.insert('stock_movements', {
        'product_id': 1,
        'type': StockMovement.typeOpening,
        'quantity': 10.0,
        'reference_document_id': 99999, // Broken reference -> Error
        'date': DateTime.now().toIso8601String(),
      });

      // B. Insert a warning finding: negative stock balance
      uncostedProdId = await rawDb.insert('products', {
        'name': 'منتج رصيد سالب للاختبار',
        'type': 'product',
        'stock_quantity': -15.0, // Negative stock -> Warning
        'purchase_price': 10.0,
        'sale_price': 20.0,
      });

      // C. Insert an info finding: physical stock held with unknown cost basis
      zeroCostProdId = await rawDb.insert('products', {
        'name': 'منتج تكلفة مجهولة للاختبار',
        'type': 'product',
        'stock_quantity': 25.0,
        'purchase_price': 0.0,
        'average_cost': null,
        'cost_status': StockMovement.costStatusUnknown, // Info finding
      });
    });

    try {
      await tester.pumpWidget(
        _buildTestApp(
          langCode: 'ar',
          child: DatabaseDiagnosticScreen(db: rawDb),
        ),
      );
      await _pumpUntilDiagnosticsLoaded(tester);

      // 1. Metric cards are present
      expect(find.text(l10n.diagnosticsSummaryErrors), findsOneWidget);
      expect(find.text(l10n.diagnosticsSummaryWarnings), findsOneWidget);
      expect(find.text(l10n.diagnosticsSummaryInfo), findsOneWidget);

      // 2. Finding titles are present
      expect(
        find.text('حركات مخزون مرتبطة بمستندات غير موجودة'),
        findsOneWidget,
      );
      expect(find.text('رصيد مخزون سالب للبضاعة'), findsOneWidget);
      expect(
        find.text('مخزون فعلي متوفر بتكلفة مجهولة أو غير محددة'),
        findsOneWidget,
      );

      // 3. Category tags are present
      expect(find.text(l10n.diagnosticsCategoryOrphaned), findsWidgets);
      expect(find.text(l10n.diagnosticsCategoryNegativeStock), findsWidgets);
      expect(find.text(l10n.diagnosticsCategoryCosting), findsWidgets);
    } finally {
      await tester.runAsync(() async {
        await rawDb.delete(
          'products',
          where: 'id IN (?, ?)',
          whereArgs: [uncostedProdId, zeroCostProdId],
        );
        await rawDb.delete(
          'stock_movements',
          where: 'id = ?',
          whereArgs: [brokenDocMovementId],
        );
        await rawDb.execute('PRAGMA foreign_keys = ON');
      });
    }
  });

  testWidgets('3. Manual-review indicator behavior', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final l10n = AppLocalizations('ar');

    late int manualReviewProdId;
    late int mechanicalItemId;

    await tester.runAsync(() async {
      await rawDb.execute('PRAGMA foreign_keys = OFF');
      // A. Finding that requires manual review: negative stock quantity
      manualReviewProdId = await rawDb.insert('products', {
        'name': 'منتج فحص يدوي',
        'type': 'product',
        'stock_quantity': -8.0, // requiresManualReview == true
        'purchase_price': 10.0,
        'sale_price': 20.0,
      });

      // B. Finding that does NOT require manual review: orphaned document item
      mechanicalItemId = await rawDb.insert('document_items', {
        'document_id':
            99991, // non-existent doc -> requiresManualReview == false
        'description': 'بند يتيم ميكانيكي',
        'quantity': 1.0,
        'price': 10.0,
        'total': 10.0,
        'taxable': 0,
      });
    });

    try {
      await tester.pumpWidget(
        _buildTestApp(
          langCode: 'ar',
          child: DatabaseDiagnosticScreen(db: rawDb),
        ),
      );
      await _pumpUntilDiagnosticsLoaded(tester);

      // 1. Manual review required badge is shown for the manual review finding
      expect(find.text(l10n.diagnosticsManualReviewRequired), findsOneWidget);

      // 2. Finding titles are both displayed
      expect(find.text('رصيد مخزون سالب للبضاعة'), findsOneWidget);
      expect(find.text('بنود فواتير يتيمة بدون مستند أصلي'), findsOneWidget);
    } finally {
      await tester.runAsync(() async {
        await rawDb.delete(
          'products',
          where: 'id = ?',
          whereArgs: [manualReviewProdId],
        );
        await rawDb.delete(
          'document_items',
          where: 'id = ?',
          whereArgs: [mechanicalItemId],
        );
        await rawDb.execute('PRAGMA foreign_keys = ON');
      });
    }
  });

  testWidgets(
    '4. Category filtering behavior with distinct stock and missing-opening labels',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final l10n = AppLocalizations('ar');

      // Verify that the localization keys are distinct
      expect(
        l10n.diagnosticsCategoryStock !=
            l10n.diagnosticsCategoryMissingOpeningStock,
        isTrue,
        reason:
            'Stock ledger and missing opening stock categories must have distinct labels',
      );

      late int orphanedItemId;
      late int stockDiscrepancyProdId;
      late int stockDiscrepancyMovementId;
      late int missingOpeningProdId;

      await tester.runAsync(() async {
        await rawDb.execute('PRAGMA foreign_keys = OFF');
        // Category 1: Orphaned Record
        orphanedItemId = await rawDb.insert('document_items', {
          'document_id': 99992,
          'description': 'بند يتيم للتصفية',
          'quantity': 1.0,
          'price': 10.0,
          'total': 10.0,
          'taxable': 0,
        });

        // Category 2: Stock Discrepancy (stock_quantity != movements_sum)
        stockDiscrepancyProdId = await rawDb.insert('products', {
          'name': 'منتج عدم تطابق الحركات',
          'type': 'product',
          'stock_quantity': 20.0,
          'purchase_price': 10.0,
          'sale_price': 20.0,
          'average_cost': 10.0,
          'cost_status': StockMovement.costStatusKnown,
        });
        stockDiscrepancyMovementId = await rawDb.insert('stock_movements', {
          'product_id': stockDiscrepancyProdId,
          'type': StockMovement.typeOpening,
          'quantity': 10.0, // Discrepancy: 10 vs 20
          'unit_cost': 10.0,
          'total_cost': 100.0,
          'cost_status': StockMovement.costStatusKnown,
          'date': DateTime.now().toIso8601String(),
        });

        // Category 3: Missing Opening Stock (stock_quantity > 0 but zero movements)
        missingOpeningProdId = await rawDb.insert('products', {
          'name': 'منتج رصيد بدون حركات',
          'type': 'product',
          'stock_quantity': 15.0,
          'purchase_price': 10.0,
          'sale_price': 20.0,
          'average_cost': 10.0,
          'cost_status': StockMovement.costStatusKnown,
        });
      });

      try {
        await tester.pumpWidget(
          _buildTestApp(
            langCode: 'ar',
            child: DatabaseDiagnosticScreen(db: rawDb),
          ),
        );
        await _pumpUntilDiagnosticsLoaded(tester);

        // Initially all 3 findings are visible
        expect(find.text('بنود فواتير يتيمة بدون مستند أصلي'), findsOneWidget);
        expect(
          find.text('اختلاف رصيد المخزون عن سجل حركة الأصناف'),
          findsOneWidget,
        );
        expect(
          find.text('صنف يحتوي على حركات مخزون بدون رصيد افتتاحي'),
          findsOneWidget,
        );

        // 1. Distinct FilterChips exist for each category
        final stockChipFinder = find.widgetWithText(
          FilterChip,
          '${l10n.diagnosticsCategoryStock} (1)',
        );
        final missingOpeningChipFinder = find.widgetWithText(
          FilterChip,
          '${l10n.diagnosticsCategoryMissingOpeningStock} (1)',
        );
        final orphanedChipFinder = find.widgetWithText(
          FilterChip,
          '${l10n.diagnosticsCategoryOrphaned} (1)',
        );
        final allChipFinder = find.widgetWithText(
          FilterChip,
          '${l10n.diagnosticsCategoryAll} (3)',
        );

        expect(stockChipFinder, findsOneWidget);
        expect(missingOpeningChipFinder, findsOneWidget);
        expect(orphanedChipFinder, findsOneWidget);
        expect(allChipFinder, findsOneWidget);

        // 2. Tap 'اختلاف رصيد المخزون عن سجل حركة الأصناف' FilterChip
        await tester.ensureVisible(stockChipFinder);
        await tester.tap(stockChipFinder);
        await tester.pumpAndSettle();

        expect(
          find.text('اختلاف رصيد المخزون عن سجل حركة الأصناف'),
          findsOneWidget,
        );
        expect(
          find.text('صنف يحتوي على حركات مخزون بدون رصيد افتتاحي'),
          findsNothing,
        );
        expect(find.text('بنود فواتير يتيمة بدون مستند أصلي'), findsNothing);

        // 3. Tap 'رصيد افتتاحي مفقود' FilterChip
        await tester.ensureVisible(missingOpeningChipFinder);
        await tester.tap(missingOpeningChipFinder);
        await tester.pumpAndSettle();

        expect(
          find.text('صنف يحتوي على حركات مخزون بدون رصيد افتتاحي'),
          findsOneWidget,
        );
        expect(
          find.text('اختلاف رصيد المخزون عن سجل حركة الأصناف'),
          findsNothing,
        );
        expect(find.text('بنود فواتير يتيمة بدون مستند أصلي'), findsNothing);

        // 4. Tap 'الكل' FilterChip: all 3 findings are restored
        await tester.ensureVisible(allChipFinder);
        await tester.tap(allChipFinder);
        await tester.pumpAndSettle();

        expect(find.text('بنود فواتير يتيمة بدون مستند أصلي'), findsOneWidget);
        expect(
          find.text('اختلاف رصيد المخزون عن سجل حركة الأصناف'),
          findsOneWidget,
        );
        expect(
          find.text('صنف يحتوي على حركات مخزون بدون رصيد افتتاحي'),
          findsOneWidget,
        );
      } finally {
        await tester.runAsync(() async {
          await rawDb.delete(
            'document_items',
            where: 'id = ?',
            whereArgs: [orphanedItemId],
          );
          await rawDb.delete(
            'stock_movements',
            where: 'id = ?',
            whereArgs: [stockDiscrepancyMovementId],
          );
          await rawDb.delete(
            'products',
            where: 'id IN (?, ?)',
            whereArgs: [stockDiscrepancyProdId, missingOpeningProdId],
          );
          await rawDb.execute('PRAGMA foreign_keys = ON');
        });
      }
    },
  );

  testWidgets('5. Affected-ID truncation and remaining count (max 20 visible)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final l10n = AppLocalizations('ar');
    final insertedIds = <int>[];

    await tester.runAsync(() async {
      await rawDb.execute('PRAGMA foreign_keys = OFF');
      // Insert 25 orphaned document items
      for (int i = 0; i < 25; i++) {
        final id = await rawDb.insert('document_items', {
          'document_id': 99993,
          'description': 'بند اختبار الترقيم $i',
          'quantity': 1.0,
          'price': 10.0,
          'total': 10.0,
          'taxable': 0,
        });
        insertedIds.add(id);
      }
    });

    try {
      await tester.pumpWidget(
        _buildTestApp(
          langCode: 'ar',
          child: DatabaseDiagnosticScreen(db: rawDb),
        ),
      );
      await _pumpUntilDiagnosticsLoaded(tester);

      // Expand the finding tile
      final findingTile = find.text('بنود فواتير يتيمة بدون مستند أصلي');
      expect(findingTile, findsOneWidget);
      await tester.tap(findingTile);
      await tester.pumpAndSettle();

      // Total count header should show (25):
      expect(find.text('${l10n.diagnosticsAffectedIds} (25):'), findsOneWidget);

      // First item chip '#${insertedIds.first}' must be visible
      expect(find.text('#${insertedIds.first}'), findsOneWidget);

      // The 20th item chip '#${insertedIds[19]}' must be visible
      expect(find.text('#${insertedIds[19]}'), findsOneWidget);

      // The 21st item chip '#${insertedIds[20]}' must NOT be rendered (truncated)
      expect(find.text('#${insertedIds[20]}'), findsNothing);

      // Truncation badge "+5 إضافية" must be rendered
      expect(find.text('+5 ${l10n.diagnosticsMoreIds}'), findsOneWidget);
    } finally {
      await tester.runAsync(() async {
        for (final id in insertedIds) {
          await rawDb.delete(
            'document_items',
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        await rawDb.execute('PRAGMA foreign_keys = ON');
      });
    }
  });

  testWidgets('6. Arabic and English RTL/LTR compatibility', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Test Arabic
    await tester.pumpWidget(
      _buildTestApp(
        langCode: 'ar',
        child: DatabaseDiagnosticScreen(db: rawDb),
      ),
    );
    await _pumpUntilDiagnosticsLoaded(tester);

    final l10nAr = AppLocalizations('ar');
    expect(find.text(l10nAr.databaseDiagnosticsTitle), findsOneWidget);
    expect(find.text(l10nAr.diagnosticsCleanTitle), findsOneWidget);

    // Test English
    await tester.pumpWidget(
      _buildTestApp(
        langCode: 'en',
        child: DatabaseDiagnosticScreen(db: rawDb),
      ),
    );
    await _pumpUntilDiagnosticsLoaded(tester);

    final l10nEn = AppLocalizations('en');
    expect(find.text(l10nEn.databaseDiagnosticsTitle), findsOneWidget);
    expect(find.text(l10nEn.diagnosticsCleanTitle), findsOneWidget);
  });

  testWidgets(
    '7. Strict read-only guarantee: snapshots before and after screen execution and refresh',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final tables = [
        'businesses',
        'contacts',
        'products',
        'documents',
        'document_items',
        'document_payments',
        'stock_movements',
        'stocktake_sessions',
        'stocktake_items',
        'audit_log',
      ];

      // Snapshot all table rows and counts before UI navigation
      final preCounts = <String, int>{};
      final preSnapshots = <String, List<Map<String, dynamic>>>{};
      await tester.runAsync(() async {
        for (final table in tables) {
          final rows = await rawDb.query(table);
          preCounts[table] = rows.length;
          preSnapshots[table] = rows;
        }
      });

      await tester.pumpWidget(
        _buildTestApp(
          langCode: 'ar',
          child: DatabaseDiagnosticScreen(db: rawDb),
        ),
      );
      await _pumpUntilDiagnosticsLoaded(tester);

      // Tap refresh in AppBar
      final refreshButton = find.byIcon(Icons.refresh);
      expect(refreshButton, findsWidgets);
      await tester.tap(refreshButton.first);
      await _pumpUntilDiagnosticsLoaded(tester);

      // Verify all tables are completely untouched
      await tester.runAsync(() async {
        for (final table in tables) {
          final postRows = await rawDb.query(table);
          expect(
            postRows.length,
            preCounts[table],
            reason:
                'Table $table row count changed after diagnostic UI viewing',
          );
          expect(
            postRows,
            preSnapshots[table],
            reason: 'Table $table data mutated after diagnostic UI viewing',
          );
        }
      });
    },
  );
}
