import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:warqatek/localization/app_localizations.dart';
import 'package:warqatek/screens/database_diagnostic_screen.dart';
import 'package:warqatek/screens/document_detail_screen.dart';
import 'package:warqatek/screens/product_form_screen.dart';

class MockDiagnosticExecutor implements DatabaseExecutor {
  final Map<String, List<Map<String, dynamic>>> queryResponses;
  final List<String> recordedQueries = [];

  MockDiagnosticExecutor(this.queryResponses);

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    recordedQueries.add(sql);
    if (sql.contains("PRAGMA table_info('products')")) {
      return [
        {'name': 'id'},
        {'name': 'cost_status'},
      ];
    }
    for (final entry in queryResponses.entries) {
      if (sql.contains(entry.key)) {
        return entry.value;
      }
    }
    return [];
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return rawQuery('FROM $table ${where ?? ''}');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrapScreen({required Widget child, String langCode = 'ar'}) {
  return LanguageProvider(
    langCode: langCode,
    onChangeLanguage: (_) async {},
    child: MaterialApp(
      locale: Locale(langCode),
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DatabaseDiagnosticScreen - Clickable Records & Safe Navigation', () {
    testWidgets('1. Displays clickable record chips and view affected records button', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockDb = MockDiagnosticExecutor({
        // Trigger remaining mismatch finding for documents 101 and 102
        'remaining != (total - paid)': [
          {
            'id': 101,
            'document_number': 'INV-2026-0001',
            'total': 500.0,
            'paid': 100.0,
            'remaining': 999.0, // Mismatch!
          },
          {
            'id': 102,
            'document_number': 'INV-2026-0002',
            'total': 800.0,
            'paid': 200.0,
            'remaining': 999.0, // Mismatch!
          },
        ],
        'SELECT id, document_number, total, paid, remaining': [
          {
            'id': 101,
            'document_number': 'INV-2026-0001',
            'total': 500.0,
            'paid': 100.0,
            'remaining': 999.0,
          },
          {
            'id': 102,
            'document_number': 'INV-2026-0002',
            'total': 800.0,
            'paid': 200.0,
            'remaining': 999.0,
          },
        ],
        'SELECT id, document_number, type, date, recipient_name, total FROM documents WHERE id IN': [
          {
            'id': 101,
            'document_number': 'INV-2026-0001',
            'type': 'invoice',
            'date': '2026-10-24T10:00:00.000',
            'recipient_name': 'شركة الأمل',
            'total': 500.0,
          },
          {
            'id': 102,
            'document_number': 'INV-2026-0002',
            'type': 'invoice',
            'date': '2026-10-24T11:00:00.000',
            'recipient_name': 'مؤسسة النور',
            'total': 800.0,
          },
        ],
      });

      await tester.pumpWidget(_wrapScreen(child: DatabaseDiagnosticScreen(db: mockDb)));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations('ar');

      // Expand finding tile
      final issueCard = find.byType(ExpansionTile);
      expect(issueCard, findsOneWidget);
      await tester.tap(issueCard);
      await tester.pumpAndSettle();

      // Verify affected IDs are visible as clickable chips
      expect(find.text('#101'), findsOneWidget);
      expect(find.text('#102'), findsOneWidget);

      // Verify "View Affected Records (2)" button is present
      final viewRecordsBtn = find.text('${l10n.diagnosticsViewAffectedRecords} (2)');
      expect(viewRecordsBtn, findsOneWidget);

      // Tap the button to open bottom sheet
      await tester.tap(viewRecordsBtn);
      await tester.pumpAndSettle();

      // Verify bottom sheet title and records
      expect(find.text('${l10n.diagnosticsAffectedRecordsTitle} (2)'), findsOneWidget);
      expect(find.text('فاتورة: INV-2026-0001'), findsOneWidget);
      expect(find.text('فاتورة: INV-2026-0002'), findsOneWidget);
    });

    testWidgets('2. Tapping document record navigates to DocumentDetailScreen without triggering repair', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockDb = MockDiagnosticExecutor({
        'SELECT id, document_number, total, paid, remaining': [
          {
            'id': 101,
            'document_number': 'INV-2026-0001',
            'total': 500.0,
            'paid': 100.0,
            'remaining': 999.0,
          },
        ],
        'SELECT id, document_number, type FROM documents WHERE id = ?': [
          {
            'id': 101,
            'document_number': 'INV-2026-0001',
            'type': 'invoice',
          },
        ],
      });

      await tester.pumpWidget(_wrapScreen(child: DatabaseDiagnosticScreen(db: mockDb)));
      await tester.pumpAndSettle();

      // Expand tile
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      // Tap #101 chip
      await tester.tap(find.text('#101'));
      await tester.pumpAndSettle();

      // Verify DocumentDetailScreen opened with documentId = 101
      final detailScreen = find.byType(DocumentDetailScreen);
      expect(detailScreen, findsOneWidget);
      final widget = tester.widget<DocumentDetailScreen>(detailScreen);
      expect(widget.documentId, equals(101));
    });

    testWidgets('3. Tapping missing or deleted record shows safe dialog without crashing', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockDb = MockDiagnosticExecutor({
        'SELECT id, document_number, total, paid, remaining': [
          {
            'id': 999,
            'document_number': 'INV-999',
            'total': 500.0,
            'paid': 100.0,
            'remaining': 999.0,
          },
        ],
        // Database returns empty list (record was deleted)
        'SELECT id, document_number, type FROM documents WHERE id = ?': [],
      });

      await tester.pumpWidget(_wrapScreen(child: DatabaseDiagnosticScreen(db: mockDb)));
      await tester.pumpAndSettle();

      // Expand tile
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      // Tap #999 chip
      await tester.tap(find.text('#999'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations('ar');

      // Verify friendly alert dialog appears instead of crashing
      expect(find.text(l10n.diagnosticsRecordUnavailable), findsOneWidget);
      expect(find.text(l10n.diagnosticsRecordUnavailableDesc), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text(l10n.close));
      await tester.pumpAndSettle();

      // Confirm user is safely back on the diagnostics screen
      expect(find.byType(DatabaseDiagnosticScreen), findsOneWidget);
    });

    testWidgets('4. Product entity navigates to ProductFormScreen', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockDb = MockDiagnosticExecutor({
        // Trigger product negative stock finding
        'stock_quantity < -': [
          {
            'id': 205,
            'name': 'طابعة ليزرية',
            'sku': 'PRN-01',
            'stock_quantity': -10.0,
          },
        ],
        'SELECT * FROM products WHERE id = ?': [
          {
            'id': 205,
            'name': 'طابعة ليزرية',
            'sku': 'PRN-01',
            'stock_quantity': -10.0,
            'unit': 'قطعة',
            'average_cost': 150.0,
            'type': 'product',
          },
        ],
      });

      await tester.pumpWidget(_wrapScreen(child: DatabaseDiagnosticScreen(db: mockDb)));
      await tester.pumpAndSettle();

      // Expand tile
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      // Tap #205 chip
      await tester.tap(find.text('#205'));
      await tester.pumpAndSettle();

      // Verify ProductFormScreen is opened
      final productForm = find.byType(ProductFormScreen);
      expect(productForm, findsOneWidget);
      final widget = tester.widget<ProductFormScreen>(productForm);
      expect(widget.product?.id, equals(205));
      expect(widget.product?.name, equals('طابعة ليزرية'));
    });

    testWidgets('5. Payment discrepancies retain manual-review badge and are excluded from auto-repair', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockDb = MockDiagnosticExecutor({
        // Payment records exceed paid
        'payments_sum > d.paid': [
          {
            'id': 301,
            'document_number': 'INV-301',
            'paid': 200.0,
            'payments_sum': 500.0,
          },
        ],
      });

      await tester.pumpWidget(_wrapScreen(child: DatabaseDiagnosticScreen(db: mockDb)));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations('ar');

      // Manual review badge must be displayed
      expect(find.text(l10n.diagnosticsManualReviewRequired), findsOneWidget);

      // Expand tile
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      // Review action button must be displayed, NOT the Fix button
      expect(find.text(l10n.repairActionReview), findsOneWidget);
      expect(find.text(l10n.repairActionFix), findsNothing);
    });
  });
}
