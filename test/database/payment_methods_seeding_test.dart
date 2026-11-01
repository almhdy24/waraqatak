import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:warqatek/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = Directory.systemTemp.createTempSync('pm_seed_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  tearDownAll(() async {
    try {
      await DatabaseHelper.instance.closeDatabase();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('New install seeds exactly 6 payment methods in exact order with Cash default', () async {
    final db = await DatabaseHelper.instance.database;

    final methods = await db.query('payment_methods', orderBy: 'sort_order, id');
    expect(methods.length, 6);

    // 1. نقداً (Cash) - selected by default
    expect(methods[0]['key'], 'cash');
    expect(methods[0]['label_ar'], 'نقداً');
    expect(methods[0]['label_en'], 'Cash');
    expect(methods[0]['sort_order'], 1);
    expect(methods[0]['is_default'], 1);
    expect(methods[0]['is_enabled'], 1);
    expect(methods[0]['is_predefined'], 1);

    // 2. بنكك (Bankak)
    expect(methods[1]['key'], 'bankak');
    expect(methods[1]['label_ar'], 'بنكك');
    expect(methods[1]['label_en'], 'Bankak');
    expect(methods[1]['sort_order'], 2);
    expect(methods[1]['is_default'], 0);
    expect(methods[1]['is_enabled'], 1);
    expect(methods[1]['is_predefined'], 1);

    // 3. فوري (Fawry)
    expect(methods[2]['key'], 'fawry');
    expect(methods[2]['label_ar'], 'فوري');
    expect(methods[2]['label_en'], 'Fawry');
    expect(methods[2]['sort_order'], 3);
    expect(methods[2]['is_default'], 0);
    expect(methods[2]['is_enabled'], 1);
    expect(methods[2]['is_predefined'], 1);

    // 4. أوكاش (O-Cash)
    expect(methods[3]['key'], 'okash');
    expect(methods[3]['label_ar'], 'أوكاش');
    expect(methods[3]['label_en'], 'O-Cash');
    expect(methods[3]['sort_order'], 4);
    expect(methods[3]['is_default'], 0);
    expect(methods[3]['is_enabled'], 1);
    expect(methods[3]['is_predefined'], 1);

    // 5. تحويل بنكي (Bank transfer)
    expect(methods[4]['key'], 'bank');
    expect(methods[4]['label_ar'], 'تحويل بنكي');
    expect(methods[4]['label_en'], 'Bank transfer');
    expect(methods[4]['sort_order'], 5);
    expect(methods[4]['is_default'], 0);
    expect(methods[4]['is_enabled'], 1);
    expect(methods[4]['is_predefined'], 1);

    // 6. شيك (Cheque)
    expect(methods[5]['key'], 'cheque');
    expect(methods[5]['label_ar'], 'شيك');
    expect(methods[5]['label_en'], 'Cheque');
    expect(methods[5]['sort_order'], 6);
    expect(methods[5]['is_default'], 0);
    expect(methods[5]['is_enabled'], 1);
    expect(methods[5]['is_predefined'], 1);

    await DatabaseHelper.instance.closeDatabase();
  });

  test('Migration from v23: removes unreferenced defaults, deactivates referenced ones, keeps manual methods', () async {
    final dbPath = '${tempDir.path}/pm_mig_v23_to_v24.db';
    // 1. Setup a v23 database with old seeded methods and a manual method
    var db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 23,
        onCreate: (d, v) async {
          await d.execute('''
            CREATE TABLE payment_methods (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              key TEXT UNIQUE NOT NULL,
              label_ar TEXT NOT NULL,
              label_en TEXT NOT NULL,
              is_enabled INTEGER NOT NULL DEFAULT 0,
              is_default INTEGER NOT NULL DEFAULT 0,
              sort_order INTEGER NOT NULL DEFAULT 0,
              is_predefined INTEGER NOT NULL DEFAULT 1
            )
          ''');
          await d.execute('''
            CREATE TABLE documents (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              payment_method TEXT
            )
          ''');
          await d.execute('''
            CREATE TABLE document_payments (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              payment_method TEXT
            )
          ''');

          // Old v23 seeded methods
          final oldSeeds = [
            {'key': 'cash', 'label_ar': 'نقداً', 'label_en': 'Cash', 'is_enabled': 1, 'is_default': 1, 'sort_order': 0, 'is_predefined': 1},
            {'key': 'bank', 'label_ar': 'تحويل بنكي', 'label_en': 'Bank Transfer', 'is_enabled': 1, 'is_default': 0, 'sort_order': 1, 'is_predefined': 1},
            {'key': 'card', 'label_ar': 'بطاقة ائتمان', 'label_en': 'Credit/Debit Card', 'is_enabled': 0, 'is_default': 0, 'sort_order': 2, 'is_predefined': 1},
            {'key': 'mobile', 'label_ar': 'محفظة جوّال', 'label_en': 'Mobile Wallet', 'is_enabled': 0, 'is_default': 0, 'sort_order': 3, 'is_predefined': 1},
            {'key': 'bankak', 'label_ar': 'بنكك', 'label_en': 'Bankak', 'is_enabled': 0, 'is_default': 0, 'sort_order': 4, 'is_predefined': 1},
            {'key': 'okash', 'label_ar': 'أوكاش', 'label_en': 'oCash', 'is_enabled': 0, 'is_default': 0, 'sort_order': 5, 'is_predefined': 1},
            {'key': 'mada', 'label_ar': 'مدى', 'label_en': 'Mada', 'is_enabled': 0, 'is_default': 0, 'sort_order': 6, 'is_predefined': 1},
            {'key': 'fawry', 'label_ar': 'فوري', 'label_en': 'Fawry', 'is_enabled': 0, 'is_default': 0, 'sort_order': 7, 'is_predefined': 1},
            {'key': 'paypal', 'label_ar': 'باي بال', 'label_en': 'PayPal', 'is_enabled': 0, 'is_default': 0, 'sort_order': 8, 'is_predefined': 1},
          ];
          for (final s in oldSeeds) {
            await d.insert('payment_methods', s);
          }

          // User added manual payment method
          await d.insert('payment_methods', {
            'key': 'custom_my_crypto',
            'label_ar': 'عملة رقمية',
            'label_en': 'Crypto',
            'is_enabled': 1,
            'is_default': 0,
            'sort_order': 99,
            'is_predefined': 0,
          });

          // Reference 'card' in documents
          await d.insert('documents', {'payment_method': 'card'});
          // Reference 'paypal' in document_payments
          await d.insert('document_payments', {'payment_method': 'paypal'});
        },
      ),
    );
    await db.close();

    // 2. Open at v24 to trigger migration
    db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 24,
        onUpgrade: (d, oldV, newV) async {
          if (oldV < 24 && newV >= 24) {
            await DatabaseHelper.replaceDefaultPaymentMethods(d);
          }
        },
      ),
    );

    // Verify unreferenced legacy methods (mobile, mada) are deleted
    final mobileRow = await db.query('payment_methods', where: 'key = ?', whereArgs: ['mobile']);
    expect(mobileRow.isEmpty, isTrue, reason: 'mobile was unreferenced and should be deleted');
    final madaRow = await db.query('payment_methods', where: 'key = ?', whereArgs: ['mada']);
    expect(madaRow.isEmpty, isTrue, reason: 'mada was unreferenced and should be deleted');

    // Verify referenced legacy methods (card in documents, paypal in document_payments) are deactivated, not deleted
    final cardRow = await db.query('payment_methods', where: 'key = ?', whereArgs: ['card']);
    expect(cardRow.isNotEmpty, isTrue, reason: 'card was referenced and must not be deleted');
    expect(cardRow.first['is_enabled'], 0, reason: 'card must be deactivated');
    expect(cardRow.first['is_default'], 0);

    final paypalRow = await db.query('payment_methods', where: 'key = ?', whereArgs: ['paypal']);
    expect(paypalRow.isNotEmpty, isTrue, reason: 'paypal was referenced and must not be deleted');
    expect(paypalRow.first['is_enabled'], 0, reason: 'paypal must be deactivated');
    expect(paypalRow.first['is_default'], 0);

    // Verify manual custom method is untouched
    final customRow = await db.query('payment_methods', where: 'key = ?', whereArgs: ['custom_my_crypto']);
    expect(customRow.isNotEmpty, isTrue);
    expect(customRow.first['label_ar'], 'عملة رقمية');
    expect(customRow.first['label_en'], 'Crypto');
    expect(customRow.first['is_enabled'], 1);
    expect(customRow.first['is_default'], 0);
    expect(customRow.first['sort_order'], 99);
    expect(customRow.first['is_predefined'], 0);

    // Verify the 6 defaults in exact order (1 to 6)
    final defaults = await db.query(
      'payment_methods',
      where: 'is_predefined = 1 AND is_enabled = 1',
      orderBy: 'sort_order, id',
    );
    expect(defaults.length, 6);

    expect(defaults[0]['key'], 'cash');
    expect(defaults[0]['label_ar'], 'نقداً');
    expect(defaults[0]['label_en'], 'Cash');
    expect(defaults[0]['sort_order'], 1);
    expect(defaults[0]['is_default'], 1);
    expect(defaults[0]['is_enabled'], 1);

    expect(defaults[1]['key'], 'bankak');
    expect(defaults[1]['label_ar'], 'بنكك');
    expect(defaults[1]['label_en'], 'Bankak');
    expect(defaults[1]['sort_order'], 2);
    expect(defaults[1]['is_default'], 0);
    expect(defaults[1]['is_enabled'], 1);

    expect(defaults[2]['key'], 'fawry');
    expect(defaults[2]['label_ar'], 'فوري');
    expect(defaults[2]['label_en'], 'Fawry');
    expect(defaults[2]['sort_order'], 3);
    expect(defaults[2]['is_default'], 0);
    expect(defaults[2]['is_enabled'], 1);

    expect(defaults[3]['key'], 'okash');
    expect(defaults[3]['label_ar'], 'أوكاش');
    expect(defaults[3]['label_en'], 'O-Cash');
    expect(defaults[3]['sort_order'], 4);
    expect(defaults[3]['is_default'], 0);
    expect(defaults[3]['is_enabled'], 1);

    expect(defaults[4]['key'], 'bank');
    expect(defaults[4]['label_ar'], 'تحويل بنكي');
    expect(defaults[4]['label_en'], 'Bank transfer');
    expect(defaults[4]['sort_order'], 5);
    expect(defaults[4]['is_default'], 0);
    expect(defaults[4]['is_enabled'], 1);

    expect(defaults[5]['key'], 'cheque');
    expect(defaults[5]['label_ar'], 'شيك');
    expect(defaults[5]['label_en'], 'Cheque');
    expect(defaults[5]['sort_order'], 6);
    expect(defaults[5]['is_default'], 0);
    expect(defaults[5]['is_enabled'], 1);

    // 3. Repeated run test: call replaceDefaultPaymentMethods again on same db
    await DatabaseHelper.replaceDefaultPaymentMethods(db);
    final countAfterRepeated = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM payment_methods'),
    );
    // 6 defaults + 2 deactivated (card, paypal) + 1 custom = 9
    expect(countAfterRepeated, 9);

    final cashRows = await db.query('payment_methods', where: 'key = ?', whereArgs: ['cash']);
    expect(cashRows.length, 1, reason: 'no duplicates created on repeated runs');

    final chequeRows = await db.query('payment_methods', where: 'key = ?', whereArgs: ['cheque']);
    expect(chequeRows.length, 1, reason: 'no duplicates created on repeated runs');

    await db.close();
  });
}
