import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/payment_method.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../models/document.dart';
import '../models/document_item.dart';
import '../models/document_payment.dart';
import '../models/document_status.dart';
import '../models/tax_profile.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  DatabaseHelper._privateConstructor();

  static const int dbVersion = 11;

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'warqatek_free.db');
    return openDatabase(
      path,
      version: dbVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createTables,
      onUpgrade: _upgradeTables,
    );
  }

  static const List<Map<String, dynamic>> _paymentMethodSeeds = [
    {'key': 'cash',   'label_ar': 'نقداً',        'label_en': 'Cash',             'is_enabled': 1, 'is_default': 1, 'sort_order': 0, 'is_predefined': 1},
    {'key': 'bank',   'label_ar': 'تحويل بنكي',   'label_en': 'Bank Transfer',    'is_enabled': 1, 'is_default': 0, 'sort_order': 1, 'is_predefined': 1},
    {'key': 'card',   'label_ar': 'بطاقة ائتمان', 'label_en': 'Credit/Debit Card','is_enabled': 0, 'is_default': 0, 'sort_order': 2, 'is_predefined': 1},
    {'key': 'mobile', 'label_ar': 'محفظة جوّال',  'label_en': 'Mobile Wallet',    'is_enabled': 0, 'is_default': 0, 'sort_order': 3, 'is_predefined': 1},
    {'key': 'bankak', 'label_ar': 'بنكك',         'label_en': 'Bankak',           'is_enabled': 0, 'is_default': 0, 'sort_order': 4, 'is_predefined': 1},
    {'key': 'okash',  'label_ar': 'أوكاش',        'label_en': 'oCash',            'is_enabled': 0, 'is_default': 0, 'sort_order': 5, 'is_predefined': 1},
    {'key': 'mada',   'label_ar': 'مدى',          'label_en': 'Mada',             'is_enabled': 0, 'is_default': 0, 'sort_order': 6, 'is_predefined': 1},
    {'key': 'fawry',  'label_ar': 'فوري',         'label_en': 'Fawry',            'is_enabled': 0, 'is_default': 0, 'sort_order': 7, 'is_predefined': 1},
    {'key': 'paypal', 'label_ar': 'باي بال',      'label_en': 'PayPal',           'is_enabled': 0, 'is_default': 0, 'sort_order': 8, 'is_predefined': 1},
  ];

  static Future<void> _seedPaymentMethods(DatabaseExecutor db) async {
    for (final seed in _paymentMethodSeeds) {
      await db.insert('payment_methods', seed,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
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
    await _seedPaymentMethods(db);

    await db.execute('''
      CREATE TABLE tax_profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT DEFAULT 'vat',
        rate REAL DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        is_default INTEGER DEFAULT 0,
        calculation_mode TEXT DEFAULT 'exclusive',
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE businesses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        owner_name TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT NOT NULL,
        email TEXT,
        logo_path TEXT,
        currency_code TEXT DEFAULT 'SDG',
        tax_rate REAL DEFAULT 0,
        legal_name TEXT,
        tax_id TEXT,
        tax_reg TEXT,
        commercial_reg TEXT,
        branch TEXT,
        taxes_enabled INTEGER DEFAULT 0,
        prices_include_tax INTEGER DEFAULT 0,
        default_tax_profile_id INTEGER,
        invoice_title TEXT,
        legal_footer TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        notes TEXT,
        type TEXT DEFAULT 'customer',
        active INTEGER DEFAULT 1,
        legal_name TEXT,
        tax_id TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT DEFAULT 'product',
        code TEXT,
        barcode TEXT,
        unit TEXT,
        sale_price REAL DEFAULT 0,
        purchase_price REAL DEFAULT 0,
        stock_quantity REAL DEFAULT 0,
        min_stock REAL DEFAULT 0,
        is_taxable INTEGER DEFAULT 1,
        is_active INTEGER DEFAULT 1,
        notes TEXT,
        tax_profile_id INTEGER,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_products_name ON products(name)');
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');

    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        reference_document_id INTEGER,
        date TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (reference_document_id) REFERENCES documents(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_stock_movements_product ON stock_movements(product_id)');

    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        document_number TEXT NOT NULL,
        date TEXT NOT NULL,
        contact_id INTEGER,
        recipient_name TEXT,
        recipient_phone TEXT,
        subtotal REAL DEFAULT 0,
        discount REAL DEFAULT 0,
        tax_rate REAL DEFAULT 0,
        tax_amount REAL DEFAULT 0,
        total REAL DEFAULT 0,
        paid REAL DEFAULT 0,
        remaining REAL DEFAULT 0,
        payment_method TEXT,
        valid_until TEXT,
        notes TEXT,
        related_document_id INTEGER,
        status TEXT DEFAULT 'issued',
        currency_code TEXT DEFAULT 'SDG',
        FOREIGN KEY (contact_id) REFERENCES contacts (id),
        FOREIGN KEY (related_document_id) REFERENCES documents (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE document_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        product_id INTEGER,
        description TEXT NOT NULL,
        quantity REAL NOT NULL,
        price REAL NOT NULL,
        total REAL NOT NULL,
        taxable INTEGER DEFAULT 1,
        tax_rate REAL,
        FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE document_counters (
        type TEXT PRIMARY KEY,
        next_number INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE document_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        payment_method TEXT,
        date TEXT NOT NULL,
        notes TEXT,
        receipt_document_id INTEGER,
        FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE,
        FOREIGN KEY (receipt_document_id) REFERENCES documents (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        entity_type TEXT,
        entity_id INTEGER,
        details TEXT,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    Future<bool> columnExists(String table, String column) async {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      return columns.any((c) => c['name'] == column);
    }

    if (oldVersion < 2) {
      if (!await columnExists('documents', 'payment_method')) {
        await db.execute('ALTER TABLE documents ADD COLUMN payment_method TEXT');
      }
      if (!await columnExists('documents', 'valid_until')) {
        await db.execute('ALTER TABLE documents ADD COLUMN valid_until TEXT');
      }
    }

    if (oldVersion < 3) {
      if (!await columnExists('businesses', 'logo_path')) {
        await db.execute('ALTER TABLE businesses ADD COLUMN logo_path TEXT');
      }
    }

    if (oldVersion < 4) {
      if (!await columnExists('businesses', 'currency_code')) {
        await db.execute("ALTER TABLE businesses ADD COLUMN currency_code TEXT DEFAULT 'SDG'");
      }
      if (!await columnExists('documents', 'currency_code')) {
        await db.execute("ALTER TABLE documents ADD COLUMN currency_code TEXT DEFAULT 'SDG'");
      }
    }

    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS document_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          document_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          payment_method TEXT,
          date TEXT NOT NULL,
          notes TEXT,
          FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
        )
      ''');

      await db.execute("""
        UPDATE documents SET status =
          CASE
            WHEN type = 'invoice' AND paid >= total THEN 'paid'
            WHEN type = 'invoice' AND paid > 0      THEN 'partially_paid'
            ELSE 'issued'
          END
        WHERE status = 'active'
      """);
    }

    if (oldVersion < 6) {
      if (!await columnExists('document_payments', 'receipt_document_id')) {
        await db.execute(
          'ALTER TABLE document_payments ADD COLUMN receipt_document_id INTEGER',
        );
      }
    }

    if (oldVersion < 7) {
      if (!await columnExists('products', 'type')) {
        await db.execute("ALTER TABLE products ADD COLUMN type TEXT DEFAULT 'product'");
      }
      if (!await columnExists('products', 'barcode')) {
        await db.execute('ALTER TABLE products ADD COLUMN barcode TEXT');
      }
      if (!await columnExists('products', 'unit')) {
        await db.execute('ALTER TABLE products ADD COLUMN unit TEXT');
      }
      if (!await columnExists('products', 'is_active')) {
        await db.execute('ALTER TABLE products ADD COLUMN is_active INTEGER DEFAULT 1');
      }
      if (!await columnExists('products', 'created_at')) {
        await db.execute('ALTER TABLE products ADD COLUMN created_at TEXT');
      }
      if (!await columnExists('products', 'updated_at')) {
        await db.execute('ALTER TABLE products ADD COLUMN updated_at TEXT');
      }
      await db.execute('CREATE INDEX IF NOT EXISTS idx_products_name ON products(name)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)');
    }

    if (oldVersion < 8) {
      if (!await columnExists('contacts', 'email')) {
        await db.execute('ALTER TABLE contacts ADD COLUMN email TEXT');
      }
      if (!await columnExists('contacts', 'notes')) {
        await db.execute('ALTER TABLE contacts ADD COLUMN notes TEXT');
      }
      if (!await columnExists('contacts', 'active')) {
        await db.execute('ALTER TABLE contacts ADD COLUMN active INTEGER DEFAULT 1');
      }
      if (!await columnExists('contacts', 'created_at')) {
        await db.execute('ALTER TABLE contacts ADD COLUMN created_at TEXT');
      }
      if (!await columnExists('contacts', 'updated_at')) {
        await db.execute('ALTER TABLE contacts ADD COLUMN updated_at TEXT');
      }

      await db.execute('''
        CREATE TABLE IF NOT EXISTS stock_movements (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          type TEXT NOT NULL,
          quantity REAL NOT NULL,
          reference_document_id INTEGER,
          date TEXT NOT NULL,
          notes TEXT,
          FOREIGN KEY (product_id) REFERENCES products(id),
          FOREIGN KEY (reference_document_id) REFERENCES documents(id) ON DELETE SET NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_movements_product ON stock_movements(product_id)');
    }

    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS audit_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          action TEXT NOT NULL,
          entity_type TEXT,
          entity_id INTEGER,
          details TEXT,
          timestamp TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tax_profiles (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          type TEXT DEFAULT 'vat',
          rate REAL DEFAULT 0,
          is_active INTEGER DEFAULT 1,
          is_default INTEGER DEFAULT 0,
          calculation_mode TEXT DEFAULT 'exclusive',
          notes TEXT
        )
      ''');
      // businesses: legal identity + tax config + document settings
      for (final col in [
        "ALTER TABLE businesses ADD COLUMN legal_name TEXT",
        "ALTER TABLE businesses ADD COLUMN tax_id TEXT",
        "ALTER TABLE businesses ADD COLUMN tax_reg TEXT",
        "ALTER TABLE businesses ADD COLUMN commercial_reg TEXT",
        "ALTER TABLE businesses ADD COLUMN branch TEXT",
        "ALTER TABLE businesses ADD COLUMN taxes_enabled INTEGER DEFAULT 0",
        "ALTER TABLE businesses ADD COLUMN prices_include_tax INTEGER DEFAULT 0",
        "ALTER TABLE businesses ADD COLUMN default_tax_profile_id INTEGER",
        "ALTER TABLE businesses ADD COLUMN invoice_title TEXT",
        "ALTER TABLE businesses ADD COLUMN legal_footer TEXT",
      ]) {
        try { await db.execute(col); } on DatabaseException catch (_) {
          // Column already exists on this install — ignore and continue.
        }
      }
      // contacts: legal identity
      for (final col in [
        "ALTER TABLE contacts ADD COLUMN legal_name TEXT",
        "ALTER TABLE contacts ADD COLUMN tax_id TEXT",
      ]) {
        try { await db.execute(col); } on DatabaseException catch (_) {
          // Column already exists on this install — ignore and continue.
        }
      }
      // products: tax profile link
      if (!await columnExists('products', 'tax_profile_id')) {
        await db.execute('ALTER TABLE products ADD COLUMN tax_profile_id INTEGER');
      }
      // document_items: tax rate snapshot
      if (!await columnExists('document_items', 'tax_rate')) {
        await db.execute('ALTER TABLE document_items ADD COLUMN tax_rate REAL');
      }
    }

    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS payment_methods (
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
      await _seedPaymentMethods(db);

      // Migrate enabled predefined methods from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final enabledKeys = prefs.getStringList('payment_methods');
      if (enabledKeys != null && enabledKeys.isNotEmpty) {
        await db.update('payment_methods', {'is_enabled': 0, 'is_default': 0},
            where: 'is_predefined = 1');
        bool firstSet = false;
        for (final key in enabledKeys) {
          if (key.startsWith('custom_')) continue;
          await db.update('payment_methods',
              {'is_enabled': 1, 'is_default': firstSet ? 0 : 1},
              where: 'key = ?', whereArgs: [key]);
          firstSet = true;
        }
      }

      // Migrate custom methods from SharedPreferences
      final customRaw = prefs.getString('custom_payment_methods_v1');
      if (customRaw != null && customRaw.isNotEmpty) {
        try {
          final customMap = jsonDecode(customRaw) as Map<String, dynamic>;
          int sortOrder = 100;
          for (final entry in customMap.entries) {
            await db.insert('payment_methods', {
              'key': entry.key,
              'label_ar': entry.value.toString(),
              'label_en': entry.value.toString(),
              'is_enabled': 1,
              'is_default': 0,
              'sort_order': sortOrder++,
              'is_predefined': 0,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        } on FormatException catch (_) {
          // Legacy prefs blob is corrupt — skip custom-method migration.
        } on TypeError catch (_) {
          // Legacy prefs blob has unexpected shape — skip.
        }
      }

      // Ensure at least one default exists (fall back to cash)
      final defaults = await db.query('payment_methods',
          where: 'is_default = 1', limit: 1);
      if (defaults.isEmpty) {
        await db.update('payment_methods',
            {'is_default': 1, 'is_enabled': 1},
            where: 'key = ?', whereArgs: ['cash']);
      }

      await prefs.remove('payment_methods');
      await prefs.remove('custom_payment_methods_v1');
    }
  }

  // ========== Business ==========
  Future<int> insertBusiness(Business b) async {
    final db = await database;
    return db.insert('businesses', b.toMap());
  }

  Future<Business?> getFirstBusiness() async {
    final db = await database;
    final maps = await db.query('businesses', limit: 1);
    if (maps.isEmpty) return null;
    return Business.fromMap(maps.first);
  }

  Future<int> updateBusiness(Business b) async {
    final db = await database;
    return db.update('businesses', b.toMap(), where: 'id = ?', whereArgs: [b.id]);
  }

  // ========== Contacts ==========
  Future<int> insertContact(Contact c) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final map = c.toMap();
    map['created_at'] ??= now;
    map['updated_at'] ??= now;
    return db.insert('contacts', map);
  }

  Future<int> updateContact(Contact c) async {
    final db = await database;
    final map = c.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();
    return db.update('contacts', map, where: 'id = ?', whereArgs: [c.id]);
  }

  Future<int> deleteContact(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      await txn.update('documents', {'contact_id': null}, where: 'contact_id = ?', whereArgs: [id]);
      return txn.delete('contacts', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> setContactActive(int id, {required bool active}) async {
    final db = await database;
    await db.update('contacts', {'active': active ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Contact>> getAllContacts({String? type, bool activeOnly = false}) async {
    final db = await database;
    final conditions = <String>[];
    final args = <Object?>[];
    if (type != null) {
      conditions.add('type = ?');
      args.add(type);
    }
    if (activeOnly) {
      conditions.add('active = 1');
    }
    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    final maps = await db.query('contacts', where: where, whereArgs: args.isEmpty ? null : args, orderBy: 'name');
    return maps.map((e) => Contact.fromMap(e)).toList();
  }

  Future<List<Contact>> searchContacts(String query, {String? type, bool activeOnly = false}) async {
    final db = await database;
    String where = '(name LIKE ? OR phone LIKE ?)';
    final args = ['%$query%', '%$query%'];
    if (type != null && type.isNotEmpty) {
      where += ' AND type = ?';
      args.add(type);
    }
    if (activeOnly) {
      where += ' AND active = 1';
    }
    final maps = await db.query('contacts', where: where, whereArgs: args, orderBy: 'name', limit: 10);
    return maps.map((e) => Contact.fromMap(e)).toList();
  }

  Future<Contact?> getContactById(int id) async {
    final db = await database;
    final maps = await db.query('contacts', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Contact.fromMap(maps.first);
  }

  Future<double> getContactOutstanding(int contactId, String docType) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(remaining), 0) AS outstanding
      FROM documents
      WHERE contact_id = ? AND type = ?
        AND status NOT IN ('${DocumentStatus.draft}', '${DocumentStatus.cancelled}')
    ''', [contactId, docType]);
    return (rows.first['outstanding'] as num?)?.toDouble() ?? 0;
  }

  // ========== Products ==========
  Future<int> insertProduct(Product p) async {
    final db = await database;
    return db.transaction((txn) async {
      final id = await txn.insert('products', p.toMap());
      if (p.isProduct && p.stockQuantity > 0) {
        await txn.insert('stock_movements', {
          'product_id': id,
          'type': StockMovement.typeOpening,
          'quantity': p.stockQuantity,
          'reference_document_id': null,
          'date': (p.createdAt ?? DateTime.now()).toIso8601String(),
          'notes': null,
        });
      }
      return id;
    });
  }

  Future<int> updateProduct(Product p) async {
    final db = await database;
    return db.update('products', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> isProductReferenced(int id) async {
    final db = await database;
    final rows = await db.query(
      'document_items',
      columns: ['id'],
      where: 'product_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<Product>> getAllProducts({String? type, bool? activeOnly}) async {
    final db = await database;
    final conditions = <String>[];
    final args = <Object?>[];
    if (type != null) {
      conditions.add('type = ?');
      args.add(type);
    }
    if (activeOnly == true) {
      conditions.add('is_active = 1');
    }
    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    final maps = await db.query('products', where: where, whereArgs: args.isEmpty ? null : args, orderBy: 'name');
    return maps.map((e) => Product.fromMap(e)).toList();
  }

  Future<List<Product>> searchProducts(String query) async {
    final db = await database;
    final maps = await db.query('products',
        where: 'name LIKE ? OR code LIKE ? OR barcode LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%'],
        orderBy: 'name',
        limit: 10);
    return maps.map((e) => Product.fromMap(e)).toList();
  }

  Future<List<Product>> searchActiveProducts(String query) async {
    final db = await database;
    final maps = await db.query('products',
        where: '(name LIKE ? OR code LIKE ? OR barcode LIKE ?) AND is_active = 1',
        whereArgs: ['%$query%', '%$query%', '%$query%'],
        orderBy: 'name',
        limit: 10);
    return maps.map((e) => Product.fromMap(e)).toList();
  }

  Future<Product?> getProductById(int id) async {
    final db = await database;
    final maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final maps = await db.query('products',
        where: 'barcode = ? AND is_active = 1', whereArgs: [barcode], limit: 1);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<bool> isBarcodeUsed(String barcode, {int? excludeId}) async {
    final db = await database;
    String where = 'barcode = ?';
    final args = <Object?>[barcode];
    if (excludeId != null) {
      where += ' AND id != ?';
      args.add(excludeId);
    }
    final rows = await db.query('products', columns: ['id'], where: where, whereArgs: args, limit: 1);
    return rows.isNotEmpty;
  }

  Future<void> setProductActive(int id, {required bool active}) async {
    final db = await database;
    await db.update('products', {'is_active': active ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  // ========== Stock Movements ==========
  Future<void> _insertStockMovement(
    DatabaseExecutor txn, {
    required int productId,
    required String type,
    required double quantity,
    int? referenceDocumentId,
    String? notes,
  }) async {
    await txn.insert('stock_movements', {
      'product_id': productId,
      'type': type,
      'quantity': quantity,
      'reference_document_id': referenceDocumentId,
      'date': DateTime.now().toIso8601String(),
      'notes': notes,
    });
  }

  Future<List<StockMovement>> getStockMovements(int productId) async {
    final db = await database;
    final maps = await db.query(
      'stock_movements',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'date DESC',
    );
    return maps.map(StockMovement.fromMap).toList();
  }

  Future<void> adjustStock({
    required int productId,
    required double delta, // positive = add, negative = remove
    String? notes,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
        [delta, productId],
      );
      await _insertStockMovement(
        txn,
        productId: productId,
        type: StockMovement.typeAdjustment,
        quantity: delta,
        notes: notes,
      );
    });
    await logAuditEvent('stock_adjusted',
        entityType: 'product', entityId: productId,
        details: 'delta=$delta${notes != null ? " reason=$notes" : ""}');
  }

  // ========== Documents ==========
  /// Inserts [doc] with its [items] (stock and stock movements included).
  ///
  /// [payNowMethod]: for issued invoices only, records a full payment with
  /// this method (linked receipt + payment row) in the same transaction, so a
  /// quick sale is never left as an unpaid invoice if anything fails.
  Future<int> insertDocumentWithItems(Document doc, List<DocumentItem> items,
      {Contact? contact, String? payNowMethod}) async {
    final db = await database;
    return db.transaction((txn) async {
      int? contactId = doc.contactId;
      if (contact != null) {
        contactId = contact.id ?? await txn.insert('contacts', contact.toMap());
      }

      final docNumber = await getNextDocumentNumber(txn, doc.type);
      final newDoc = Document(
        type: doc.type,
        documentNumber: docNumber,
        date: doc.date,
        contactId: contactId,
        recipientName: contact?.name ?? doc.recipientName,
        recipientPhone: contact?.phone ?? doc.recipientPhone,
        subtotal: doc.subtotal,
        discount: doc.discount,
        taxRate: doc.taxRate,
        taxAmount: doc.taxAmount,
        total: doc.total,
        paid: doc.paid,
        remaining: doc.remaining,
        paymentMethod: doc.paymentMethod,
        validUntil: doc.validUntil,
        notes: doc.notes,
        relatedDocumentId: doc.relatedDocumentId,
        status: doc.status,
        currencyCode: doc.currencyCode,
      );

      final docId = await txn.insert('documents', newDoc.toMap());
      final isDraft = doc.status == DocumentStatus.draft;

      // Pre-check stock availability for non-draft invoices
      if (doc.type == 'invoice' && !isDraft) {
        for (final item in items) {
          if (item.productId == null || item.quantity <= 0) continue;
          final pRows = await txn.query('products',
              columns: ['name', 'type', 'stock_quantity'],
              where: 'id = ?',
              whereArgs: [item.productId]);
          if (pRows.isNotEmpty && (pRows.first['type'] as String? ?? 'product') == 'product') {
            final stock = (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0;
            if (stock < item.quantity) {
              final name = pRows.first['name'] as String? ?? '';
              throw StateError(
                  'Insufficient stock for "$name": available ${stock.toStringAsFixed(2)}, required ${item.quantity.toStringAsFixed(2)}');
            }
          }
        }
      }

      for (final item in items) {
        await txn.insert('document_items', {
          'document_id': docId,
          'product_id': item.productId,
          'description': item.description,
          'quantity': item.quantity,
          'price': item.price,
          'total': item.total,
          'taxable': item.taxable ? 1 : 0,
          'tax_rate': item.taxRate,
        });

        if (item.productId == null || item.quantity <= 0) continue;

        if (doc.type == 'invoice' && !isDraft) {
          await txn.rawUpdate(
            'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ? AND type = \'product\'',
            [item.quantity, item.productId],
          );
          final pRows = await txn.query('products', columns: ['type'], where: 'id = ?', whereArgs: [item.productId]);
          if (pRows.isNotEmpty && pRows.first['type'] == 'product') {
            await _insertStockMovement(txn, productId: item.productId!, type: StockMovement.typeSale, quantity: -item.quantity, referenceDocumentId: docId);
          }
        } else if (doc.type == 'purchase' && !isDraft) {
          await txn.rawUpdate(
            'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ? AND type = \'product\'',
            [item.quantity, item.productId],
          );
          final pRows = await txn.query('products', columns: ['type'], where: 'id = ?', whereArgs: [item.productId]);
          if (pRows.isNotEmpty && pRows.first['type'] == 'product') {
            await _insertStockMovement(txn, productId: item.productId!, type: StockMovement.typePurchase, quantity: item.quantity, referenceDocumentId: docId);
          }
        }
      }

      if (payNowMethod != null) {
        if (doc.type != 'invoice' || isDraft || doc.paid != 0) {
          throw ArgumentError(
              'payNowMethod requires an issued, unpaid invoice');
        }
        if (doc.total > 0) {
          await _recordPaymentTxn(txn,
              documentId: docId, amount: doc.total, paymentMethod: payNowMethod);
        }
      }

      return docId;
    });
  }

  Future<void> updateDocumentWithItems(Document doc, List<DocumentItem> newItems, {Contact? contact}) async {
    final db = await database;
    await db.transaction((txn) async {
      int? contactId = doc.contactId;
      if (contact != null) {
        contactId = contact.id ?? await txn.insert('contacts', contact.toMap());
      }

      final oldItems = await txn.query('document_items', where: 'document_id = ?', whereArgs: [doc.id]);
      final existingRows = await txn.query('documents', columns: ['type', 'status'], where: 'id = ?', whereArgs: [doc.id]);
      if (existingRows.isEmpty) throw StateError('Document not found');

      final oldType   = existingRows.first['type']   as String;
      final oldStatus = existingRows.first['status'] as String? ?? DocumentStatus.issued;

      final affectsStock = (oldType == 'invoice' || oldType == 'purchase') &&
          oldStatus != DocumentStatus.draft &&
          oldStatus != DocumentStatus.cancelled;
      if (affectsStock) {
        for (final old in oldItems) {
          final productId = old['product_id'] as int?;
          final qty = (old['quantity'] as num?)?.toDouble() ?? 0;
          if (productId == null || qty <= 0) continue;
          final pRows = await txn.query('products', columns: ['type'], where: 'id = ?', whereArgs: [productId]);
          if (pRows.isEmpty || pRows.first['type'] != 'product') continue;
          if (oldType == 'invoice') {
            await txn.rawUpdate('UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?', [qty, productId]);
            await _insertStockMovement(txn, productId: productId, type: StockMovement.typeCancellation, quantity: qty, referenceDocumentId: doc.id);
          } else if (oldType == 'purchase') {
            await txn.rawUpdate('UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?', [qty, productId]);
            await _insertStockMovement(txn, productId: productId, type: StockMovement.typeCancellation, quantity: -qty, referenceDocumentId: doc.id);
          }
        }
      }

      await txn.update('documents', {
        'type': doc.type,
        'document_number': doc.documentNumber,
        'date': doc.date.toIso8601String(),
        'contact_id': contactId,
        'recipient_name': contact?.name ?? doc.recipientName,
        'recipient_phone': contact?.phone ?? doc.recipientPhone,
        'subtotal': doc.subtotal,
        'discount': doc.discount,
        'tax_rate': doc.taxRate,
        'tax_amount': doc.taxAmount,
        'total': doc.total,
        'paid': doc.paid,
        'remaining': doc.remaining,
        'payment_method': doc.paymentMethod,
        'valid_until': doc.validUntil?.toIso8601String(),
        'notes': doc.notes,
        'related_document_id': doc.relatedDocumentId,
        'status': doc.status,
        'currency_code': doc.currencyCode,
      }, where: 'id = ?', whereArgs: [doc.id]);

      await txn.delete('document_items', where: 'document_id = ?', whereArgs: [doc.id]);
      final newIsDraft = doc.status == DocumentStatus.draft;

      for (final item in newItems) {
        await txn.insert('document_items', {
          'document_id': doc.id,
          'product_id': item.productId,
          'description': item.description,
          'quantity': item.quantity,
          'price': item.price,
          'total': item.total,
          'taxable': item.taxable ? 1 : 0,
          'tax_rate': item.taxRate,
        });

        if (item.productId == null || item.quantity <= 0) continue;

        if (doc.type == 'invoice' && !newIsDraft) {
          await txn.rawUpdate('UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ? AND type = \'product\'', [item.quantity, item.productId]);
          final pRows = await txn.query('products', columns: ['type'], where: 'id = ?', whereArgs: [item.productId]);
          if (pRows.isNotEmpty && pRows.first['type'] == 'product') {
            await _insertStockMovement(txn, productId: item.productId!, type: StockMovement.typeSale, quantity: -item.quantity, referenceDocumentId: doc.id);
          }
        } else if (doc.type == 'purchase' && !newIsDraft) {
          await txn.rawUpdate('UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ? AND type = \'product\'', [item.quantity, item.productId]);
          final pRows = await txn.query('products', columns: ['type'], where: 'id = ?', whereArgs: [item.productId]);
          if (pRows.isNotEmpty && pRows.first['type'] == 'product') {
            await _insertStockMovement(txn, productId: item.productId!, type: StockMovement.typePurchase, quantity: item.quantity, referenceDocumentId: doc.id);
          }
        }
      }
    });
  }

  Future<int> deleteDocument(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      final docRows = await txn.query('documents', where: 'id = ?', whereArgs: [id]);
      if (docRows.isEmpty) return 0;
      final doc = Document.fromMap(docRows.first);

      // Payment receipts: remove the linked payment row(s) from the parent
      // invoice and recalculate its paid/status.
      // For all other document types: just null out any stray receipt references
      // so the receipt_document_id FK (which has no cascade) never blocks deletion.
      if (doc.type == 'payment_receipt') {
        await txn.delete('document_payments',
            where: 'receipt_document_id = ?', whereArgs: [id]);
        if (doc.relatedDocumentId != null) {
          final invoiceRows = await txn.query('documents',
              where: 'id = ?', whereArgs: [doc.relatedDocumentId]);
          if (invoiceRows.isNotEmpty) {
            final invoice = Document.fromMap(invoiceRows.first);
            if (invoice.status != DocumentStatus.cancelled) {
              final sumRows = await txn.rawQuery(
                'SELECT COALESCE(SUM(amount), 0) AS total FROM document_payments WHERE document_id = ?',
                [doc.relatedDocumentId],
              );
              final newPaid =
                  (sumRows.first['total'] as num?)?.toDouble() ?? 0;
              final newRemaining =
                  (invoice.total - newPaid).clamp(0.0, double.infinity);
              final newStatus =
                  DocumentStatus.fromPayment(newPaid, invoice.total);
              await txn.update(
                'documents',
                {'paid': newPaid, 'remaining': newRemaining, 'status': newStatus},
                where: 'id = ?',
                whereArgs: [doc.relatedDocumentId],
              );
            }
          }
        }
      } else {
        // Non-receipt document may still be referenced by a payment row's
        // receipt_document_id (no ON DELETE cascade on that column).
        await txn.rawUpdate(
          'UPDATE document_payments SET receipt_document_id = NULL WHERE receipt_document_id = ?',
          [id],
        );
      }

      // Stock reversion for non-draft, non-cancelled invoices and purchases
      final needsStockReversal = (doc.type == 'invoice' || doc.type == 'purchase') &&
          doc.status != DocumentStatus.draft &&
          doc.status != DocumentStatus.cancelled;
      if (needsStockReversal) {
        final items = await txn.query('document_items', where: 'document_id = ?', whereArgs: [id]);
        for (final item in items) {
          final productId = item['product_id'] as int?;
          final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
          if (productId == null || qty <= 0) continue;
          final pRows = await txn.query('products', columns: ['type'], where: 'id = ?', whereArgs: [productId]);
          if (pRows.isEmpty || pRows.first['type'] != 'product') continue;
          if (doc.type == 'invoice') {
            await txn.rawUpdate('UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?', [qty, productId]);
          } else if (doc.type == 'purchase') {
            await txn.rawUpdate('UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?', [qty, productId]);
          }
        }
      }

      // Nullify related_document_id on any documents that reference this one.
      // Without this, the FK constraint prevents deletion when other documents
      // (e.g. payment receipts) still point to this document.
      await txn.rawUpdate(
        'UPDATE documents SET related_document_id = NULL WHERE related_document_id = ?',
        [id],
      );

      return txn.delete('documents', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> cancelDocument(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      final docRows = await txn.query('documents', where: 'id = ?', whereArgs: [id]);
      if (docRows.isEmpty) return;
      final doc = Document.fromMap(docRows.first);

      if (doc.status == DocumentStatus.cancelled) {
        throw StateError('Document is already cancelled');
      }

      // Payment receipts: also reverse the linked invoice payment
      if (doc.type == 'payment_receipt' && doc.relatedDocumentId != null) {
        await _reverseReceiptPayment(txn, id, doc.relatedDocumentId!);
        return;
      }

      final affectsStock = (doc.type == 'invoice' || doc.type == 'purchase') &&
          doc.status != DocumentStatus.draft;
      if (affectsStock) {
        final items = await txn.query('document_items', where: 'document_id = ?', whereArgs: [id]);
        for (final item in items) {
          final productId = item['product_id'] as int?;
          final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
          if (productId == null || qty <= 0) continue;
          final pRows = await txn.query('products', columns: ['type'], where: 'id = ?', whereArgs: [productId]);
          if (pRows.isEmpty || pRows.first['type'] != 'product') continue;
          if (doc.type == 'invoice') {
            await txn.rawUpdate('UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?', [qty, productId]);
            await _insertStockMovement(txn, productId: productId, type: StockMovement.typeCancellation, quantity: qty, referenceDocumentId: id);
          } else if (doc.type == 'purchase') {
            await txn.rawUpdate('UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?', [qty, productId]);
            await _insertStockMovement(txn, productId: productId, type: StockMovement.typeCancellation, quantity: -qty, referenceDocumentId: id);
          }
        }
      }

      await txn.update('documents', {'status': DocumentStatus.cancelled}, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> _reverseReceiptPayment(
    DatabaseExecutor txn,
    int receiptId,
    int invoiceId,
  ) async {
    // Delete the payment row linked to this receipt
    await txn.delete('document_payments', where: 'receipt_document_id = ?', whereArgs: [receiptId]);

    // Recalculate invoice from remaining payments
    final invoiceRows = await txn.query('documents', where: 'id = ?', whereArgs: [invoiceId]);
    if (invoiceRows.isNotEmpty) {
      final invoice = Document.fromMap(invoiceRows.first);
      if (invoice.status != DocumentStatus.cancelled) {
        final sumRows = await txn.rawQuery(
          'SELECT COALESCE(SUM(amount), 0) AS total FROM document_payments WHERE document_id = ?',
          [invoiceId],
        );
        final newPaid = (sumRows.first['total'] as num?)?.toDouble() ?? 0;
        final newRemaining = (invoice.total - newPaid).clamp(0.0, double.infinity);
        final newStatus = DocumentStatus.fromPayment(newPaid, invoice.total);
        await txn.update('documents', {
          'paid': newPaid,
          'remaining': newRemaining,
          'status': newStatus,
        }, where: 'id = ?', whereArgs: [invoiceId]);
      }
    }

    // Cancel the receipt document
    await txn.update('documents', {'status': DocumentStatus.cancelled}, where: 'id = ?', whereArgs: [receiptId]);
  }

  Future<void> recordPayment({
    required int documentId,
    required double amount,
    String? paymentMethod,
    String? notes,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final docRows = await txn.query('documents', where: 'id = ?', whereArgs: [documentId]);
      if (docRows.isEmpty) throw StateError('Document not found');
      final doc = Document.fromMap(docRows.first);

      if (doc.type != 'invoice' && doc.type != 'purchase') throw StateError('Payment recording is only supported for invoices and purchases');
      if (doc.status == DocumentStatus.cancelled) throw StateError('Cannot record payment on a cancelled document');
      if (doc.status == DocumentStatus.draft) throw StateError('Cannot record payment on a draft document');
      if (amount <= 0) throw ArgumentError('Payment amount must be greater than zero');
      if (amount > doc.remaining) throw ArgumentError('Payment cannot exceed remaining amount');

      await txn.insert('document_payments', {
        'document_id': documentId,
        'amount': amount,
        'payment_method': paymentMethod,
        'date': DateTime.now().toIso8601String(),
        'notes': notes,
      });

      final newPaid      = doc.paid + amount;
      final newRemaining = (doc.total - newPaid).clamp(0.0, double.infinity);
      final newStatus    = DocumentStatus.fromPayment(newPaid, doc.total);

      await txn.update('documents', {
        'paid': newPaid,
        'remaining': newRemaining,
        'status': newStatus,
      }, where: 'id = ?', whereArgs: [documentId]);
    });
  }

  /// Records a payment against an invoice and creates a linked payment_receipt document.
  /// Returns the receipt document id.
  Future<int> recordPaymentWithReceipt({
    required int documentId,
    required double amount,
    String? paymentMethod,
    String? notes,
  }) async {
    final db = await database;
    final receiptId = await db.transaction((txn) => _recordPaymentTxn(
          txn,
          documentId: documentId,
          amount: amount,
          paymentMethod: paymentMethod,
          notes: notes,
        ));
    await logAuditEvent('payment_recorded',
        entityType: 'document', entityId: documentId,
        details: 'amount=$amount method=$paymentMethod');
    return receiptId;
  }

  /// Records a payment against an invoice/purchase inside [txn]: creates the
  /// linked receipt/voucher, the payment row, and updates paid/remaining/status.
  Future<int> _recordPaymentTxn(
    Transaction txn, {
    required int documentId,
    required double amount,
    String? paymentMethod,
    String? notes,
  }) async {
    final docRows = await txn.query('documents', where: 'id = ?', whereArgs: [documentId]);
    if (docRows.isEmpty) throw StateError('Document not found');
    final doc = Document.fromMap(docRows.first);

    if (doc.type != 'invoice' && doc.type != 'purchase') throw StateError('Payment recording is only supported for invoices and purchases');
    if (doc.status == DocumentStatus.cancelled) throw StateError('Cannot record payment on a cancelled document');
    if (doc.status == DocumentStatus.draft) throw StateError('Cannot record payment on a draft document');
    if (doc.status == DocumentStatus.paid) throw StateError('Document is already fully paid');
    if (amount <= 0) throw ArgumentError('Payment amount must be greater than zero');
    if (amount > doc.remaining) throw ArgumentError('Payment cannot exceed remaining amount');

    // Create the linked voucher document (payment_receipt for invoices, expense_voucher for purchases)
    final linkedType = doc.type == 'purchase' ? 'expense_voucher' : 'payment_receipt';
    final linkedNumber = await getNextDocumentNumber(txn, linkedType);
    final now = DateTime.now();
    final receiptId = await txn.insert('documents', {
      'type': linkedType,
      'document_number': linkedNumber,
      'date': now.toIso8601String(),
      'contact_id': doc.contactId,
      'recipient_name': doc.recipientName,
      'recipient_phone': doc.recipientPhone,
      'subtotal': amount,
      'discount': 0.0,
      'tax_rate': 0.0,
      'tax_amount': 0.0,
      'total': amount,
      'paid': amount,
      'remaining': 0.0,
      'payment_method': paymentMethod,
      'valid_until': null,
      'notes': doc.documentNumber,
      'related_document_id': documentId,
      'status': DocumentStatus.issued,
      'currency_code': doc.currencyCode,
    });

    // Record the payment row linked to the receipt
    await txn.insert('document_payments', {
      'document_id': documentId,
      'amount': amount,
      'payment_method': paymentMethod,
      'date': now.toIso8601String(),
      'notes': notes,
      'receipt_document_id': receiptId,
    });

    // Update invoice totals
    final newPaid      = doc.paid + amount;
    final newRemaining = (doc.total - newPaid).clamp(0.0, double.infinity);
    final newStatus    = DocumentStatus.fromPayment(newPaid, doc.total);

    await txn.update('documents', {
      'paid': newPaid,
      'remaining': newRemaining,
      'status': newStatus,
    }, where: 'id = ?', whereArgs: [documentId]);

    return receiptId;
  }

  /// Consistent read-only snapshot of everything the derived accounting
  /// ledger is built from (one read transaction, nothing is written).
  Future<
      ({
        List<Document> documents,
        List<DocumentItem> items,
        List<Product> products,
        List<StockMovement> movements,
        List<DocumentPayment> payments,
      })> getLedgerData() async {
    final db = await database;
    return db.transaction((txn) async {
      final docs = await txn.query('documents', orderBy: 'date ASC, id ASC');
      final items = await txn.query('document_items');
      final products = await txn.query('products');
      final movements = await txn.query('stock_movements', orderBy: 'date ASC, id ASC');
      final payments = await txn.query('document_payments', orderBy: 'date ASC, id ASC');
      return (
        documents: docs.map(Document.fromMap).toList(),
        items: items.map(DocumentItem.fromMap).toList(),
        products: products.map(Product.fromMap).toList(),
        movements: movements.map(StockMovement.fromMap).toList(),
        payments: payments.map(DocumentPayment.fromMap).toList(),
      );
    });
  }

  Future<List<DocumentPayment>> getDocumentPayments(int documentId) async {
    final db = await database;
    final maps = await db.query(
      'document_payments',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'date ASC',
    );
    return maps.map(DocumentPayment.fromMap).toList();
  }

  /// Returns the invoice converted from the given quotation, if any.
  Future<Document?> getConvertedInvoice(int quotationId) async {
    final db = await database;
    final maps = await db.query(
      'documents',
      where: "type = 'invoice' AND related_document_id = ?",
      whereArgs: [quotationId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Document.fromMap(maps.first);
  }

  /// Converts a quotation to a draft invoice, preserving all items and details.
  /// Returns the new invoice document id.
  Future<int> convertQuotationToInvoice(int quotationId) async {
    final db = await database;
    return db.transaction((txn) async {
      final qRows = await txn.query('documents', where: 'id = ?', whereArgs: [quotationId]);
      if (qRows.isEmpty) throw StateError('Quotation not found');
      final quotation = Document.fromMap(qRows.first);

      if (quotation.type != 'quotation') throw ArgumentError('Document is not a quotation');
      if (quotation.status == DocumentStatus.cancelled) {
        throw StateError('Cannot convert a cancelled quotation');
      }

      // Prevent duplicate conversion
      final existing = await txn.query(
        'documents',
        where: "type = 'invoice' AND related_document_id = ?",
        whereArgs: [quotationId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final inv = Document.fromMap(existing.first);
        throw StateError('Already converted: ${inv.documentNumber}');
      }

      final invoiceNumber = await getNextDocumentNumber(txn, 'invoice');
      final now = DateTime.now();

      final invoiceId = await txn.insert('documents', {
        'type': 'invoice',
        'document_number': invoiceNumber,
        'date': now.toIso8601String(),
        'contact_id': quotation.contactId,
        'recipient_name': quotation.recipientName,
        'recipient_phone': quotation.recipientPhone,
        'subtotal': quotation.subtotal,
        'discount': quotation.discount,
        'tax_rate': quotation.taxRate,
        'tax_amount': quotation.taxAmount,
        'total': quotation.total,
        'paid': 0.0,
        'remaining': quotation.total,
        'payment_method': null,
        'valid_until': null,
        'notes': quotation.notes,
        'related_document_id': quotationId,
        'status': DocumentStatus.draft,
        'currency_code': quotation.currencyCode,
      });

      // Copy items (no stock deduction — draft)
      final qItems = await txn.query('document_items', where: 'document_id = ?', whereArgs: [quotationId]);
      for (final item in qItems) {
        await txn.insert('document_items', {
          'document_id': invoiceId,
          'product_id': item['product_id'],
          'description': item['description'],
          'quantity': item['quantity'],
          'price': item['price'],
          'total': item['total'],
          'taxable': item['taxable'],
        });
      }

      return invoiceId;
    });
  }

  /// Promotes a draft document to issued, deducting stock for invoices.
  Future<void> issueDocument(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('documents', where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) throw StateError('Document not found');
      final doc = Document.fromMap(rows.first);

      if (doc.status != DocumentStatus.draft) {
        throw StateError('Document is not a draft');
      }

      final items = await txn.query('document_items', where: 'document_id = ?', whereArgs: [id]);

      if (doc.type == 'invoice') {
        // Validate stock availability first
        for (final item in items) {
          final productId = item['product_id'] as int?;
          final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
          if (productId == null || qty <= 0) continue;
          final pRows = await txn.query('products', columns: ['name', 'type', 'stock_quantity'], where: 'id = ?', whereArgs: [productId]);
          if (pRows.isNotEmpty && pRows.first['type'] == 'product') {
            final stock = (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0;
            if (stock < qty) {
              final name = pRows.first['name'] as String? ?? '';
              throw StateError('Insufficient stock for "$name": available ${stock.toStringAsFixed(2)}, required ${qty.toStringAsFixed(2)}');
            }
          }
        }
        for (final item in items) {
          final productId = item['product_id'] as int?;
          final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
          if (productId == null || qty <= 0) continue;
          await txn.rawUpdate('UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ? AND type = \'product\'', [qty, productId]);
          final pRows = await txn.query('products', columns: ['type'], where: 'id = ?', whereArgs: [productId]);
          if (pRows.isNotEmpty && pRows.first['type'] == 'product') {
            await _insertStockMovement(txn, productId: productId, type: StockMovement.typeSale, quantity: -qty, referenceDocumentId: id);
          }
        }
      } else if (doc.type == 'purchase') {
        for (final item in items) {
          final productId = item['product_id'] as int?;
          final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
          if (productId == null || qty <= 0) continue;
          await txn.rawUpdate('UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ? AND type = \'product\'', [qty, productId]);
          final pRows = await txn.query('products', columns: ['type'], where: 'id = ?', whereArgs: [productId]);
          if (pRows.isNotEmpty && pRows.first['type'] == 'product') {
            await _insertStockMovement(txn, productId: productId, type: StockMovement.typePurchase, quantity: qty, referenceDocumentId: id);
          }
        }
      }

      final newStatus = (doc.type == 'invoice' || doc.type == 'purchase')
          ? DocumentStatus.fromPayment(doc.paid, doc.total)
          : DocumentStatus.issued;

      await txn.update('documents', {'status': newStatus}, where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Creates a new draft copy of an existing document (new number, current date, no payments).
  Future<int> copyDocumentWithItems(int sourceId) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query('documents', where: 'id = ?', whereArgs: [sourceId]);
      if (rows.isEmpty) throw StateError('Document not found');
      final source = Document.fromMap(rows.first);

      final newNumber = await getNextDocumentNumber(txn, source.type);
      final now = DateTime.now();
      final isItemBased = source.type == 'invoice' || source.type == 'quotation';

      // Financial/receipt copies start as issued; invoice/quotation copies as draft
      final newStatus = isItemBased ? DocumentStatus.draft : DocumentStatus.issued;
      final newPaid      = isItemBased ? 0.0 : source.total;
      final newRemaining = isItemBased ? source.total : 0.0;

      final newId = await txn.insert('documents', {
        'type': source.type,
        'document_number': newNumber,
        'date': now.toIso8601String(),
        'contact_id': source.contactId,
        'recipient_name': source.recipientName,
        'recipient_phone': source.recipientPhone,
        'subtotal': source.subtotal,
        'discount': source.discount,
        'tax_rate': source.taxRate,
        'tax_amount': source.taxAmount,
        'total': source.total,
        'paid': newPaid,
        'remaining': newRemaining,
        'payment_method': source.paymentMethod,
        'valid_until': source.type == 'quotation' ? source.validUntil?.toIso8601String() : null,
        'notes': source.notes,
        'related_document_id': null,
        'status': newStatus,
        'currency_code': source.currencyCode,
      });

      if (isItemBased) {
        final items = await txn.query('document_items', where: 'document_id = ?', whereArgs: [sourceId]);
        for (final item in items) {
          await txn.insert('document_items', {
            'document_id': newId,
            'product_id': item['product_id'],
            'description': item['description'],
            'quantity': item['quantity'],
            'price': item['price'],
            'total': item['total'],
            'taxable': item['taxable'],
          });
        }
      }

      return newId;
    });
  }

  Future<String> getNextDocumentNumber(DatabaseExecutor txn, String type) async {
    final prefix = switch (type) {
      'invoice'         => 'INV',
      'quotation'       => 'QUO',
      'purchase'        => 'PUR',
      'payment_receipt' => 'PAY',
      'expense_voucher' => 'EXP',
      'custom'          => 'CUS',
      _                 => 'DOC',
    };
    final rows = await txn.query('document_counters', where: 'type = ?', whereArgs: [type]);
    int next = 1;
    if (rows.isNotEmpty) {
      next = (rows.first['next_number'] as num).toInt();
      await txn.update('document_counters', {'next_number': next + 1}, where: 'type = ?', whereArgs: [type]);
    } else {
      await txn.insert('document_counters', {'type': type, 'next_number': 2});
    }
    return '$prefix-${next.toString().padLeft(5, '0')}';
  }

  Future<List<Document>> getAllDocuments() async {
    final db = await database;
    final maps = await db.query('documents', orderBy: 'date DESC');
    return maps.map((e) => Document.fromMap(e)).toList();
  }

  Future<List<Document>> getDocumentsByType(String type) async {
    final db = await database;
    final maps = await db.query('documents', where: 'type = ?', whereArgs: [type], orderBy: 'date DESC');
    return maps.map((e) => Document.fromMap(e)).toList();
  }

  Future<List<Document>> searchDocuments(String query, {String? type}) async {
    final db = await database;
    String where =
        '(document_number LIKE ? OR notes LIKE ? OR recipient_name LIKE ? OR recipient_phone LIKE ? OR contact_id IN (SELECT id FROM contacts WHERE name LIKE ? OR phone LIKE ?))';
    final args = ['%$query%', '%$query%', '%$query%', '%$query%', '%$query%', '%$query%'];
    if (type != null) {
      where += ' AND type = ?';
      args.add(type);
    }
    final maps = await db.query('documents', where: where, whereArgs: args, orderBy: 'date DESC');
    return maps.map((e) => Document.fromMap(e)).toList();
  }

  Future<Document?> getDocumentById(int id) async {
    final db = await database;
    final maps = await db.query('documents', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Document.fromMap(maps.first);
  }

  Future<List<DocumentItem>> getDocumentItems(int docId) async {
    final db = await database;
    final maps = await db.query('document_items', where: 'document_id = ?', whereArgs: [docId]);
    return maps.map((e) => DocumentItem.fromMap(e)).toList();
  }

  Future<List<Document>> getRecentDocuments({int limit = 5}) async {
    final db = await database;
    final maps = await db.query('documents', orderBy: 'date DESC', limit: limit);
    return maps.map((e) => Document.fromMap(e)).toList();
  }

  Future<Map<String, double>> getTodaySummary() async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final result = await db.rawQuery('''
      SELECT
        SUM(CASE WHEN type = 'invoice' THEN total ELSE 0 END) as sales,
        SUM(CASE WHEN type = 'invoice' THEN remaining ELSE 0 END) as outstanding
      FROM documents
      WHERE date >= ? AND date < ?
        AND status != '${DocumentStatus.draft}'
        AND status != '${DocumentStatus.cancelled}'
    ''', [start.toIso8601String(), end.toIso8601String()]);
    if (result.isEmpty || result.first['sales'] == null) {
      return {'sales': 0, 'outstanding': 0};
    }
    return {
      'sales':       (result.first['sales']       as num?)?.toDouble() ?? 0,
      'outstanding': (result.first['outstanding'] as num?)?.toDouble() ?? 0,
    };
  }

  Future<List<Document>> getDocumentsByContact(int contactId) async {
    final db = await database;
    final maps = await db.query('documents', where: 'contact_id = ?', whereArgs: [contactId], orderBy: 'date DESC');
    return maps.map((e) => Document.fromMap(e)).toList();
  }

  // ==================== Dashboard & Reports ====================

  /// Period-based financial summary for the dashboard.
  /// Sales/purchases/payments respect the date range.
  /// Customer/supplier outstanding is always all-time.
  Future<Map<String, dynamic>> getPeriodSummary({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await database;
    final fromStr = from.toIso8601String();
    final toStr = to.toIso8601String();

    // Period financial totals
    final finRows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'invoice'         THEN total ELSE 0 END), 0) AS sales,
        COALESCE(SUM(CASE WHEN type = 'purchase'        THEN total ELSE 0 END), 0) AS purchases,
        COALESCE(SUM(CASE WHEN type = 'payment_receipt' THEN total ELSE 0 END), 0) AS paymentsIn,
        COALESCE(SUM(CASE WHEN type = 'expense_voucher' THEN total ELSE 0 END), 0) AS paymentsOut
      FROM documents
      WHERE status NOT IN ('${DocumentStatus.draft}', '${DocumentStatus.cancelled}')
        AND date >= ? AND date <= ?
    ''', [fromStr, toStr]);

    final f = finRows.first;
    final double sales = (f['sales'] as num?)?.toDouble() ?? 0;
    final double purchases = (f['purchases'] as num?)?.toDouble() ?? 0;
    final double paymentsIn = (f['paymentsIn'] as num?)?.toDouble() ?? 0;
    final double paymentsOut = (f['paymentsOut'] as num?)?.toDouble() ?? 0;

    // All-time outstanding balances
    final balRows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'invoice'  THEN remaining ELSE 0 END), 0) AS customerOutstanding,
        COALESCE(SUM(CASE WHEN type = 'purchase' THEN remaining ELSE 0 END), 0) AS supplierPayable
      FROM documents
      WHERE status NOT IN ('${DocumentStatus.draft}', '${DocumentStatus.cancelled}')
    ''');

    final b = balRows.first;
    final double customerOutstanding = (b['customerOutstanding'] as num?)?.toDouble() ?? 0;
    final double supplierPayable = (b['supplierPayable'] as num?)?.toDouble() ?? 0;

    // Inventory snapshot (physical products only)
    final invRows = await db.rawQuery('''
      SELECT
        COUNT(*) AS totalProducts,
        COALESCE(SUM(CASE WHEN stock_quantity <= 0 THEN 1 ELSE 0 END), 0) AS outOfStock,
        COALESCE(SUM(CASE WHEN min_stock > 0 AND stock_quantity > 0 AND stock_quantity <= min_stock THEN 1 ELSE 0 END), 0) AS lowStock
      FROM products
      WHERE type = 'product' AND is_active = 1
    ''');

    final i = invRows.first;
    return {
      'sales': sales,
      'purchases': purchases,
      'paymentsIn': paymentsIn,
      'paymentsOut': paymentsOut,
      'customerOutstanding': customerOutstanding,
      'supplierPayable': supplierPayable,
      'totalProducts': (i['totalProducts'] as num?)?.toInt() ?? 0,
      'lowStock': (i['lowStock'] as num?)?.toInt() ?? 0,
      'outOfStock': (i['outOfStock'] as num?)?.toInt() ?? 0,
    };
  }

  /// Documents of a given type within a date range. Excludes drafts.
  /// Include cancelled = true shows them so the report can display separately.
  Future<List<Document>> getDocumentsInPeriod({
    required String type,
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await database;
    final maps = await db.query(
      'documents',
      where: "type = ? AND date >= ? AND date <= ? AND status != '${DocumentStatus.draft}'",
      whereArgs: [type, from.toIso8601String(), to.toIso8601String()],
      orderBy: 'date DESC',
    );
    return maps.map((e) => Document.fromMap(e)).toList();
  }

  /// Contact balance summary for customer/supplier report (all-time).
  Future<List<Map<String, dynamic>>> getContactBalances(
      String contactType, String docType) async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        c.id AS contact_id,
        c.name,
        c.phone,
        COALESCE(SUM(d.total), 0)     AS total_amount,
        COALESCE(SUM(d.paid), 0)      AS total_paid,
        COALESCE(SUM(d.remaining), 0) AS outstanding,
        COUNT(d.id)                   AS doc_count
      FROM contacts c
      LEFT JOIN documents d ON d.contact_id = c.id
        AND d.type = ?
        AND d.status NOT IN ('${DocumentStatus.draft}', '${DocumentStatus.cancelled}')
      WHERE c.type = ?
      GROUP BY c.id
      ORDER BY outstanding DESC, c.name
    ''', [docType, contactType]);
  }

  /// Product-level sales and purchase quantities within a period.
  Future<List<Map<String, dynamic>>> getProductReport({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        p.id, p.name, p.type AS product_type,
        p.stock_quantity, p.min_stock, p.purchase_price,
        COALESCE(SUM(CASE WHEN d.type = 'invoice'  THEN di.quantity ELSE 0 END), 0) AS sales_qty,
        COALESCE(SUM(CASE WHEN d.type = 'invoice'  THEN di.total    ELSE 0 END), 0) AS sales_value,
        COALESCE(SUM(CASE WHEN d.type = 'purchase' THEN di.quantity ELSE 0 END), 0) AS purchase_qty,
        COALESCE(SUM(CASE WHEN d.type = 'purchase' THEN di.total    ELSE 0 END), 0) AS purchase_value
      FROM products p
      LEFT JOIN document_items di ON di.product_id = p.id
      LEFT JOIN documents d ON d.id = di.document_id
        AND d.status NOT IN ('${DocumentStatus.draft}', '${DocumentStatus.cancelled}')
        AND d.date >= ? AND d.date <= ?
      WHERE p.is_active = 1
      GROUP BY p.id
      ORDER BY sales_value DESC, p.name
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  /// Payments recorded in the given period with their linked document info.
  Future<List<Map<String, dynamic>>> getPaymentReport({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        dp.id, dp.amount, dp.payment_method, dp.date, dp.notes,
        dp.document_id,
        d.document_number, d.type AS doc_type, d.recipient_name
      FROM document_payments dp
      JOIN documents d ON d.id = dp.document_id
      WHERE dp.date >= ? AND dp.date <= ?
      ORDER BY dp.date DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  Future<void> logAuditEvent(
    String action, {
    String? entityType,
    int? entityId,
    String? details,
  }) async {
    try {
      final db = await database;
      await db.insert('audit_log', {
        'action': action,
        'entity_type': entityType,
        'entity_id': entityId,
        'details': details,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Never fail the main operation due to audit logging
    }
  }

  Future<List<Map<String, dynamic>>> getRecentAuditEvents({int limit = 100}) async {
    final db = await database;
    return db.query('audit_log', orderBy: 'timestamp DESC', limit: limit);
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // ========== Tax Profiles ==========

  Future<int> insertTaxProfile(TaxProfile p) async {
    final db = await database;
    return db.transaction((txn) async {
      if (p.isDefault) {
        await txn.update('tax_profiles', {'is_default': 0});
      }
      return txn.insert('tax_profiles', p.toMap());
    });
  }

  Future<int> updateTaxProfile(TaxProfile p) async {
    final db = await database;
    return db.transaction((txn) async {
      if (p.isDefault) {
        await txn.update('tax_profiles', {'is_default': 0},
            where: 'id != ?', whereArgs: [p.id]);
      }
      return txn.update('tax_profiles', p.toMap(),
          where: 'id = ?', whereArgs: [p.id]);
    });
  }

  Future<int> deleteTaxProfile(int id) async {
    final db = await database;
    return db.delete('tax_profiles', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TaxProfile>> getTaxProfiles({bool activeOnly = false}) async {
    final db = await database;
    final maps = await db.query(
      'tax_profiles',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'is_default DESC, name',
    );
    return maps.map(TaxProfile.fromMap).toList();
  }

  Future<TaxProfile?> getTaxProfileById(int id) async {
    final db = await database;
    final maps =
        await db.query('tax_profiles', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return TaxProfile.fromMap(maps.first);
  }

  Future<TaxProfile?> getDefaultTaxProfile() async {
    final db = await database;
    final maps = await db.query('tax_profiles',
        where: 'is_default = 1 AND is_active = 1', limit: 1);
    if (maps.isEmpty) return null;
    return TaxProfile.fromMap(maps.first);
  }

  // ========== Payment Methods ==========

  Future<List<PaymentMethod>> getPaymentMethods() async {
    final db = await database;
    final maps = await db.query('payment_methods', orderBy: 'sort_order, id');
    return maps.map(PaymentMethod.fromMap).toList();
  }

  Future<List<PaymentMethod>> getEnabledPaymentMethods() async {
    final db = await database;
    final maps = await db.query('payment_methods',
        where: 'is_enabled = 1', orderBy: 'sort_order, id');
    return maps.map(PaymentMethod.fromMap).toList();
  }

  Future<PaymentMethod?> getDefaultPaymentMethod() async {
    final db = await database;
    final maps = await db.query('payment_methods',
        where: 'is_default = 1', limit: 1);
    if (maps.isEmpty) return null;
    return PaymentMethod.fromMap(maps.first);
  }

  Future<void> setPaymentMethodEnabled(String key, {required bool enabled}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('payment_methods', {'is_enabled': enabled ? 1 : 0},
          where: 'key = ?', whereArgs: [key]);
      // If disabling the default, move default to cash (or first enabled)
      if (!enabled) {
        final defaults = await txn.query('payment_methods',
            where: 'is_default = 1 AND key = ?', whereArgs: [key]);
        if (defaults.isNotEmpty) {
          await txn.update('payment_methods', {'is_default': 0},
              where: 'key = ?', whereArgs: [key]);
          final fallback = await txn.query('payment_methods',
              where: 'is_enabled = 1 AND key != ?',
              whereArgs: [key],
              orderBy: 'sort_order, id',
              limit: 1);
          if (fallback.isNotEmpty) {
            await txn.update('payment_methods', {'is_default': 1},
                where: 'id = ?', whereArgs: [fallback.first['id']]);
          }
        }
      }
    });
  }

  Future<void> setPaymentMethodDefault(String key) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('payment_methods', {'is_default': 0});
      await txn.update('payment_methods',
          {'is_default': 1, 'is_enabled': 1},
          where: 'key = ?', whereArgs: [key]);
    });
  }

  Future<int> insertCustomPaymentMethod({
    required String key,
    required String labelAr,
    required String labelEn,
  }) async {
    final db = await database;
    final maxOrder = Sqflite.firstIntValue(
        await db.rawQuery('SELECT MAX(sort_order) FROM payment_methods')) ?? 0;
    return db.insert('payment_methods', {
      'key': key,
      'label_ar': labelAr,
      'label_en': labelEn,
      'is_enabled': 1,
      'is_default': 0,
      'sort_order': maxOrder + 1,
      'is_predefined': 0,
    });
  }

  Future<void> updatePaymentMethodLabel(
      int id, String labelAr, String labelEn) async {
    final db = await database;
    await db.update('payment_methods',
        {'label_ar': labelAr, 'label_en': labelEn},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> isPaymentMethodUsedInDocuments(String key) async {
    final db = await database;
    final r1 = await db.query('documents',
        columns: ['id'], where: 'payment_method = ?', whereArgs: [key], limit: 1);
    if (r1.isNotEmpty) return true;
    final r2 = await db.query('document_payments',
        columns: ['id'], where: 'payment_method = ?', whereArgs: [key], limit: 1);
    return r2.isNotEmpty;
  }

  Future<int> deletePaymentMethod(int id) async {
    final db = await database;
    return db.delete('payment_methods', where: 'id = ? AND is_predefined = 0', whereArgs: [id]);
  }
}
