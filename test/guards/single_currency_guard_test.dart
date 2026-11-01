import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';
import 'package:warqatek/models/business.dart';
import 'package:warqatek/models/document.dart';
import 'package:warqatek/models/document_item.dart';
import 'package:warqatek/models/document_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Single Currency Static & Architecture Guards', () {
    test('Guard 1: No currency selector/picker exists outside business_setup_screen.dart', () {
      final screensDir = Directory('lib/screens');
      final widgetsDir = Directory('lib/widgets');
      final violatingFiles = <String>[];

      final allowlist = <String, String>{
        'lib/screens/business_setup_screen.dart':
            'Initial business setup currency selection (locked on first transaction)',
      };

      final filesToCheck = [
        ...screensDir.listSync(recursive: true).whereType<File>(),
        ...widgetsDir.listSync(recursive: true).whereType<File>(),
      ].where((f) => f.path.endsWith('.dart'));

      for (final file in filesToCheck) {
        final normalized = file.path.replaceAll('\\', '/');
        if (allowlist.containsKey(normalized)) continue;

        final content = file.readAsStringSync();
        // Check for currency pickers or dropdowns
        if (content.contains('DropdownButton<Currency>') ||
            content.contains('DropdownButtonFormField<Currency>') ||
            content.contains('Currency.supportedCurrencies')) {
          violatingFiles.add('$normalized: contains currency picker/selector');
        }
      }

      expect(
        violatingFiles,
        isEmpty,
        reason: 'Currency selectors are strictly forbidden outside business setup:\n${violatingFiles.join('\n')}',
      );
    });

    test('Guard 2: No UI screens issue raw SQL insert/update directly to documents table', () {
      final screensDir = Directory('lib/screens');
      final violatingScreens = <String>[];

      for (final file in screensDir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final normalized = file.path.replaceAll('\\', '/');
        final content = file.readAsStringSync();

        if (content.contains("insert('documents'") ||
            content.contains('insert("documents"') ||
            content.contains("update('documents'") ||
            content.contains('update("documents"')) {
          violatingScreens.add('$normalized: direct raw SQL manipulation of documents table');
        }
      }

      expect(
        violatingScreens,
        isEmpty,
        reason: 'Screens must route all document mutations through DatabaseHelper / DocumentService:\n${violatingScreens.join('\n')}',
      );
    });

    test('Guard 3: CurrencyContext provides authoritative single-currency validation', () {
      final currencyServiceFile = File('lib/services/currency_service.dart');
      expect(currencyServiceFile.existsSync(), isTrue);

      final content = currencyServiceFile.readAsStringSync();
      expect(content.contains('class CurrencyContext'), isTrue);
      expect(content.contains('getBaseCurrencyCode'), isTrue);
      expect(content.contains('isBaseCurrency'), isTrue);
    });
  });

  group('Single Currency Test Preservation Guard', () {
    test('Guard 4: All tests mapped in docs/single_currency_design.md exist in test files', () {
      final docFile = File('docs/single_currency_design.md');
      expect(docFile.existsSync(), isTrue);

      final phase1File = File('test/services/multi_currency_phase1_test.dart');
      final phase2File = File('test/services/multi_currency_phase2_stage1_test.dart');
      final singleBaseFile = File('test/services/single_base_currency_test.dart');

      expect(phase1File.existsSync(), isTrue);
      expect(phase2File.existsSync(), isTrue);
      expect(singleBaseFile.existsSync(), isTrue);

      final phase1Content = phase1File.readAsStringSync();
      final phase2Content = phase2File.readAsStringSync();
      final singleBaseContent = singleBaseFile.readAsStringSync();

      // Verify Phase 1 mapped tests
      expect(phase1Content.contains('1. Customer: real getContactBalances result schema matches'), isTrue);
      expect(phase1Content.contains('2. Supplier: real getContactBalances result schema matches'), isTrue);
      expect(phase1Content.contains('3. getPurchasesReport correctly segregates totalsByCurrency'), isTrue);
      expect(phase1Content.contains('4. aggregateByCurrency groups COGS and trusted profit per currency'), isTrue);
      expect(phase1Content.contains('5. CustomerDetailScreen renders each document tile with its own currency symbol'), isTrue);

      // Verify Phase 2 Stage 1 mapped tests
      expect(phase2Content.contains('1. getPeriodSummary segregates currencies'), isTrue);
      expect(phase2Content.contains('2. getContactBalances isolates debts per currency'), isTrue);
      expect(phase2Content.contains('3. getProductPerformance maintains currency consistency'), isTrue);

      // Verify Single Base Currency tests 1 through 14
      for (int i = 1; i <= 14; i++) {
        expect(
          singleBaseContent.contains("test('$i. ") || singleBaseContent.contains('test("$i. '),
          isTrue,
          reason: 'Test $i in test/services/single_base_currency_test.dart must exist',
        );
      }
    });
  });

  group('Single Currency Runtime & Database Guards', () {
    late Directory tempDir;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      tempDir = Directory.systemTemp.createTempSync('single_currency_guard_test');
      await databaseFactory.setDatabasesPath(tempDir.path);
    });

    tearDownAll(() async {
      try {
        await DatabaseHelper.instance.closeDatabase();
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    Future<void> resetDb() async {
      final rawDb = await DatabaseHelper.instance.database;
      await rawDb.delete('document_payments');
      await rawDb.delete('document_items');
      await rawDb.delete('stock_movements');
      await rawDb.delete('documents');
      await rawDb.delete('contacts');
      await rawDb.delete('products');
      await rawDb.delete('businesses');

      await DatabaseHelper.instance.insertBusiness(
        Business(
          name: 'متجر دروع الحماية',
          ownerName: 'المالك',
          phone: '0123456789',
          address: 'الخرطوم',
          currencyCode: 'SDG',
        ),
      );
    }

    test('Guard 5: DatabaseHelper rejects inserting document with mismatched foreign currency', () async {
      await resetDb();

      final foreignDoc = Document(
        type: 'invoice',
        documentNumber: 'INV-FOREIGN-01',
        date: DateTime.now(),
        subtotal: 100.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        discount: 0.0,
        total: 100.0,
        paid: 0.0,
        remaining: 100.0,
        status: DocumentStatus.issued,
        currencyCode: 'USD', // Mismatched currency
      );

      expect(
        () async => await DatabaseHelper.instance.insertDocumentWithItems(
          foreignDoc,
          [const DocumentItem(documentId: 0, description: 'Test Item', quantity: 1, price: 100, total: 100)],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Guard 6: DatabaseHelper rejects issuing a draft document with foreign currency', () async {
      await resetDb();
      final rawDb = await DatabaseHelper.instance.database;

      // Seed a draft with legacy foreign currency
      final draftId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-DRAFT-01',
        'date': DateTime.now().toIso8601String(),
        'subtotal': 50.0,
        'discount': 0.0,
        'tax_rate': 0.0,
        'tax_amount': 0.0,
        'total': 50.0,
        'paid': 0.0,
        'remaining': 50.0,
        'status': DocumentStatus.draft,
        'currency_code': 'SAR',
      });

      expect(
        () async => await DatabaseHelper.instance.issueDocument(draftId),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Guard 7: DatabaseHelper rejects duplicating document with legacy foreign currency', () async {
      await resetDb();
      final rawDb = await DatabaseHelper.instance.database;

      final sourceId = await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-LEGACY-02',
        'date': DateTime.now().toIso8601String(),
        'subtotal': 200.0,
        'discount': 0.0,
        'tax_rate': 0.0,
        'tax_amount': 0.0,
        'total': 200.0,
        'paid': 200.0,
        'remaining': 0.0,
        'status': DocumentStatus.issued,
        'currency_code': 'EUR',
      });

      expect(
        () async => await DatabaseHelper.instance.copyDocumentWithItems(sourceId),
        throwsA(isA<StateError>()),
      );
    });

    test('Guard 8: getPeriodSummary segregates legacy foreign currency records from base totals', () async {
      await resetDb();
      final rawDb = await DatabaseHelper.instance.database;
      final now = DateTime.now();

      // Insert base SDG invoice (1,000 SDG)
      final sdgDoc = Document(
        type: 'invoice',
        documentNumber: 'INV-SDG-01',
        date: now,
        subtotal: 1000.0,
        taxRate: 0.0,
        taxAmount: 0.0,
        discount: 0.0,
        total: 1000.0,
        paid: 1000.0,
        remaining: 0.0,
        status: DocumentStatus.issued,
        currencyCode: 'SDG',
      );
      await DatabaseHelper.instance.insertDocumentWithItems(
        sdgDoc,
        [const DocumentItem(documentId: 0, description: 'SDG Product', quantity: 1, price: 1000, total: 1000)],
      );

      // Insert legacy foreign USD invoice (500 USD) directly to simulate historical record
      await rawDb.insert('documents', {
        'type': 'invoice',
        'document_number': 'INV-LEGACY-USD',
        'date': now.toIso8601String(),
        'subtotal': 500.0,
        'discount': 0.0,
        'tax_rate': 0.0,
        'tax_amount': 0.0,
        'total': 500.0,
        'paid': 500.0,
        'remaining': 0.0,
        'status': DocumentStatus.issued,
        'currency_code': 'USD',
      });

      final summary = await DatabaseHelper.instance.getPeriodSummary(
        from: now.subtract(const Duration(days: 1)),
        to: now.add(const Duration(days: 1)),
      );

      // Base scalar total MUST strictly reflect base currency SDG (1,000) and NEVER sum nominally with USD (1,500)
      expect(summary['sales'], equals(1000.0));
      expect(summary['paymentsIn'], equals(1000.0));

      // totalsByCurrency MUST segregate both currencies cleanly
      final totalsByCurrency = summary['totalsByCurrency'] as Map<String, dynamic>;
      expect(totalsByCurrency['SDG']?.sales, equals(1000.0));
      expect(totalsByCurrency['USD']?.sales, equals(500.0));
    });
  });
}
