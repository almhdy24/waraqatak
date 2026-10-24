import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/currency.dart';
import '../models/payment_method.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../models/document.dart';
import '../models/document_item.dart';
import '../models/document_payment.dart';
import '../models/document_status.dart';
import '../models/tax_profile.dart';
import '../models/app_notification.dart';
import '../models/diagnostic_report.dart';
import '../models/stocktake.dart';
import '../services/inventory_costing_service.dart';
import '../utils/format_utils.dart';
import '../utils/money_utils.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  DatabaseHelper._privateConstructor();

  static const int dbVersion = 17;

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
    {
      'key': 'cash',
      'label_ar': 'نقداً',
      'label_en': 'Cash',
      'is_enabled': 1,
      'is_default': 1,
      'sort_order': 0,
      'is_predefined': 1,
    },
    {
      'key': 'bank',
      'label_ar': 'تحويل بنكي',
      'label_en': 'Bank Transfer',
      'is_enabled': 1,
      'is_default': 0,
      'sort_order': 1,
      'is_predefined': 1,
    },
    {
      'key': 'card',
      'label_ar': 'بطاقة ائتمان',
      'label_en': 'Credit/Debit Card',
      'is_enabled': 0,
      'is_default': 0,
      'sort_order': 2,
      'is_predefined': 1,
    },
    {
      'key': 'mobile',
      'label_ar': 'محفظة جوّال',
      'label_en': 'Mobile Wallet',
      'is_enabled': 0,
      'is_default': 0,
      'sort_order': 3,
      'is_predefined': 1,
    },
    {
      'key': 'bankak',
      'label_ar': 'بنكك',
      'label_en': 'Bankak',
      'is_enabled': 0,
      'is_default': 0,
      'sort_order': 4,
      'is_predefined': 1,
    },
    {
      'key': 'okash',
      'label_ar': 'أوكاش',
      'label_en': 'oCash',
      'is_enabled': 0,
      'is_default': 0,
      'sort_order': 5,
      'is_predefined': 1,
    },
    {
      'key': 'mada',
      'label_ar': 'مدى',
      'label_en': 'Mada',
      'is_enabled': 0,
      'is_default': 0,
      'sort_order': 6,
      'is_predefined': 1,
    },
    {
      'key': 'fawry',
      'label_ar': 'فوري',
      'label_en': 'Fawry',
      'is_enabled': 0,
      'is_default': 0,
      'sort_order': 7,
      'is_predefined': 1,
    },
    {
      'key': 'paypal',
      'label_ar': 'باي بال',
      'label_en': 'PayPal',
      'is_enabled': 0,
      'is_default': 0,
      'sort_order': 8,
      'is_predefined': 1,
    },
  ];

  static Future<void> _seedPaymentMethods(DatabaseExecutor db) async {
    for (final seed in _paymentMethodSeeds) {
      await db.insert(
        'payment_methods',
        seed,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
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
        category TEXT,
        tax_profile_id INTEGER,
        average_cost REAL,
        cost_status TEXT DEFAULT 'unknown',
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_products_name ON products(name)');
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
    await db.execute(
      'CREATE INDEX idx_products_category ON products(category)',
    );

    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        reference_document_id INTEGER,
        date TEXT NOT NULL,
        notes TEXT,
        unit_cost REAL,
        total_cost REAL,
        cost_status TEXT DEFAULT 'unknown',
        provenance TEXT,
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (reference_document_id) REFERENCES documents(id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_stock_movements_product ON stock_movements(product_id)',
    );
    await db.execute(
      'CREATE INDEX idx_stock_movements_cost ON stock_movements(cost_status)',
    );

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
        unit_cost REAL,
        total_cost REAL,
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER UNIQUE NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        category TEXT NOT NULL,
        action_url TEXT,
        target_audience TEXT,
        published_at TEXT NOT NULL,
        expires_at TEXT,
        is_read INTEGER NOT NULL DEFAULT 0,
        read_at TEXT,
        synced_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cached_notif_server ON cached_notifications(server_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cached_notif_read ON cached_notifications(is_read)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS diagnostic_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_uuid TEXT UNIQUE NOT NULL,
        app_version TEXT NOT NULL,
        platform TEXT NOT NULL,
        os_version TEXT NOT NULL,
        exception_type TEXT NOT NULL,
        sanitized_message TEXT,
        sanitized_stack_trace TEXT,
        operation TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_diag_uuid ON diagnostic_reports(report_uuid)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_diag_created ON diagnostic_reports(created_at)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stocktake_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_number TEXT UNIQUE NOT NULL,
        status TEXT NOT NULL,
        started_at TEXT NOT NULL,
        completed_at TEXT,
        notes TEXT,
        category_filter TEXT,
        total_items INTEGER DEFAULT 0,
        matched_items INTEGER DEFAULT 0,
        discrepant_items INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stocktake_sessions_status ON stocktake_sessions(status)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stocktake_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        baseline_quantity REAL NOT NULL,
        counted_quantity REAL,
        reconciled_system_quantity REAL,
        variance REAL,
        unit_cost REAL,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY (session_id) REFERENCES stocktake_sessions(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stocktake_items_session ON stocktake_items(session_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stocktake_items_product ON stocktake_items(product_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_log_action ON audit_log(action)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_log_timestamp ON audit_log(timestamp)',
    );
  }

  @visibleForTesting
  Future<void> upgradeTablesForTest(
    DatabaseExecutor db,
    int oldVersion,
    int newVersion,
  ) => _upgradeTables(db, oldVersion, newVersion);

  Future<void> _upgradeTables(
    DatabaseExecutor db,
    int oldVersion,
    int newVersion,
  ) async {
    Future<bool> columnExists(String table, String column) async {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      return columns.any((c) => c['name'] == column);
    }

    if (oldVersion < 2) {
      if (!await columnExists('documents', 'payment_method')) {
        await db.execute(
          'ALTER TABLE documents ADD COLUMN payment_method TEXT',
        );
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
        await db.execute(
          "ALTER TABLE businesses ADD COLUMN currency_code TEXT DEFAULT 'SDG'",
        );
      }
      if (!await columnExists('documents', 'currency_code')) {
        await db.execute(
          "ALTER TABLE documents ADD COLUMN currency_code TEXT DEFAULT 'SDG'",
        );
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
        await db.execute(
          "ALTER TABLE products ADD COLUMN type TEXT DEFAULT 'product'",
        );
      }
      if (!await columnExists('products', 'barcode')) {
        await db.execute('ALTER TABLE products ADD COLUMN barcode TEXT');
      }
      if (!await columnExists('products', 'unit')) {
        await db.execute('ALTER TABLE products ADD COLUMN unit TEXT');
      }
      if (!await columnExists('products', 'is_active')) {
        await db.execute(
          'ALTER TABLE products ADD COLUMN is_active INTEGER DEFAULT 1',
        );
      }
      if (!await columnExists('products', 'created_at')) {
        await db.execute('ALTER TABLE products ADD COLUMN created_at TEXT');
      }
      if (!await columnExists('products', 'updated_at')) {
        await db.execute('ALTER TABLE products ADD COLUMN updated_at TEXT');
      }
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_name ON products(name)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)',
      );
    }

    if (oldVersion < 8) {
      if (!await columnExists('contacts', 'email')) {
        await db.execute('ALTER TABLE contacts ADD COLUMN email TEXT');
      }
      if (!await columnExists('contacts', 'notes')) {
        await db.execute('ALTER TABLE contacts ADD COLUMN notes TEXT');
      }
      if (!await columnExists('contacts', 'active')) {
        await db.execute(
          'ALTER TABLE contacts ADD COLUMN active INTEGER DEFAULT 1',
        );
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
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_stock_movements_product ON stock_movements(product_id)',
      );
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
        try {
          await db.execute(col);
        } on DatabaseException catch (_) {
          // Column already exists on this install — ignore and continue.
        }
      }
      // contacts: legal identity
      for (final col in [
        "ALTER TABLE contacts ADD COLUMN legal_name TEXT",
        "ALTER TABLE contacts ADD COLUMN tax_id TEXT",
      ]) {
        try {
          await db.execute(col);
        } on DatabaseException catch (_) {
          // Column already exists on this install — ignore and continue.
        }
      }
      // products: tax profile link
      if (!await columnExists('products', 'tax_profile_id')) {
        await db.execute(
          'ALTER TABLE products ADD COLUMN tax_profile_id INTEGER',
        );
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
        await db.update('payment_methods', {
          'is_enabled': 0,
          'is_default': 0,
        }, where: 'is_predefined = 1');
        bool firstSet = false;
        for (final key in enabledKeys) {
          if (key.startsWith('custom_')) continue;
          await db.update(
            'payment_methods',
            {'is_enabled': 1, 'is_default': firstSet ? 0 : 1},
            where: 'key = ?',
            whereArgs: [key],
          );
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
      final defaults = await db.query(
        'payment_methods',
        where: 'is_default = 1',
        limit: 1,
      );
      if (defaults.isEmpty) {
        await db.update(
          'payment_methods',
          {'is_default': 1, 'is_enabled': 1},
          where: 'key = ?',
          whereArgs: ['cash'],
        );
      }

      await prefs.remove('payment_methods');
      await prefs.remove('custom_payment_methods_v1');
    }

    if (oldVersion < 12) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cached_notifications (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          server_id INTEGER UNIQUE NOT NULL,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          category TEXT NOT NULL,
          action_url TEXT,
          target_audience TEXT,
          published_at TEXT NOT NULL,
          expires_at TEXT,
          is_read INTEGER NOT NULL DEFAULT 0,
          read_at TEXT,
          synced_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cached_notif_server ON cached_notifications(server_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_cached_notif_read ON cached_notifications(is_read)',
      );
    }

    if (oldVersion < 13) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS diagnostic_reports (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          report_uuid TEXT UNIQUE NOT NULL,
          app_version TEXT NOT NULL,
          platform TEXT NOT NULL,
          os_version TEXT NOT NULL,
          exception_type TEXT NOT NULL,
          sanitized_message TEXT,
          sanitized_stack_trace TEXT,
          operation TEXT NOT NULL,
          occurred_at TEXT NOT NULL,
          created_at TEXT NOT NULL,
          retry_count INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_diag_uuid ON diagnostic_reports(report_uuid)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_diag_created ON diagnostic_reports(created_at)',
      );
    }

    if (oldVersion < 14) {
      if (!await columnExists('products', 'category')) {
        await db.execute('ALTER TABLE products ADD COLUMN category TEXT');
      }
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_category ON products(category)',
      );
    }

    if (oldVersion < 15) {
      if (!await columnExists('products', 'average_cost')) {
        await db.execute('ALTER TABLE products ADD COLUMN average_cost REAL');
      }
      if (!await columnExists('products', 'cost_status')) {
        await db.execute(
          "ALTER TABLE products ADD COLUMN cost_status TEXT DEFAULT 'unknown'",
        );
      }
      if (!await columnExists('stock_movements', 'unit_cost')) {
        await db.execute(
          'ALTER TABLE stock_movements ADD COLUMN unit_cost REAL',
        );
      }
      if (!await columnExists('stock_movements', 'total_cost')) {
        await db.execute(
          'ALTER TABLE stock_movements ADD COLUMN total_cost REAL',
        );
      }
      if (!await columnExists('stock_movements', 'cost_status')) {
        await db.execute(
          "ALTER TABLE stock_movements ADD COLUMN cost_status TEXT DEFAULT 'unknown'",
        );
      }
      if (!await columnExists('stock_movements', 'provenance')) {
        await db.execute(
          'ALTER TABLE stock_movements ADD COLUMN provenance TEXT',
        );
      }
      if (!await columnExists('document_items', 'unit_cost')) {
        await db.execute(
          'ALTER TABLE document_items ADD COLUMN unit_cost REAL',
        );
      }
      if (!await columnExists('document_items', 'total_cost')) {
        await db.execute(
          'ALTER TABLE document_items ADD COLUMN total_cost REAL',
        );
      }
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_stock_movements_cost ON stock_movements(cost_status)',
      );

      await _migrateLegacyCosting(db);
    }

    if (oldVersion < 16) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS stocktake_sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_number TEXT UNIQUE NOT NULL,
          status TEXT NOT NULL,
          started_at TEXT NOT NULL,
          completed_at TEXT,
          notes TEXT,
          category_filter TEXT,
          total_items INTEGER DEFAULT 0,
          matched_items INTEGER DEFAULT 0,
          discrepant_items INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_stocktake_sessions_status ON stocktake_sessions(status)',
      );

      await db.execute('''
        CREATE TABLE IF NOT EXISTS stocktake_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          baseline_quantity REAL NOT NULL,
          counted_quantity REAL,
          reconciled_system_quantity REAL,
          variance REAL,
          unit_cost REAL,
          notes TEXT,
          status TEXT NOT NULL DEFAULT 'pending',
          FOREIGN KEY (session_id) REFERENCES stocktake_sessions(id) ON DELETE CASCADE,
          FOREIGN KEY (product_id) REFERENCES products(id)
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_stocktake_items_session ON stocktake_items(session_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_stocktake_items_product ON stocktake_items(product_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_audit_log_action ON audit_log(action)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_audit_log_timestamp ON audit_log(timestamp)',
      );
    }

    if (oldVersion < 17) {
      // v1.1.3 hotfix: Re-run the historical invoice item costing repair for
      // databases that were upgraded to v15/v16 before step 6 of
      // _migrateLegacyCosting (invoice item cost reconstruction) was
      // introduced, or where that step left recoverable items as NULL.
      //
      // This migration is strictly additive and idempotent:
      //   - It only writes to rows where total_cost IS NULL.
      //   - It never replaces a non-NULL cost.
      //   - It never invents cost values; it only uses defensible purchase
      //     evidence already present in the database.
      //   - It runs inside the existing _upgradeTables transaction so a
      //     crash mid-migration will not leave partial data.
      await _repairInvoiceItemCosts(db);
    }
  }

  Future<void> _migrateLegacyCosting(DatabaseExecutor db) async {
    // Idempotency note: All UPDATE statements use WHERE guards that exclude
    // rows already repaired (cost_status != 'unknown' OR unit_cost IS NOT NULL),
    // so running this migration twice is safe.

    // 1. Reconstruct purchase movements from linked purchase document items.
    //    Only update rows that still have no cost recorded (idempotent).
    final purchaseMovements = await db.rawQuery('''
      SELECT sm.id AS movement_id, sm.product_id, sm.quantity, sm.reference_document_id,
             di.price AS item_price
      FROM stock_movements sm
      INNER JOIN documents d ON d.id = sm.reference_document_id AND d.type = 'purchase'
      INNER JOIN document_items di ON di.document_id = d.id AND di.product_id = sm.product_id
      WHERE sm.type = 'purchase' AND sm.reference_document_id IS NOT NULL
        AND (sm.unit_cost IS NULL OR sm.cost_status = '${StockMovement.costStatusUnknown}')
    ''');

    for (final pm in purchaseMovements) {
      final mid = pm['movement_id'] as int;
      final price = (pm['item_price'] as num?)?.toDouble() ?? 0.0;
      final qty = (pm['quantity'] as num?)?.toDouble() ?? 0.0;
      if (price > 0) {
        await db.update(
          'stock_movements',
          {
            'unit_cost': price,
            'total_cost': qty * price,
            'cost_status': StockMovement.costStatusReconstructed,
            'provenance': 'purchase_document_item',
          },
          where: 'id = ?',
          whereArgs: [mid],
        );
      }
    }

    // 2. Reconstruct purchase document_items cost fields (idempotent: only
    //    update rows where unit_cost is still null).
    await db.rawUpdate('''
      UPDATE document_items
      SET unit_cost = price, total_cost = quantity * price
      WHERE document_id IN (SELECT id FROM documents WHERE type = 'purchase')
        AND unit_cost IS NULL
    ''');

    // 3. Mark opening movements without cost basis as unknown (idempotent).
    await db.rawUpdate('''
      UPDATE stock_movements
      SET cost_status = '${StockMovement.costStatusUnknown}', provenance = 'legacy_opening'
      WHERE type = '${StockMovement.typeOpening}' AND (cost_status = 'unknown' OR cost_status IS NULL)
        AND unit_cost IS NULL
    ''');

    // 4. Mark legacy sale and cancellation movements as unknown (idempotent).
    await db.rawUpdate('''
      UPDATE stock_movements
      SET cost_status = '${StockMovement.costStatusUnknown}', provenance = 'legacy_sale'
      WHERE type = '${StockMovement.typeSale}' AND (cost_status = 'unknown' OR cost_status IS NULL)
        AND unit_cost IS NULL
    ''');
    await db.rawUpdate('''
      UPDATE stock_movements
      SET cost_status = '${StockMovement.costStatusUnknown}', provenance = 'legacy_cancellation'
      WHERE type = '${StockMovement.typeCancellation}' AND (cost_status = 'unknown' OR cost_status IS NULL)
        AND unit_cost IS NULL
    ''');

    // 5. Products: if a product only has reconstructed purchases and no unknown movements,
    // and stock > 0, calculate its current average cost. Otherwise, leave as unknown.
    final products = await db.query(
      'products',
      columns: ['id', 'stock_quantity'],
    );
    for (final p in products) {
      final pid = p['id'] as int;
      final stock = (p['stock_quantity'] as num?)?.toDouble() ?? 0.0;
      if (stock <= 0) continue;

      final unknownCount =
          Sqflite.firstIntValue(
            await db.rawQuery(
              '''
        SELECT COUNT(*) FROM stock_movements
        WHERE product_id = ? AND (cost_status = '${StockMovement.costStatusUnknown}' OR cost_status IS NULL)
      ''',
              [pid],
            ),
          ) ??
          0;

      if (unknownCount == 0) {
        final movements = await db.rawQuery(
          '''
          SELECT type, quantity, unit_cost FROM stock_movements
          WHERE product_id = ?
          ORDER BY date ASC, id ASC
        ''',
          [pid],
        );

        double runningStock = 0;
        double? runningAvg;
        for (final m in movements) {
          final mType = m['type'] as String;
          final mQty = (m['quantity'] as num).toDouble();
          final mCost = (m['unit_cost'] as num?)?.toDouble();
          if (mType == StockMovement.typePurchase && mCost != null) {
            runningAvg = InventoryCostingService.calculateNewWeightedAverage(
              currentStock: runningStock,
              currentAvgCost: runningAvg,
              incomingQty: mQty,
              incomingUnitCost: mCost,
            );
            runningStock += mQty;
          } else if (mType == StockMovement.typeSale) {
            runningStock += mQty;
          }
        }

        if (runningAvg != null && runningAvg > 0) {
          await db.update(
            'products',
            {
              'average_cost': runningAvg,
              'cost_status': Product.costStatusKnown,
            },
            where: 'id = ?',
            whereArgs: [pid],
          );
        }
      }
    }

    // Historical invoice document_items repair is handled exclusively by
    // _repairInvoiceItemCosts in the v17 migration branch. This prevents legacy
    // step 6 from prematurely populating invoice costs with catalog averages
    // during a direct v14-to-v17 upgrade.
  }

  /// Narrowly-scoped, idempotent repair of historical invoice document_items
  /// that are still missing unit_cost / total_cost after legacy migrations.
  ///
  /// Called from the v17 migration so that:
  ///   - Users upgrading from v14 (pre-costing) receive the safe repair once.
  ///   - Users upgrading from v15/v16 receive the repair without re-running v15.
  ///
  /// Reconstruction rules (IAS 2 moving weighted average):
  ///   (a) Calculate moving weighted-average cost across all finalized purchases
  ///       strictly on or before the invoice date (date <= docDate).
  ///   (b) If an opening stock movement exists with a known unit cost on or
  ///       before docDate, it enters the pool at that known cost.
  ///   (c) If an opening stock or adjustment with UNKNOWN cost exists on or before
  ///       docDate, the true weighted average cannot be established without
  ///       guessing, so the cost remains NULL (unknown).
  ///   (d) Never use purchases dated after the invoice date.
  ///   (e) Never use today's products.average_cost as a historical fallback.
  ///
  /// Cross-table consistency:
  ///   - Repaired document_items update their corresponding sale stock_movements
  ///     by primary key ID, matching by quantity to avoid collision on multi-line
  ///     invoices referencing the same product.
  ///   - stock_movements.total_cost is computed as ABS(quantity) * unitCost.
  ///   - Existing non-NULL / known costs are never overwritten.
  static Future<void> _repairInvoiceItemCosts(DatabaseExecutor db) async {
    // Fetch uncosted invoice items (product-linked, positive quantity,
    // non-draft, non-cancelled).
    final uncostedItems = await db.rawQuery('''
      SELECT di.id AS item_id, di.product_id, di.quantity,
             d.id AS doc_id, d.date AS doc_date
      FROM document_items di
      INNER JOIN documents d ON d.id = di.document_id
      WHERE d.type = 'invoice'
        AND d.status NOT IN ('${DocumentStatus.draft}', '${DocumentStatus.cancelled}')
        AND di.product_id IS NOT NULL
        AND di.quantity > 0
        AND di.total_cost IS NULL
    ''');

    if (uncostedItems.isEmpty) return; // Nothing to repair — fast exit.

    // Audit log header (best-effort; failure must not abort the migration).
    try {
      await db.insert('audit_log', {
        'action': 'v17_costing_repair_start',
        'entity_type': 'migration',
        'entity_id': null,
        'details': 'Repairing ${uncostedItems.length} uncosted invoice item(s)',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    int repairedCount = 0;

    for (final row in uncostedItems) {
      final itemId = row['item_id'] as int;
      final productId = row['product_id'] as int;
      final docId = row['doc_id'] as int;
      final qty = (row['quantity'] as num).toDouble();
      final docDate = row['doc_date'] as String;

      double? reconstructedUnitCost;

      // 1. Check if any incoming stock movement with unknown cost occurred on or
      //    before the invoice date (e.g. uncosted legacy opening stock, uncosted
      //    adjustment, or uncosted sale cancellation return).
      //    If so, the cost basis of the inventory pool is unknown and cannot be
      //    calculated without fabrication.
      final hasUnknownIncoming =
          (Sqflite.firstIntValue(
                await db.rawQuery(
                  '''
        SELECT COUNT(*) FROM stock_movements
        WHERE product_id = ?
          AND quantity > 0
          AND type IN ('${StockMovement.typeOpening}', '${StockMovement.typeAdjustment}', '${StockMovement.typeCancellation}')
          AND (cost_status = '${StockMovement.costStatusUnknown}' OR cost_status IS NULL OR unit_cost IS NULL OR unit_cost <= 0)
          AND date <= ?
      ''',
                  [productId, docDate],
                ),
              ) ??
              0) >
          0;

      if (!hasUnknownIncoming) {
        // 2. Query all finalized purchases strictly on or before docDate in chronological order.
        final purchasesBefore = await db.rawQuery(
          '''
          SELECT di_p.quantity, di_p.price AS unit_cost, d_p.date AS doc_date
          FROM document_items di_p
          INNER JOIN documents d_p ON d_p.id = di_p.document_id
          WHERE d_p.type = 'purchase'
            AND d_p.status NOT IN ('${DocumentStatus.draft}', '${DocumentStatus.cancelled}')
            AND di_p.product_id = ?
            AND d_p.date <= ?
            AND di_p.price > 0
          ORDER BY d_p.date ASC, d_p.id ASC
        ''',
          [productId, docDate],
        );

        // 3. Query all other incoming stock movements with known unit cost on or before docDate
        //    (opening stock, positive adjustments, and positive returns/cancellations).
        final otherIncomingBefore = await db.rawQuery(
          '''
          SELECT quantity, unit_cost, date
          FROM stock_movements
          WHERE product_id = ?
            AND quantity > 0
            AND type IN ('${StockMovement.typeOpening}', '${StockMovement.typeAdjustment}', '${StockMovement.typeCancellation}')
            AND cost_status = '${StockMovement.costStatusKnown}'
            AND unit_cost IS NOT NULL
            AND unit_cost > 0
            AND date <= ?
          ORDER BY date ASC, id ASC
        ''',
          [productId, docDate],
        );

        final allIncomingCosts = <double>[
          ...purchasesBefore.map((p) => (p['unit_cost'] as num).toDouble()),
          ...otherIncomingBefore.map((o) => (o['unit_cost'] as num).toDouble()),
        ];

        if (allIncomingCosts.isNotEmpty) {
          final firstPrice = allIncomingCosts.first;
          // Check if all incoming inventory batches on or before docDate had the identical unit price.
          // If batches had varying prices (or different adjustment / opening costs), moving weighted
          // average cannot be verified without complete chronological replay of intermediate sales
          // and stockouts. In that case, we leave reconstructedUnitCost = NULL.
          final allSamePrice = allIncomingCosts.every(
            (c) => (c - firstPrice).abs() < 0.001,
          );
          if (allSamePrice && firstPrice > 0) {
            reconstructedUnitCost = firstPrice;
          }
        }
      }

      // If no defensible historical evidence exists on or before docDate,
      // reconstructedUnitCost remains NULL. Never fall back to products.average_cost.

      if (reconstructedUnitCost != null && reconstructedUnitCost > 0) {
        // Reconcile corresponding stock_movement unambiguously:
        final itemCountForProduct =
            (Sqflite.firstIntValue(
              await db.rawQuery(
                '''
          SELECT COUNT(*) FROM document_items
          WHERE document_id = ? AND product_id = ?
        ''',
                [docId, productId],
              ),
            ) ??
            0);

        final candidateMovements = await db.rawQuery(
          '''
          SELECT id, quantity
          FROM stock_movements
          WHERE reference_document_id = ?
            AND product_id = ?
            AND type = '${StockMovement.typeSale}'
            AND (cost_status = '${StockMovement.costStatusUnknown}' OR unit_cost IS NULL)
          ORDER BY id ASC
        ''',
          [docId, productId],
        );

        int? targetMovementId;
        if (itemCountForProduct == 1 && candidateMovements.length == 1) {
          final mQty =
              ((candidateMovements.first['quantity'] as num).toDouble()).abs();
          // Unambiguous 1-to-1 match ONLY if movement quantity matches invoice line quantity
          // exactly (verifying the line was fully deducted from stock, NOT oversold).
          if ((mQty - qty).abs() < 0.001) {
            targetMovementId = candidateMovements.first['id'] as int;
          }
        } else if (itemCountForProduct > 1 && candidateMovements.isNotEmpty) {
          // Multiple invoice lines exist for this product.
          // Match ONLY if there is an exact, unique quantity match:
          // 1. Exactly one candidate movement has ABS(quantity) == qty.
          // 2. Exactly one line item for this product on this invoice has quantity == qty.
          final exactQtyMatches = candidateMovements
              .where(
                (m) =>
                    (((m['quantity'] as num).toDouble()).abs() - qty).abs() <
                    0.001,
              )
              .toList();
          final linesWithThisQty =
              (Sqflite.firstIntValue(
                await db.rawQuery(
                  '''
            SELECT COUNT(*) FROM document_items
            WHERE document_id = ? AND product_id = ? AND quantity = ?
          ''',
                  [docId, productId, qty],
                ),
              ) ??
              0);

          if (exactQtyMatches.length == 1 && linesWithThisQty == 1) {
            targetMovementId = exactQtyMatches.first['id'] as int;
          }
        }

        // Only update document_items IF a corresponding stock movement was successfully
        // and unambiguously reconciled. If stock was oversold or movement is ambiguous,
        // leave total_cost = NULL so the reporting layer treats the sale as untrusted.
        if (targetMovementId != null) {
          await db.update(
            'document_items',
            {
              'unit_cost': reconstructedUnitCost,
              'total_cost': qty * reconstructedUnitCost,
            },
            where: 'id = ? AND total_cost IS NULL',
            whereArgs: [itemId],
          );

          await db.rawUpdate(
            '''
            UPDATE stock_movements
            SET unit_cost = ?,
                total_cost = ABS(quantity) * ?,
                cost_status = '${StockMovement.costStatusReconstructed}',
                provenance = 'v17_invoice_repair'
            WHERE id = ?
              AND (cost_status = '${StockMovement.costStatusUnknown}' OR unit_cost IS NULL)
          ''',
            [reconstructedUnitCost, reconstructedUnitCost, targetMovementId],
          );

          repairedCount++;
        }
      }
      // If no dated basis found, leave total_cost = NULL (unknown — correct state).
    }

    // Audit log summary.
    try {
      await db.insert('audit_log', {
        'action': 'v17_costing_repair_complete',
        'entity_type': 'migration',
        'entity_id': null,
        'details':
            'Repaired $repairedCount of ${uncostedItems.length} item(s); '
            '${uncostedItems.length - repairedCount} remain unresolvable (unknown)',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
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
    return db.update(
      'businesses',
      b.toMap(),
      where: 'id = ?',
      whereArgs: [b.id],
    );
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
      await txn.update(
        'documents',
        {'contact_id': null},
        where: 'contact_id = ?',
        whereArgs: [id],
      );
      return txn.delete('contacts', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> setContactActive(int id, {required bool active}) async {
    final db = await database;
    await db.update(
      'contacts',
      {
        'active': active ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Contact>> getAllContacts({
    String? type,
    bool activeOnly = false,
  }) async {
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
    final maps = await db.query(
      'contacts',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name',
    );
    return maps.map((e) => Contact.fromMap(e)).toList();
  }

  Future<List<Contact>> searchContacts(
    String query, {
    String? type,
    bool activeOnly = false,
  }) async {
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
    final maps = await db.query(
      'contacts',
      where: where,
      whereArgs: args,
      orderBy: 'name',
      limit: 10,
    );
    return maps.map((e) => Contact.fromMap(e)).toList();
  }

  Future<Contact?> getContactById(int id) async {
    final db = await database;
    final maps = await db.query('contacts', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Contact.fromMap(maps.first);
  }

  Future<double> getContactOutstanding(
    int contactId,
    String docType, {
    String? currencyCode,
  }) async {
    final db = await database;
    final where = StringBuffer(
      "contact_id = ? AND type = ? AND status NOT IN ('${DocumentStatus.draft}', '${DocumentStatus.cancelled}')",
    );
    final args = <Object?>[contactId, docType];
    if (currencyCode != null) {
      where.write(' AND currency_code = ?');
      args.add(currencyCode);
    }
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(remaining), 0) AS outstanding
      FROM documents
      WHERE $where
    ''', args);
    return (rows.first['outstanding'] as num?)?.toDouble() ?? 0;
  }

  // ========== Products ==========
  Future<int> insertProduct(Product p) async {
    final db = await database;
    return db.transaction((txn) async {
      final hasKnownCost =
          p.isProduct && p.stockQuantity > 0 && p.purchasePrice > 0;
      final avgCost = hasKnownCost ? p.purchasePrice : null;
      final costStatus = hasKnownCost
          ? Product.costStatusKnown
          : Product.costStatusUnknown;

      final pMap = p.toMap();
      pMap['average_cost'] = avgCost;
      pMap['cost_status'] = costStatus;

      final id = await txn.insert('products', pMap);
      if (p.isProduct && p.stockQuantity > 0) {
        await _insertStockMovement(
          txn,
          productId: id,
          type: StockMovement.typeOpening,
          quantity: p.stockQuantity,
          unitCost: avgCost,
          totalCost: hasKnownCost ? p.stockQuantity * p.purchasePrice : null,
          costStatus: costStatus,
          provenance: 'opening_stock',
          date: p.createdAt ?? DateTime.now(),
        );
      }
      return id;
    });
  }

  Future<int> updateProduct(Product p) async {
    final db = await database;
    return db.transaction((txn) async {
      final existingRows = await txn.query(
        'products',
        columns: ['stock_quantity', 'type'],
        where: 'id = ?',
        whereArgs: [p.id],
      );
      if (existingRows.isNotEmpty) {
        final existingStock =
            (existingRows.first['stock_quantity'] as num?)?.toDouble() ?? 0;
        final existingType = existingRows.first['type'] as String? ?? 'product';
        if (existingType == 'product' &&
            p.type == 'service' &&
            existingStock > 0) {
          throw StateError(
            'Cannot convert product with active stock ($existingStock) to service',
          );
        }
      }
      final map = p.toMap();
      // Prevent direct modification of stock_quantity through product metadata update.
      map.remove('stock_quantity');
      // Never overwrite costing fields through a metadata edit.
      // average_cost and cost_status are managed exclusively by the costing
      // service (purchase receipts, stock adjustments, cost reconciliation).
      // Removing them from the update map preserves whatever the costing
      // service last wrote, even when the user changes the catalog
      // purchase_price in the product form.
      map.remove('average_cost');
      map.remove('cost_status');
      return txn.update('products', map, where: 'id = ?', whereArgs: [p.id]);
    });
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      final refRows = await txn.query(
        'document_items',
        columns: ['id'],
        where: 'product_id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (refRows.isNotEmpty) {
        throw StateError('Cannot delete product referenced in documents');
      }
      await txn.delete(
        'stock_movements',
        where: 'product_id = ?',
        whereArgs: [id],
      );
      return txn.delete('products', where: 'id = ?', whereArgs: [id]);
    });
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

  Future<List<Product>> getAllProducts({
    String? type,
    bool? activeOnly,
    String? category,
  }) async {
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
    if (category != null && category.trim().isNotEmpty) {
      conditions.add('category = ?');
      args.add(category.trim());
    }
    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    final maps = await db.query(
      'products',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name',
    );
    return maps.map((e) => Product.fromMap(e)).toList();
  }

  Future<List<Product>> searchProducts(
    String query, {
    int? limit,
    String? category,
  }) async {
    final db = await database;
    final conditions = <String>[
      '(name LIKE ? OR code LIKE ? OR barcode LIKE ?)',
    ];
    final args = <Object?>['%$query%', '%$query%', '%$query%'];
    if (category != null && category.trim().isNotEmpty) {
      conditions.add('category = ?');
      args.add(category.trim());
    }
    final maps = await db.query(
      'products',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'name',
      limit: limit,
    );
    return maps.map((e) => Product.fromMap(e)).toList();
  }

  Future<List<String>> getProductCategories() async {
    final db = await database;
    final results = await db.rawQuery(
      'SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND TRIM(category) != "" ORDER BY category',
    );
    return results.map((r) => r['category'] as String).toList();
  }

  Future<List<Product>> searchActiveProducts(
    String query, {
    int limit = 10,
  }) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: '(name LIKE ? OR code LIKE ? OR barcode LIKE ?) AND is_active = 1',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'name',
      limit: limit,
    );
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
    final maps = await db.query(
      'products',
      where: 'barcode = ? AND is_active = 1',
      whereArgs: [barcode],
      limit: 1,
    );
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
    final rows = await db.query(
      'products',
      columns: ['id'],
      where: where,
      whereArgs: args,
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> setProductActive(int id, {required bool active}) async {
    final db = await database;
    await db.update(
      'products',
      {'is_active': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== Stock Movements ==========
  Future<void> _insertStockMovement(
    DatabaseExecutor txn, {
    required int productId,
    required String type,
    required double quantity,
    int? referenceDocumentId,
    String? notes,
    double? unitCost,
    double? totalCost,
    String costStatus = StockMovement.costStatusUnknown,
    String? provenance,
    DateTime? date,
  }) async {
    await txn.insert('stock_movements', {
      'product_id': productId,
      'type': type,
      'quantity': quantity,
      'reference_document_id': referenceDocumentId,
      'date': (date ?? DateTime.now()).toIso8601String(),
      'notes': notes,
      'unit_cost': unitCost,
      'total_cost': totalCost,
      'cost_status': costStatus,
      'provenance': provenance,
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

  Future<List<StockMovement>> getAllStockMovements({
    int? productId,
    String? type,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <Object?>[];

    if (productId != null) {
      conditions.add('sm.product_id = ?');
      args.add(productId);
    }
    if (type != null && type.isNotEmpty && type != 'all') {
      conditions.add('sm.type = ?');
      args.add(type);
    }
    if (fromDate != null) {
      conditions.add('sm.date >= ?');
      args.add(fromDate.toIso8601String());
    }
    if (toDate != null) {
      conditions.add('sm.date <= ?');
      args.add(toDate.toIso8601String());
    }

    final whereClause = conditions.isNotEmpty
        ? 'WHERE ${conditions.join(' AND ')}'
        : '';

    final sql =
        '''
      SELECT sm.*, p.name AS product_name, p.unit AS product_unit
      FROM stock_movements sm
      LEFT JOIN products p ON sm.product_id = p.id
      $whereClause
      ORDER BY sm.date DESC, sm.id DESC
      LIMIT ? OFFSET ?
    ''';
    args.add(limit);
    args.add(offset);

    final maps = await db.rawQuery(sql, args);
    return maps.map(StockMovement.fromMap).toList();
  }

  Future<void> adjustStock({
    required int productId,
    required double delta, // positive = add, negative = remove
    String? notes,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await InventoryCostingService.onStockAdjusted(
        txn,
        productId: productId,
        delta: delta,
        notes: notes,
      );
    });
    await logAuditEvent(
      'stock_adjusted',
      entityType: 'product',
      entityId: productId,
      details: 'delta=$delta${notes != null ? " reason=$notes" : ""}',
    );
  }

  Future<void> reconcileProductCost({
    required int productId,
    required double newUnitCost,
    String? notes,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await InventoryCostingService.reconcileProductCost(
        txn,
        productId: productId,
        newUnitCost: newUnitCost,
        notes: notes,
      );
    });
  }

  // ========== Documents ==========
  /// Inserts [doc] with its [items] (stock and stock movements included).
  ///
  /// [payNowMethod]: for issued invoices only, records a full payment with
  /// this method (linked receipt + payment row) in the same transaction, so a
  /// quick sale is never left as an unpaid invoice if anything fails.
  Future<int> insertDocumentWithItems(
    Document doc,
    List<DocumentItem> items, {
    Contact? contact,
    String? payNowMethod,
    bool strictStock = true,
  }) async {
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
      if (doc.type == 'invoice' && !isDraft && strictStock) {
        for (final item in items) {
          if (item.productId == null || item.quantity <= 0) continue;
          final pRows = await txn.query(
            'products',
            columns: ['name', 'type', 'stock_quantity'],
            where: 'id = ?',
            whereArgs: [item.productId],
          );
          if (pRows.isNotEmpty &&
              (pRows.first['type'] as String? ?? 'product') == 'product') {
            final stock =
                (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0;
            if (stock < item.quantity) {
              final name = pRows.first['name'] as String? ?? '';
              throw StateError(
                'Insufficient stock for "$name": available ${FormatUtils.formatQuantity(stock)}, required ${FormatUtils.formatQuantity(item.quantity)}',
              );
            }
          }
        }
      }

      for (final item in items) {
        double? itemUnitCost;
        double? itemTotalCost;

        if (item.productId != null && item.quantity > 0) {
          if (doc.type == 'invoice' && !isDraft) {
            final pRows = await txn.query(
              'products',
              columns: [
                'type',
                'stock_quantity',
                'average_cost',
                'cost_status',
              ],
              where: 'id = ?',
              whereArgs: [item.productId],
            );
            if (pRows.isNotEmpty && pRows.first['type'] == 'product') {
              final currentStock =
                  (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0;
              final avgCost = (pRows.first['average_cost'] as num?)?.toDouble();
              final costStatus =
                  pRows.first['cost_status'] as String? ??
                  Product.costStatusUnknown;
              final isCostKnown =
                  costStatus == Product.costStatusKnown && avgCost != null;

              final double deductQty;
              if (strictStock) {
                deductQty = item.quantity;
              } else {
                deductQty = currentStock > 0
                    ? (currentStock >= item.quantity
                          ? item.quantity
                          : currentStock)
                    : 0.0;
              }
              final bool isFullyBacked = deductQty >= item.quantity;
              if (deductQty > 0) {
                // If stock was partially oversold, cost for the whole line is incomplete
                // and must NOT be marked as fully trusted on document_items.
                itemUnitCost = (isCostKnown && isFullyBacked) ? avgCost : null;
                itemTotalCost = (isCostKnown && isFullyBacked)
                    ? item.quantity * avgCost
                    : null;
                final movementCost = isCostKnown ? deductQty * avgCost : null;
                final movementCostStatus = (isCostKnown && isFullyBacked)
                    ? StockMovement.costStatusKnown
                    : StockMovement.costStatusUnknown;

                await txn.rawUpdate(
                  'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
                  [deductQty, item.productId],
                );
                await _insertStockMovement(
                  txn,
                  productId: item.productId!,
                  type: StockMovement.typeSale,
                  quantity: -deductQty,
                  unitCost: isCostKnown ? avgCost : null,
                  totalCost: movementCost,
                  costStatus: movementCostStatus,
                  provenance: isFullyBacked
                      ? 'sales_invoice'
                      : 'sales_invoice_partial',
                  referenceDocumentId: docId,
                  date: doc.date,
                );
              }
            }
          } else if (doc.type == 'purchase' && !isDraft) {
            final pRows = await txn.query(
              'products',
              columns: [
                'type',
                'stock_quantity',
                'average_cost',
                'cost_status',
              ],
              where: 'id = ?',
              whereArgs: [item.productId],
            );
            if (pRows.isNotEmpty && pRows.first['type'] == 'product') {
              final currentStock =
                  (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0.0;
              final currentAvg = (pRows.first['average_cost'] as num?)
                  ?.toDouble();
              final priorCostStatus =
                  pRows.first['cost_status'] as String? ??
                  Product.costStatusUnknown;

              final incomingQty = item.quantity;
              final incomingUnitCost = item.price;
              itemUnitCost = incomingUnitCost;
              itemTotalCost = incomingQty * incomingUnitCost;

              final double newAvgCost;
              final String newCostStatus;
              if (priorCostStatus == Product.costStatusKnown ||
                  currentStock <= 0) {
                newAvgCost =
                    InventoryCostingService.calculateNewWeightedAverage(
                      currentStock: currentStock,
                      currentAvgCost: currentAvg,
                      incomingQty: incomingQty,
                      incomingUnitCost: incomingUnitCost,
                    );
                newCostStatus = Product.costStatusKnown;
              } else {
                newAvgCost = incomingUnitCost;
                newCostStatus = Product.costStatusUnknown;
              }

              await txn.update(
                'products',
                {
                  'stock_quantity': currentStock + incomingQty,
                  'average_cost': newAvgCost,
                  'cost_status': newCostStatus,
                },
                where: 'id = ?',
                whereArgs: [item.productId],
              );

              await _insertStockMovement(
                txn,
                productId: item.productId!,
                type: StockMovement.typePurchase,
                quantity: incomingQty,
                unitCost: incomingUnitCost,
                totalCost: itemTotalCost,
                costStatus: StockMovement.costStatusKnown,
                provenance: 'purchase_document',
                referenceDocumentId: docId,
                date: doc.date,
              );
            }
          }
        }

        await txn.insert('document_items', {
          'document_id': docId,
          'product_id': item.productId,
          'description': item.description,
          'quantity': item.quantity,
          'price': item.price,
          'total': item.total,
          'taxable': item.taxable ? 1 : 0,
          'tax_rate': item.taxRate,
          'unit_cost': itemUnitCost,
          'total_cost': itemTotalCost,
        });
      }

      if (payNowMethod != null) {
        if (doc.type != 'invoice' || isDraft || doc.paid != 0) {
          throw ArgumentError(
            'payNowMethod requires an issued, unpaid invoice',
          );
        }
        if (doc.total > 0) {
          await _recordPaymentTxn(
            txn,
            documentId: docId,
            amount: doc.total,
            paymentMethod: payNowMethod,
          );
        }
      } else if (!isDraft &&
          (doc.type == 'invoice' || doc.type == 'purchase') &&
          doc.paid > 0) {
        // Record upfront down payment on invoice/purchase creation
        await txn.insert('document_payments', {
          'document_id': docId,
          'amount': doc.paid,
          'payment_method': doc.paymentMethod,
          'date': doc.date.toIso8601String(),
          'notes': doc.type == 'invoice'
              ? 'Initial payment'
              : 'Initial purchase payment',
          'receipt_document_id': null,
        });
      }

      return docId;
    });
  }

  Future<void> updateDocumentWithItems(
    Document doc,
    List<DocumentItem> newItems, {
    Contact? contact,
    bool strictStock = true,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      int? contactId = doc.contactId;
      if (contact != null) {
        contactId = contact.id ?? await txn.insert('contacts', contact.toMap());
      }

      final oldItems = await txn.query(
        'document_items',
        where: 'document_id = ?',
        whereArgs: [doc.id],
      );
      final existingRows = await txn.query(
        'documents',
        columns: ['type', 'status'],
        where: 'id = ?',
        whereArgs: [doc.id],
      );
      if (existingRows.isEmpty) throw StateError('Document not found');

      final oldType = existingRows.first['type'] as String;
      final oldStatus =
          existingRows.first['status'] as String? ?? DocumentStatus.issued;

      final newIsDraft = doc.status == DocumentStatus.draft;

      final affectsStock =
          (oldType == 'invoice' || oldType == 'purchase') &&
          oldStatus != DocumentStatus.draft &&
          oldStatus != DocumentStatus.cancelled;
      if (affectsStock) {
        if (oldType == 'invoice') {
          final oldMovements = await txn.query(
            'stock_movements',
            where: 'reference_document_id = ? AND type = ?',
            whereArgs: [doc.id, StockMovement.typeSale],
          );
          if (oldMovements.isNotEmpty) {
            for (final m in oldMovements) {
              final productId = m['product_id'] as int;
              final mQty = (m['quantity'] as num).toDouble();
              final revertQty = -mQty;
              if (revertQty > 0) {
                final unitCost = (m['unit_cost'] as num?)?.toDouble();
                final totalCost = (m['total_cost'] as num?)?.toDouble();
                final costStatus =
                    m['cost_status'] as String? ??
                    StockMovement.costStatusUnknown;

                await txn.rawUpdate(
                  'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
                  [revertQty, productId],
                );
                await _insertStockMovement(
                  txn,
                  productId: productId,
                  type: StockMovement.typeCancellation,
                  quantity: revertQty,
                  unitCost: unitCost,
                  totalCost: totalCost,
                  costStatus: costStatus,
                  provenance: 'sale_reversal',
                  referenceDocumentId: doc.id,
                );
              }
            }
          } else {
            for (final old in oldItems) {
              final productId = old['product_id'] as int?;
              final qty = (old['quantity'] as num?)?.toDouble() ?? 0;
              if (productId == null || qty <= 0) continue;
              final pRows = await txn.query(
                'products',
                columns: ['type'],
                where: 'id = ?',
                whereArgs: [productId],
              );
              if (pRows.isEmpty || pRows.first['type'] != 'product') continue;
              await txn.rawUpdate(
                'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
                [qty, productId],
              );
              await _insertStockMovement(
                txn,
                productId: productId,
                type: StockMovement.typeCancellation,
                quantity: qty,
                provenance: 'sale_reversal',
                referenceDocumentId: doc.id,
              );
            }
          }
        } else if (oldType == 'purchase') {
          // Pre-check: if reducing purchased quantity for any product, verify that
          // the product currently has sufficient stock and that the stock was not
          // already sold or consumed.
          final oldProductQuantities = <int, double>{};
          for (final old in oldItems) {
            final pid = old['product_id'] as int?;
            final qty = (old['quantity'] as num?)?.toDouble() ?? 0;
            if (pid != null && qty > 0) {
              oldProductQuantities[pid] =
                  (oldProductQuantities[pid] ?? 0.0) + qty;
            }
          }

          final newProductQuantities = <int, double>{};
          if (doc.type == 'purchase' && !newIsDraft) {
            for (final newItem in newItems) {
              final pid = newItem.productId;
              final qty = newItem.quantity;
              if (pid != null && qty > 0) {
                newProductQuantities[pid] =
                    (newProductQuantities[pid] ?? 0.0) + qty;
              }
            }
          }

          for (final entry in oldProductQuantities.entries) {
            final pid = entry.key;
            final oldQty = entry.value;
            final newQty = newProductQuantities[pid] ?? 0.0;
            if (oldQty > newQty) {
              final netReduction = oldQty - newQty;
              final pRows = await txn.query(
                'products',
                columns: ['name', 'type', 'stock_quantity'],
                where: 'id = ?',
                whereArgs: [pid],
              );
              if (pRows.isNotEmpty &&
                  (pRows.first['type'] as String? ?? 'product') == 'product') {
                final stock =
                    (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0.0;
                if (stock < netReduction) {
                  final name = pRows.first['name'] as String? ?? '';
                  throw StateError(
                    'Insufficient stock to edit purchase for "$name": available ${FormatUtils.formatQuantity(stock)}, required reduction ${FormatUtils.formatQuantity(netReduction)}',
                  );
                }
              }
            }
          }

          for (final old in oldItems) {
            final productId = old['product_id'] as int?;
            final qty = (old['quantity'] as num?)?.toDouble() ?? 0;
            if (productId == null || qty <= 0) continue;
            final pRows = await txn.query(
              'products',
              columns: [
                'type',
                'stock_quantity',
                'average_cost',
                'cost_status',
              ],
              where: 'id = ?',
              whereArgs: [productId],
            );
            if (pRows.isEmpty || pRows.first['type'] != 'product') continue;

            final origMovements = await txn.query(
              'stock_movements',
              where:
                  'reference_document_id = ? AND product_id = ? AND type = ?',
              whereArgs: [doc.id, productId, StockMovement.typePurchase],
            );
            final origUnitCost = origMovements.isNotEmpty
                ? (origMovements.first['unit_cost'] as num?)?.toDouble()
                : (old['price'] as num?)?.toDouble();
            final origCostStatus = origMovements.isNotEmpty
                ? (origMovements.first['cost_status'] as String? ??
                      StockMovement.costStatusKnown)
                : StockMovement.costStatusKnown;

            final currentStock =
                (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0.0;
            final currentAvg = (pRows.first['average_cost'] as num?)
                ?.toDouble();
            final newStock = currentStock - qty;

            double? newAvgCost = currentAvg;
            String newCostStatus =
                pRows.first['cost_status'] as String? ??
                Product.costStatusUnknown;
            if (newStock <= 0) {
              newAvgCost = null;
              newCostStatus = Product.costStatusUnknown;
            } else if (currentAvg != null && origUnitCost != null) {
              final prevVal = currentStock * currentAvg;
              final removedVal = qty * origUnitCost;
              final remainVal = (prevVal - removedVal).clamp(
                0.0,
                double.infinity,
              );
              newAvgCost = remainVal / newStock;
            }

            await txn.update(
              'products',
              {
                'stock_quantity': newStock,
                'average_cost': newAvgCost,
                'cost_status': newCostStatus,
              },
              where: 'id = ?',
              whereArgs: [productId],
            );

            await _insertStockMovement(
              txn,
              productId: productId,
              type: StockMovement.typeCancellation,
              quantity: -qty,
              unitCost: origUnitCost,
              totalCost: origUnitCost != null ? -qty * origUnitCost : null,
              costStatus: origCostStatus,
              provenance: 'purchase_reversal',
              referenceDocumentId: doc.id,
            );
          }
        }
      }

      await txn.update(
        'documents',
        {
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
        },
        where: 'id = ?',
        whereArgs: [doc.id],
      );

      await txn.delete(
        'document_items',
        where: 'document_id = ?',
        whereArgs: [doc.id],
      );

      // Pre-check stock availability for non-draft invoices
      if (doc.type == 'invoice' && !newIsDraft && strictStock) {
        for (final item in newItems) {
          if (item.productId == null || item.quantity <= 0) continue;
          final pRows = await txn.query(
            'products',
            columns: ['name', 'type', 'stock_quantity'],
            where: 'id = ?',
            whereArgs: [item.productId],
          );
          if (pRows.isNotEmpty &&
              (pRows.first['type'] as String? ?? 'product') == 'product') {
            final stock =
                (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0;
            if (stock < item.quantity) {
              final name = pRows.first['name'] as String? ?? '';
              throw StateError(
                'Insufficient stock for "$name": available ${FormatUtils.formatQuantity(stock)}, required ${FormatUtils.formatQuantity(item.quantity)}',
              );
            }
          }
        }
      }

      for (final item in newItems) {
        double? itemUnitCost;
        double? itemTotalCost;

        if (item.productId != null && item.quantity > 0) {
          if (doc.type == 'invoice' && !newIsDraft) {
            final pRows = await txn.query(
              'products',
              columns: [
                'type',
                'stock_quantity',
                'average_cost',
                'cost_status',
              ],
              where: 'id = ?',
              whereArgs: [item.productId],
            );
            if (pRows.isNotEmpty && pRows.first['type'] == 'product') {
              final currentStock =
                  (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0;
              final avgCost = (pRows.first['average_cost'] as num?)?.toDouble();
              final costStatus =
                  pRows.first['cost_status'] as String? ??
                  Product.costStatusUnknown;
              final isCostKnown =
                  costStatus == Product.costStatusKnown && avgCost != null;

              final double deductQty;
              if (strictStock) {
                deductQty = item.quantity;
              } else {
                deductQty = currentStock > 0
                    ? (currentStock >= item.quantity
                          ? item.quantity
                          : currentStock)
                    : 0.0;
              }
              final bool isFullyBacked = deductQty >= item.quantity;
              if (deductQty > 0) {
                // If stock was partially oversold, cost for the whole line is incomplete
                // and must NOT be marked as fully trusted on document_items.
                itemUnitCost = (isCostKnown && isFullyBacked) ? avgCost : null;
                itemTotalCost = (isCostKnown && isFullyBacked)
                    ? item.quantity * avgCost
                    : null;
                final movementCost = isCostKnown ? deductQty * avgCost : null;
                final movementCostStatus = (isCostKnown && isFullyBacked)
                    ? StockMovement.costStatusKnown
                    : StockMovement.costStatusUnknown;

                await txn.rawUpdate(
                  'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
                  [deductQty, item.productId],
                );
                await _insertStockMovement(
                  txn,
                  productId: item.productId!,
                  type: StockMovement.typeSale,
                  quantity: -deductQty,
                  unitCost: isCostKnown ? avgCost : null,
                  totalCost: movementCost,
                  costStatus: movementCostStatus,
                  provenance: isFullyBacked
                      ? 'sales_invoice'
                      : 'sales_invoice_partial',
                  referenceDocumentId: doc.id,
                  date: doc.date,
                );
              }
            }
          } else if (doc.type == 'purchase' && !newIsDraft) {
            final pRows = await txn.query(
              'products',
              columns: [
                'type',
                'stock_quantity',
                'average_cost',
                'cost_status',
              ],
              where: 'id = ?',
              whereArgs: [item.productId],
            );
            if (pRows.isNotEmpty && pRows.first['type'] == 'product') {
              final currentStock =
                  (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0.0;
              final currentAvg = (pRows.first['average_cost'] as num?)
                  ?.toDouble();
              final priorCostStatus =
                  pRows.first['cost_status'] as String? ??
                  Product.costStatusUnknown;

              final incomingQty = item.quantity;
              final incomingUnitCost = item.price;
              itemUnitCost = incomingUnitCost;
              itemTotalCost = incomingQty * incomingUnitCost;

              final double newAvgCost;
              final String newCostStatus;
              if (priorCostStatus == Product.costStatusKnown ||
                  currentStock <= 0) {
                newAvgCost =
                    InventoryCostingService.calculateNewWeightedAverage(
                      currentStock: currentStock,
                      currentAvgCost: currentAvg,
                      incomingQty: incomingQty,
                      incomingUnitCost: incomingUnitCost,
                    );
                newCostStatus = Product.costStatusKnown;
              } else {
                newAvgCost = incomingUnitCost;
                newCostStatus = Product.costStatusUnknown;
              }

              await txn.update(
                'products',
                {
                  'stock_quantity': currentStock + incomingQty,
                  'average_cost': newAvgCost,
                  'cost_status': newCostStatus,
                },
                where: 'id = ?',
                whereArgs: [item.productId],
              );

              await _insertStockMovement(
                txn,
                productId: item.productId!,
                type: StockMovement.typePurchase,
                quantity: incomingQty,
                unitCost: incomingUnitCost,
                totalCost: itemTotalCost,
                costStatus: StockMovement.costStatusKnown,
                provenance: 'purchase_document',
                referenceDocumentId: doc.id,
                date: doc.date,
              );
            }
          }
        }

        await txn.insert('document_items', {
          'document_id': doc.id,
          'product_id': item.productId,
          'description': item.description,
          'quantity': item.quantity,
          'price': item.price,
          'total': item.total,
          'taxable': item.taxable ? 1 : 0,
          'tax_rate': item.taxRate,
          'unit_cost': itemUnitCost,
          'total_cost': itemTotalCost,
        });
      }
    });
  }

  Future<int> deleteDocument(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      final docRows = await txn.query(
        'documents',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (docRows.isEmpty) return 0;
      final doc = Document.fromMap(docRows.first);

      // Payment receipts & expense vouchers: reverse the linked payment from the parent
      // invoice/purchase and recalculate its paid/status.
      // For all other document types: just null out any stray receipt references
      // so the receipt_document_id FK (which has no cascade) never blocks deletion.
      if (doc.type == 'payment_receipt' || doc.type == 'expense_voucher') {
        if (doc.status != DocumentStatus.cancelled) {
          final paymentRows = await txn.query(
            'document_payments',
            where: 'receipt_document_id = ?',
            whereArgs: [id],
          );
          final pTotal = paymentRows.fold<double>(
            0.0,
            (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0.0),
          );
          final amountToReverse = pTotal > 0 ? pTotal : doc.total;

          await txn.delete(
            'document_payments',
            where: 'receipt_document_id = ?',
            whereArgs: [id],
          );

          if (doc.relatedDocumentId != null) {
            final parentRows = await txn.query(
              'documents',
              where: 'id = ?',
              whereArgs: [doc.relatedDocumentId],
            );
            if (parentRows.isNotEmpty) {
              final parent = Document.fromMap(parentRows.first);
              if (parent.status != DocumentStatus.cancelled) {
                final newPaid = (parent.paid - amountToReverse).clamp(
                  0.0,
                  parent.total,
                );
                final newRemaining = (parent.total - newPaid).clamp(
                  0.0,
                  double.infinity,
                );
                final newStatus = DocumentStatus.fromPayment(
                  newPaid,
                  parent.total,
                );
                await txn.update(
                  'documents',
                  {
                    'paid': newPaid,
                    'remaining': newRemaining,
                    'status': newStatus,
                  },
                  where: 'id = ?',
                  whereArgs: [doc.relatedDocumentId],
                );
              }
            }
          }
        } else {
          // If the voucher was ALREADY cancelled, its payment row and parent paid
          // amount were already reversed during cancelDocument.
          // Clean up any remaining payment row without deducting again.
          await txn.delete(
            'document_payments',
            where: 'receipt_document_id = ?',
            whereArgs: [id],
          );
        }
      } else {
        // Non-voucher document may still be referenced by a payment row's
        // receipt_document_id (no ON DELETE cascade on that column).
        await txn.rawUpdate(
          'UPDATE document_payments SET receipt_document_id = NULL WHERE receipt_document_id = ?',
          [id],
        );
      }

      // Stock reversion for non-draft, non-cancelled invoices and purchases
      final needsStockReversal =
          (doc.type == 'invoice' || doc.type == 'purchase') &&
          doc.status != DocumentStatus.draft &&
          doc.status != DocumentStatus.cancelled;
      if (needsStockReversal) {
        final movements = await txn.query(
          'stock_movements',
          where: 'reference_document_id = ?',
          whereArgs: [id],
        );
        if (doc.type == 'purchase') {
          final netPurchaseQtyByProduct = <int, double>{};
          for (final m in movements) {
            final productId = m['product_id'] as int;
            final mType = m['type'] as String;
            final mQty = (m['quantity'] as num).toDouble();
            if (mType == StockMovement.typePurchase) {
              netPurchaseQtyByProduct[productId] =
                  (netPurchaseQtyByProduct[productId] ?? 0.0) + mQty;
            } else if (mType == StockMovement.typeCancellation && mQty < 0) {
              netPurchaseQtyByProduct[productId] =
                  (netPurchaseQtyByProduct[productId] ?? 0.0) + mQty;
            }
          }
          for (final entry in netPurchaseQtyByProduct.entries) {
            final productId = entry.key;
            final netQty = entry.value;
            if (netQty <= 0) continue;
            final pRows = await txn.query(
              'products',
              columns: ['name', 'type', 'stock_quantity'],
              where: 'id = ?',
              whereArgs: [productId],
            );
            if (pRows.isNotEmpty &&
                (pRows.first['type'] as String? ?? 'product') == 'product') {
              final stock =
                  (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0;
              if (stock < netQty) {
                final name = pRows.first['name'] as String? ?? '';
                throw StateError(
                  'Insufficient stock to reverse purchase for "$name": available ${FormatUtils.formatQuantity(stock)}, required ${FormatUtils.formatQuantity(netQty)}',
                );
              }
            }
          }
        }
        if (movements.isNotEmpty) {
          for (final m in movements) {
            final productId = m['product_id'] as int;
            final mType = m['type'] as String;
            final mQty = (m['quantity'] as num).toDouble();
            if (mType == StockMovement.typeSale) {
              await txn.rawUpdate(
                'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
                [-mQty, productId],
              );
            } else if (mType == StockMovement.typePurchase) {
              await txn.rawUpdate(
                'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
                [mQty, productId],
              );
            } else if (mType == StockMovement.typeCancellation &&
                doc.type == 'purchase') {
              await txn.rawUpdate(
                'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
                [mQty, productId],
              );
            }
          }
        } else {
          final items = await txn.query(
            'document_items',
            where: 'document_id = ?',
            whereArgs: [id],
          );
          if (doc.type == 'purchase') {
            for (final item in items) {
              final productId = item['product_id'] as int?;
              final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
              if (productId == null || qty <= 0) continue;
              final pRows = await txn.query(
                'products',
                columns: ['name', 'type', 'stock_quantity'],
                where: 'id = ?',
                whereArgs: [productId],
              );
              if (pRows.isNotEmpty &&
                  (pRows.first['type'] as String? ?? 'product') == 'product') {
                final stock =
                    (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0;
                if (stock < qty) {
                  final name = pRows.first['name'] as String? ?? '';
                  throw StateError(
                    'Insufficient stock to reverse purchase for "$name": available ${FormatUtils.formatQuantity(stock)}, required ${FormatUtils.formatQuantity(qty)}',
                  );
                }
              }
            }
          }
          for (final item in items) {
            final productId = item['product_id'] as int?;
            final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
            if (productId == null || qty <= 0) continue;
            final pRows = await txn.query(
              'products',
              columns: ['type'],
              where: 'id = ?',
              whereArgs: [productId],
            );
            if (pRows.isEmpty || pRows.first['type'] != 'product') continue;
            if (doc.type == 'invoice') {
              await txn.rawUpdate(
                'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
                [qty, productId],
              );
            } else if (doc.type == 'purchase') {
              await txn.rawUpdate(
                'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
                [qty, productId],
              );
            }
          }
        }
      }

      // Remove only the stock movements belonging to this deleted document
      // so no orphaned movements with reference_document_id = NULL remain.
      await txn.delete(
        'stock_movements',
        where: 'reference_document_id = ?',
        whereArgs: [id],
      );

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
      final docRows = await txn.query(
        'documents',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (docRows.isEmpty) return;
      final doc = Document.fromMap(docRows.first);

      if (doc.status == DocumentStatus.cancelled) {
        throw StateError('Document is already cancelled');
      }

      // Payment receipts & expense vouchers: also reverse the linked invoice/purchase payment
      if ((doc.type == 'payment_receipt' || doc.type == 'expense_voucher') &&
          doc.relatedDocumentId != null) {
        await _reverseReceiptPayment(txn, id, doc.relatedDocumentId!);
        return;
      }

      final affectsStock =
          (doc.type == 'invoice' || doc.type == 'purchase') &&
          doc.status != DocumentStatus.draft;
      if (affectsStock) {
        final items = await txn.query(
          'document_items',
          where: 'document_id = ?',
          whereArgs: [id],
        );

        // Guard against cancelling a purchase whose stock has already been consumed
        if (doc.type == 'purchase') {
          for (final item in items) {
            final productId = item['product_id'] as int?;
            final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
            if (productId == null || qty <= 0) continue;
            final pRows = await txn.query(
              'products',
              columns: ['name', 'type', 'stock_quantity'],
              where: 'id = ?',
              whereArgs: [productId],
            );
            if (pRows.isNotEmpty &&
                (pRows.first['type'] as String? ?? 'product') == 'product') {
              final stock =
                  (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0;
              if (stock < qty) {
                final name = pRows.first['name'] as String? ?? '';
                throw StateError(
                  'Insufficient stock to cancel purchase for "$name": available ${FormatUtils.formatQuantity(stock)}, required ${FormatUtils.formatQuantity(qty)}',
                );
              }
            }
          }
        }

        for (final item in items) {
          final productId = item['product_id'] as int?;
          final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
          if (productId == null || qty <= 0) continue;
          final pRows = await txn.query(
            'products',
            columns: ['type', 'stock_quantity', 'average_cost', 'cost_status'],
            where: 'id = ?',
            whereArgs: [productId],
          );
          if (pRows.isEmpty || pRows.first['type'] != 'product') continue;
          if (doc.type == 'invoice') {
            final mRows = await txn.query(
              'stock_movements',
              where:
                  'reference_document_id = ? AND product_id = ? AND type = ?',
              whereArgs: [id, productId, StockMovement.typeSale],
            );
            final double revertQty;
            double? unitCost;
            double? totalCost;
            String costStatus = StockMovement.costStatusUnknown;
            if (mRows.isNotEmpty) {
              revertQty = -(mRows.first['quantity'] as num).toDouble();
              unitCost = (mRows.first['unit_cost'] as num?)?.toDouble();
              totalCost = (mRows.first['total_cost'] as num?)?.toDouble();
              costStatus =
                  mRows.first['cost_status'] as String? ??
                  StockMovement.costStatusUnknown;
            } else {
              revertQty = qty;
            }
            if (revertQty > 0) {
              await txn.rawUpdate(
                'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
                [revertQty, productId],
              );
              await _insertStockMovement(
                txn,
                productId: productId,
                type: StockMovement.typeCancellation,
                quantity: revertQty,
                unitCost: unitCost,
                totalCost: totalCost,
                costStatus: costStatus,
                provenance: 'sale_cancellation',
                referenceDocumentId: id,
              );
            }
          } else if (doc.type == 'purchase') {
            final mRows = await txn.query(
              'stock_movements',
              where:
                  'reference_document_id = ? AND product_id = ? AND type = ?',
              whereArgs: [id, productId, StockMovement.typePurchase],
            );
            final unitCost = mRows.isNotEmpty
                ? (mRows.first['unit_cost'] as num?)?.toDouble()
                : (item['price'] as num?)?.toDouble();
            final costStatus = mRows.isNotEmpty
                ? (mRows.first['cost_status'] as String? ??
                      StockMovement.costStatusKnown)
                : StockMovement.costStatusKnown;

            final currentStock =
                (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0.0;
            final currentAvg = (pRows.first['average_cost'] as num?)
                ?.toDouble();
            final newStock = currentStock - qty;

            double? newAvgCost = currentAvg;
            String newCostStatus =
                pRows.first['cost_status'] as String? ??
                Product.costStatusUnknown;
            if (newStock <= 0) {
              newAvgCost = null;
              newCostStatus = Product.costStatusUnknown;
            } else if (currentAvg != null && unitCost != null) {
              final prevVal = currentStock * currentAvg;
              final removedVal = qty * unitCost;
              final remainVal = (prevVal - removedVal).clamp(
                0.0,
                double.infinity,
              );
              newAvgCost = remainVal / newStock;
            }

            await txn.update(
              'products',
              {
                'stock_quantity': newStock,
                'average_cost': newAvgCost,
                'cost_status': newCostStatus,
              },
              where: 'id = ?',
              whereArgs: [productId],
            );
            await _insertStockMovement(
              txn,
              productId: productId,
              type: StockMovement.typeCancellation,
              quantity: -qty,
              unitCost: unitCost,
              totalCost: unitCost != null ? -qty * unitCost : null,
              costStatus: costStatus,
              provenance: 'purchase_cancellation',
              referenceDocumentId: id,
            );
          }
        }
      }

      await txn.update(
        'documents',
        {'status': DocumentStatus.cancelled},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> _reverseReceiptPayment(
    DatabaseExecutor txn,
    int receiptId,
    int invoiceId,
  ) async {
    final paymentRows = await txn.query(
      'document_payments',
      where: 'receipt_document_id = ?',
      whereArgs: [receiptId],
    );
    final pTotal = paymentRows.fold<double>(
      0.0,
      (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0.0),
    );

    // Delete the payment row linked to this receipt/voucher
    await txn.delete(
      'document_payments',
      where: 'receipt_document_id = ?',
      whereArgs: [receiptId],
    );

    // Recalculate parent invoice/purchase without destroying upfront payments
    final invoiceRows = await txn.query(
      'documents',
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
    if (invoiceRows.isNotEmpty) {
      final invoice = Document.fromMap(invoiceRows.first);
      if (invoice.status != DocumentStatus.cancelled) {
        final receiptRows = await txn.query(
          'documents',
          columns: ['total'],
          where: 'id = ?',
          whereArgs: [receiptId],
        );
        final receiptTotal = receiptRows.isNotEmpty
            ? ((receiptRows.first['total'] as num?)?.toDouble() ?? 0.0)
            : 0.0;
        final decimalDigits = Currency.decimalDigitsForCode(invoice.currencyCode);
        final amountToReverse = pTotal > 0 ? pTotal : receiptTotal;
        final canonicalReverse = MoneyUtils.round(amountToReverse, decimalDigits);

        final newPaid = math.max(
          0.0,
          MoneyUtils.round(invoice.paid - canonicalReverse, decimalDigits),
        );
        final newRemaining = MoneyUtils.calculateRemaining(
          invoice.total,
          newPaid,
          decimalDigits,
        );
        final newStatus = DocumentStatus.fromPayment(
          newPaid,
          invoice.total,
          decimalDigits: decimalDigits,
        );
        await txn.update(
          'documents',
          {'paid': newPaid, 'remaining': newRemaining, 'status': newStatus},
          where: 'id = ?',
          whereArgs: [invoiceId],
        );
      }
    }

    // Cancel the receipt/voucher document
    await txn.update(
      'documents',
      {'status': DocumentStatus.cancelled},
      where: 'id = ?',
      whereArgs: [receiptId],
    );
  }

  Future<void> recordPayment({
    required int documentId,
    required double amount,
    String? paymentMethod,
    String? notes,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final docRows = await txn.query(
        'documents',
        where: 'id = ?',
        whereArgs: [documentId],
      );
      if (docRows.isEmpty) throw StateError('Document not found');
      final doc = Document.fromMap(docRows.first);

      if (doc.type != 'invoice' && doc.type != 'purchase') {
        throw StateError(
          'Payment recording is only supported for invoices and purchases',
        );
      }
      if (doc.status == DocumentStatus.cancelled) {
        throw StateError('Cannot record payment on a cancelled document');
      }
      if (doc.status == DocumentStatus.draft) {
        throw StateError('Cannot record payment on a draft document');
      }
      if (amount <= 0) {
        throw ArgumentError('Payment amount must be greater than zero');
      }
      if (amount > doc.remaining) {
        throw ArgumentError('Payment cannot exceed remaining amount');
      }

      await txn.insert('document_payments', {
        'document_id': documentId,
        'amount': amount,
        'payment_method': paymentMethod,
        'date': DateTime.now().toIso8601String(),
        'notes': notes,
      });

      final newPaid = doc.paid + amount;
      final newRemaining = (doc.total - newPaid).clamp(0.0, double.infinity);
      final newStatus = DocumentStatus.fromPayment(newPaid, doc.total);

      await txn.update(
        'documents',
        {'paid': newPaid, 'remaining': newRemaining, 'status': newStatus},
        where: 'id = ?',
        whereArgs: [documentId],
      );
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
    final receiptId = await db.transaction(
      (txn) => _recordPaymentTxn(
        txn,
        documentId: documentId,
        amount: amount,
        paymentMethod: paymentMethod,
        notes: notes,
      ),
    );
    await logAuditEvent(
      'payment_recorded',
      entityType: 'document',
      entityId: documentId,
      details: 'amount=$amount method=$paymentMethod',
    );
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
    final docRows = await txn.query(
      'documents',
      where: 'id = ?',
      whereArgs: [documentId],
    );
    if (docRows.isEmpty) throw StateError('Document not found');
    final doc = Document.fromMap(docRows.first);

    if (doc.type != 'invoice' && doc.type != 'purchase') {
      throw StateError(
        'Payment recording is only supported for invoices and purchases',
      );
    }
    if (doc.status == DocumentStatus.cancelled) {
      throw StateError('Cannot record payment on a cancelled document');
    }
    if (doc.status == DocumentStatus.draft) {
      throw StateError('Cannot record payment on a draft document');
    }
    if (doc.status == DocumentStatus.paid) {
      throw StateError('Document is already fully paid');
    }
    final decimalDigits = Currency.decimalDigitsForCode(doc.currencyCode);
    final canonicalAmount = MoneyUtils.round(amount, decimalDigits);

    if (canonicalAmount <= 0) {
      throw ArgumentError('Payment amount must be greater than zero');
    }
    if (MoneyUtils.isOverpayment(canonicalAmount, doc.remaining, decimalDigits)) {
      throw ArgumentError('Payment cannot exceed remaining amount');
    }

    // Create the linked voucher document (payment_receipt for invoices, expense_voucher for purchases)
    final linkedType = doc.type == 'purchase'
        ? 'expense_voucher'
        : 'payment_receipt';
    final linkedNumber = await getNextDocumentNumber(txn, linkedType);
    final now = DateTime.now();
    final receiptId = await txn.insert('documents', {
      'type': linkedType,
      'document_number': linkedNumber,
      'date': now.toIso8601String(),
      'contact_id': doc.contactId,
      'recipient_name': doc.recipientName,
      'recipient_phone': doc.recipientPhone,
      'subtotal': canonicalAmount,
      'discount': 0.0,
      'tax_rate': 0.0,
      'tax_amount': 0.0,
      'total': canonicalAmount,
      'paid': canonicalAmount,
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
      'amount': canonicalAmount,
      'payment_method': paymentMethod,
      'date': now.toIso8601String(),
      'notes': notes,
      'receipt_document_id': receiptId,
    });

    // Update invoice totals
    final newPaid = MoneyUtils.round(doc.paid + canonicalAmount, decimalDigits);
    final newRemaining = MoneyUtils.calculateRemaining(doc.total, newPaid, decimalDigits);
    final newStatus = DocumentStatus.fromPayment(newPaid, doc.total, decimalDigits: decimalDigits);

    await txn.update(
      'documents',
      {'paid': newPaid, 'remaining': newRemaining, 'status': newStatus},
      where: 'id = ?',
      whereArgs: [documentId],
    );

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
    })
  >
  getLedgerData() async {
    final db = await database;
    return db.transaction((txn) async {
      final docs = await txn.query('documents', orderBy: 'date ASC, id ASC');
      final items = await txn.query('document_items');
      final products = await txn.query('products');
      final movements = await txn.query(
        'stock_movements',
        orderBy: 'date ASC, id ASC',
      );
      final payments = await txn.query(
        'document_payments',
        orderBy: 'date ASC, id ASC',
      );
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
      final qRows = await txn.query(
        'documents',
        where: 'id = ?',
        whereArgs: [quotationId],
      );
      if (qRows.isEmpty) throw StateError('Quotation not found');
      final quotation = Document.fromMap(qRows.first);

      if (quotation.type != 'quotation') {
        throw ArgumentError('Document is not a quotation');
      }
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
      final qItems = await txn.query(
        'document_items',
        where: 'document_id = ?',
        whereArgs: [quotationId],
      );
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
  Future<void> issueDocument(int id, {bool strictStock = true}) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'documents',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) throw StateError('Document not found');
      final doc = Document.fromMap(rows.first);

      if (doc.status != DocumentStatus.draft) {
        throw StateError('Document is not a draft');
      }

      final items = await txn.query(
        'document_items',
        where: 'document_id = ?',
        whereArgs: [id],
      );

      if (doc.type == 'invoice') {
        if (strictStock) {
          // Validate stock availability first
          for (final item in items) {
            final productId = item['product_id'] as int?;
            final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
            if (productId == null || qty <= 0) continue;
            final pRows = await txn.query(
              'products',
              columns: ['name', 'type', 'stock_quantity'],
              where: 'id = ?',
              whereArgs: [productId],
            );
            if (pRows.isNotEmpty && pRows.first['type'] == 'product') {
              final stock =
                  (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0;
              if (stock < qty) {
                final name = pRows.first['name'] as String? ?? '';
                throw StateError(
                  'Insufficient stock for "$name": available ${FormatUtils.formatQuantity(stock)}, required ${FormatUtils.formatQuantity(qty)}',
                );
              }
            }
          }
        }
        for (final item in items) {
          final productId = item['product_id'] as int?;
          final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
          if (productId == null || qty <= 0) continue;
          final pRows = await txn.query(
            'products',
            columns: ['type', 'stock_quantity', 'average_cost', 'cost_status'],
            where: 'id = ?',
            whereArgs: [productId],
          );
          if (pRows.isNotEmpty && pRows.first['type'] == 'product') {
            final currentStock =
                (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0;
            final avgCost = (pRows.first['average_cost'] as num?)?.toDouble();
            final costStatus =
                pRows.first['cost_status'] as String? ??
                Product.costStatusUnknown;
            final isCostKnown =
                costStatus == Product.costStatusKnown && avgCost != null;

            final double deductQty;
            if (strictStock) {
              deductQty = qty;
            } else {
              deductQty = currentStock > 0
                  ? (currentStock >= qty ? qty : currentStock)
                  : 0.0;
            }
            final bool isFullyBacked = deductQty >= qty;
            if (deductQty > 0) {
              final unitCost = (isCostKnown && isFullyBacked) ? avgCost : null;
              final totalCost = (isCostKnown && isFullyBacked)
                  ? qty * avgCost
                  : null;
              final movementCost = isCostKnown ? deductQty * avgCost : null;
              final movementCostStatus = (isCostKnown && isFullyBacked)
                  ? StockMovement.costStatusKnown
                  : StockMovement.costStatusUnknown;

              await txn.rawUpdate(
                'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
                [deductQty, productId],
              );
              await _insertStockMovement(
                txn,
                productId: productId,
                type: StockMovement.typeSale,
                quantity: -deductQty,
                unitCost: isCostKnown ? avgCost : null,
                totalCost: movementCost,
                costStatus: movementCostStatus,
                provenance: isFullyBacked
                    ? 'sales_invoice'
                    : 'sales_invoice_partial',
                referenceDocumentId: id,
                date: doc.date,
              );
              await txn.update(
                'document_items',
                {'unit_cost': unitCost, 'total_cost': totalCost},
                where: 'id = ?',
                whereArgs: [item['id']],
              );
            }
          }
        }
      } else if (doc.type == 'purchase') {
        for (final item in items) {
          final productId = item['product_id'] as int?;
          final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
          if (productId == null || qty <= 0) continue;
          final pRows = await txn.query(
            'products',
            columns: ['type', 'stock_quantity', 'average_cost', 'cost_status'],
            where: 'id = ?',
            whereArgs: [productId],
          );
          if (pRows.isNotEmpty && pRows.first['type'] == 'product') {
            final currentStock =
                (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0.0;
            final currentAvg = (pRows.first['average_cost'] as num?)
                ?.toDouble();
            final priorCostStatus =
                pRows.first['cost_status'] as String? ??
                Product.costStatusUnknown;

            final incomingQty = qty;
            final incomingUnitCost = (item['price'] as num?)?.toDouble() ?? 0.0;
            final itemTotalCost = incomingQty * incomingUnitCost;

            final double newAvgCost;
            final String newCostStatus;
            if (priorCostStatus == Product.costStatusKnown ||
                currentStock <= 0) {
              newAvgCost = InventoryCostingService.calculateNewWeightedAverage(
                currentStock: currentStock,
                currentAvgCost: currentAvg,
                incomingQty: incomingQty,
                incomingUnitCost: incomingUnitCost,
              );
              newCostStatus = Product.costStatusKnown;
            } else {
              newAvgCost = incomingUnitCost;
              newCostStatus = Product.costStatusUnknown;
            }

            await txn.update(
              'products',
              {
                'stock_quantity': currentStock + incomingQty,
                'average_cost': newAvgCost,
                'cost_status': newCostStatus,
              },
              where: 'id = ?',
              whereArgs: [productId],
            );

            await _insertStockMovement(
              txn,
              productId: productId,
              type: StockMovement.typePurchase,
              quantity: incomingQty,
              unitCost: incomingUnitCost,
              totalCost: itemTotalCost,
              costStatus: StockMovement.costStatusKnown,
              provenance: 'purchase_document',
              referenceDocumentId: id,
              date: doc.date,
            );

            await txn.update(
              'document_items',
              {'unit_cost': incomingUnitCost, 'total_cost': itemTotalCost},
              where: 'id = ?',
              whereArgs: [item['id']],
            );
          }
        }
      }

      final newStatus = (doc.type == 'invoice' || doc.type == 'purchase')
          ? DocumentStatus.fromPayment(doc.paid, doc.total)
          : DocumentStatus.issued;

      await txn.update(
        'documents',
        {'status': newStatus},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Creates a new draft copy of an existing document (new number, current date, no payments).
  Future<int> copyDocumentWithItems(int sourceId) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'documents',
        where: 'id = ?',
        whereArgs: [sourceId],
      );
      if (rows.isEmpty) throw StateError('Document not found');
      final source = Document.fromMap(rows.first);

      final newNumber = await getNextDocumentNumber(txn, source.type);
      final now = DateTime.now();
      final isItemBased =
          source.type == 'invoice' || source.type == 'quotation';

      // Financial/receipt copies start as issued; invoice/quotation copies as draft
      final newStatus = isItemBased
          ? DocumentStatus.draft
          : DocumentStatus.issued;
      final newPaid = isItemBased ? 0.0 : source.total;
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
        'valid_until': source.type == 'quotation'
            ? source.validUntil?.toIso8601String()
            : null,
        'notes': source.notes,
        'related_document_id': null,
        'status': newStatus,
        'currency_code': source.currencyCode,
      });

      if (isItemBased) {
        final items = await txn.query(
          'document_items',
          where: 'document_id = ?',
          whereArgs: [sourceId],
        );
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

  Future<String> getNextDocumentNumber(
    DatabaseExecutor txn,
    String type,
  ) async {
    final prefix = switch (type) {
      'invoice' => 'INV',
      'quotation' => 'QUO',
      'purchase' => 'PUR',
      'payment_receipt' => 'PAY',
      'expense_voucher' => 'EXP',
      'custom' => 'CUS',
      _ => 'DOC',
    };
    final rows = await txn.query(
      'document_counters',
      where: 'type = ?',
      whereArgs: [type],
    );
    int next = 1;
    if (rows.isNotEmpty) {
      next = (rows.first['next_number'] as num).toInt();
      await txn.update(
        'document_counters',
        {'next_number': next + 1},
        where: 'type = ?',
        whereArgs: [type],
      );
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
    final maps = await db.query(
      'documents',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'date DESC',
    );
    return maps.map((e) => Document.fromMap(e)).toList();
  }

  Future<List<Document>> searchDocuments(String query, {String? type}) async {
    final db = await database;
    String where =
        '(document_number LIKE ? OR notes LIKE ? OR recipient_name LIKE ? OR recipient_phone LIKE ? OR contact_id IN (SELECT id FROM contacts WHERE name LIKE ? OR phone LIKE ?))';
    final args = [
      '%$query%',
      '%$query%',
      '%$query%',
      '%$query%',
      '%$query%',
      '%$query%',
    ];
    if (type != null) {
      where += ' AND type = ?';
      args.add(type);
    }
    final maps = await db.query(
      'documents',
      where: where,
      whereArgs: args,
      orderBy: 'date DESC',
    );
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
    final maps = await db.query(
      'document_items',
      where: 'document_id = ?',
      whereArgs: [docId],
    );
    return maps.map((e) => DocumentItem.fromMap(e)).toList();
  }

  Future<List<Document>> getRecentDocuments({int limit = 5}) async {
    final db = await database;
    final maps = await db.query(
      'documents',
      orderBy: 'date DESC',
      limit: limit,
    );
    return maps.map((e) => Document.fromMap(e)).toList();
  }

  Future<Map<String, double>> getTodaySummary() async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final result = await db.rawQuery(
      '''
      SELECT
        SUM(CASE WHEN type = 'invoice' THEN total ELSE 0 END) as sales,
        SUM(CASE WHEN type = 'invoice' THEN remaining ELSE 0 END) as outstanding
      FROM documents
      WHERE date >= ? AND date < ?
        AND status != '${DocumentStatus.draft}'
        AND status != '${DocumentStatus.cancelled}'
    ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    if (result.isEmpty || result.first['sales'] == null) {
      return {'sales': 0, 'outstanding': 0};
    }
    return {
      'sales': (result.first['sales'] as num?)?.toDouble() ?? 0,
      'outstanding': (result.first['outstanding'] as num?)?.toDouble() ?? 0,
    };
  }

  Future<List<Document>> getDocumentsByContact(int contactId) async {
    final db = await database;
    final maps = await db.query(
      'documents',
      where: 'contact_id = ?',
      whereArgs: [contactId],
      orderBy: 'date DESC',
    );
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
    final finRows = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'invoice'         THEN total ELSE 0 END), 0) AS sales,
        COALESCE(SUM(CASE WHEN type = 'purchase'        THEN total ELSE 0 END), 0) AS purchases,
        COALESCE(SUM(CASE WHEN type = 'payment_receipt' THEN total ELSE 0 END), 0) AS paymentsIn,
        COALESCE(SUM(CASE WHEN type = 'expense_voucher' THEN total ELSE 0 END), 0) AS paymentsOut
      FROM documents
      WHERE status NOT IN ('${DocumentStatus.draft}', '${DocumentStatus.cancelled}')
        AND date >= ? AND date <= ?
    ''',
      [fromStr, toStr],
    );

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
    final double customerOutstanding =
        (b['customerOutstanding'] as num?)?.toDouble() ?? 0;
    final double supplierPayable =
        (b['supplierPayable'] as num?)?.toDouble() ?? 0;

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
      where:
          "type = ? AND date >= ? AND date <= ? AND status != '${DocumentStatus.draft}'",
      whereArgs: [type, from.toIso8601String(), to.toIso8601String()],
      orderBy: 'date DESC',
    );
    return maps.map((e) => Document.fromMap(e)).toList();
  }

  /// Contact balance summary for customer/supplier report (all-time).
  Future<List<Map<String, dynamic>>> getContactBalances(
    String contactType,
    String docType,
  ) async {
    final db = await database;
    return db.rawQuery(
      '''
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
    ''',
      [docType, contactType],
    );
  }

  /// Product-level sales and purchase quantities within a period.
  Future<List<Map<String, dynamic>>> getProductReport({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT
        p.id, p.name, p.type AS product_type,
        p.stock_quantity, p.min_stock, p.purchase_price,
        p.average_cost, p.cost_status,
        COALESCE(SUM(CASE WHEN d.type = 'invoice'  THEN di.quantity ELSE 0 END), 0) AS sales_qty,
        COALESCE(SUM(CASE WHEN d.type = 'invoice'  THEN di.total    ELSE 0 END), 0) AS sales_value,
        COALESCE(SUM(CASE WHEN d.type = 'purchase' THEN di.quantity ELSE 0 END), 0) AS purchase_qty,
        COALESCE(SUM(CASE WHEN d.type = 'purchase' THEN di.total    ELSE 0 END), 0) AS purchase_value,
        COALESCE(SUM(CASE WHEN d.type = 'invoice' AND di.total_cost IS NOT NULL THEN di.total_cost ELSE 0 END), 0) AS cogs,
        COUNT(CASE WHEN d.type = 'invoice' AND di.quantity > 0 AND di.total_cost IS NULL THEN 1 END) AS unknown_cost_count
      FROM products p
      LEFT JOIN document_items di ON di.product_id = p.id
      LEFT JOIN documents d ON d.id = di.document_id
        AND d.status NOT IN ('${DocumentStatus.draft}', '${DocumentStatus.cancelled}')
        AND d.date >= ? AND d.date <= ?
      WHERE p.is_active = 1
      GROUP BY p.id
      ORDER BY sales_value DESC, p.name
    ''',
      [from.toIso8601String(), to.toIso8601String()],
    );
  }

  /// Payments recorded in the given period with their linked document info.
  Future<List<Map<String, dynamic>>> getPaymentReport({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT
        dp.id, dp.amount, dp.payment_method, dp.date, dp.notes,
        dp.document_id,
        d.document_number, d.type AS doc_type, d.recipient_name
      FROM document_payments dp
      JOIN documents d ON d.id = dp.document_id
      WHERE dp.date >= ? AND dp.date <= ?
      ORDER BY dp.date DESC
    ''',
      [from.toIso8601String(), to.toIso8601String()],
    );
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

  Future<List<Map<String, dynamic>>> getRecentAuditEvents({
    int limit = 100,
  }) async {
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
        await txn.update(
          'tax_profiles',
          {'is_default': 0},
          where: 'id != ?',
          whereArgs: [p.id],
        );
      }
      return txn.update(
        'tax_profiles',
        p.toMap(),
        where: 'id = ?',
        whereArgs: [p.id],
      );
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
    final maps = await db.query(
      'tax_profiles',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return TaxProfile.fromMap(maps.first);
  }

  Future<TaxProfile?> getDefaultTaxProfile() async {
    final db = await database;
    final maps = await db.query(
      'tax_profiles',
      where: 'is_default = 1 AND is_active = 1',
      limit: 1,
    );
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
    final maps = await db.query(
      'payment_methods',
      where: 'is_enabled = 1',
      orderBy: 'sort_order, id',
    );
    return maps.map(PaymentMethod.fromMap).toList();
  }

  Future<PaymentMethod?> getDefaultPaymentMethod() async {
    final db = await database;
    final maps = await db.query(
      'payment_methods',
      where: 'is_default = 1',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return PaymentMethod.fromMap(maps.first);
  }

  Future<void> setPaymentMethodEnabled(
    String key, {
    required bool enabled,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'payment_methods',
        {'is_enabled': enabled ? 1 : 0},
        where: 'key = ?',
        whereArgs: [key],
      );
      // If disabling the default, move default to cash (or first enabled)
      if (!enabled) {
        final defaults = await txn.query(
          'payment_methods',
          where: 'is_default = 1 AND key = ?',
          whereArgs: [key],
        );
        if (defaults.isNotEmpty) {
          await txn.update(
            'payment_methods',
            {'is_default': 0},
            where: 'key = ?',
            whereArgs: [key],
          );
          final fallback = await txn.query(
            'payment_methods',
            where: 'is_enabled = 1 AND key != ?',
            whereArgs: [key],
            orderBy: 'sort_order, id',
            limit: 1,
          );
          if (fallback.isNotEmpty) {
            await txn.update(
              'payment_methods',
              {'is_default': 1},
              where: 'id = ?',
              whereArgs: [fallback.first['id']],
            );
          }
        }
      }
    });
  }

  Future<void> setPaymentMethodDefault(String key) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('payment_methods', {'is_default': 0});
      await txn.update(
        'payment_methods',
        {'is_default': 1, 'is_enabled': 1},
        where: 'key = ?',
        whereArgs: [key],
      );
    });
  }

  Future<int> insertCustomPaymentMethod({
    required String key,
    required String labelAr,
    required String labelEn,
  }) async {
    final db = await database;
    final maxOrder =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT MAX(sort_order) FROM payment_methods'),
        ) ??
        0;
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
    int id,
    String labelAr,
    String labelEn,
  ) async {
    final db = await database;
    await db.update(
      'payment_methods',
      {'label_ar': labelAr, 'label_en': labelEn},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> isPaymentMethodUsedInDocuments(String key) async {
    final db = await database;
    final r1 = await db.query(
      'documents',
      columns: ['id'],
      where: 'payment_method = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (r1.isNotEmpty) return true;
    final r2 = await db.query(
      'document_payments',
      columns: ['id'],
      where: 'payment_method = ?',
      whereArgs: [key],
      limit: 1,
    );
    return r2.isNotEmpty;
  }

  Future<int> deletePaymentMethod(int id) async {
    final db = await database;
    return db.delete(
      'payment_methods',
      where: 'id = ? AND is_predefined = 0',
      whereArgs: [id],
    );
  }

  // ========== Cached In-App Notifications ==========
  Future<void> upsertCachedNotification(AppNotification notif) async {
    final db = await database;
    final existing = await db.query(
      'cached_notifications',
      columns: ['is_read', 'read_at'],
      where: 'server_id = ?',
      whereArgs: [notif.serverId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final existingRead = (existing.first['is_read'] as int? ?? 0) == 1;
      final existingReadAt = existing.first['read_at'] as String?;
      final values = notif.toDbMap();
      if (existingRead) {
        values['is_read'] = 1;
        values['read_at'] = existingReadAt;
      }
      await db.update(
        'cached_notifications',
        values,
        where: 'server_id = ?',
        whereArgs: [notif.serverId],
      );
    } else {
      await db.insert(
        'cached_notifications',
        notif.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<AppNotification>> getCachedNotifications() async {
    final db = await database;
    final rows = await db.query(
      'cached_notifications',
      orderBy: 'published_at DESC',
    );
    return rows.map((r) => AppNotification.fromDb(r)).toList();
  }

  Future<void> markNotificationAsRead(int serverId, DateTime readAt) async {
    final db = await database;
    await db.update(
      'cached_notifications',
      {'is_read': 1, 'read_at': readAt.toIso8601String()},
      where: 'server_id = ?',
      whereArgs: [serverId],
    );
  }

  Future<int> getUnreadNotificationCount() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final res = await db.rawQuery(
      '''
      SELECT COUNT(*) as unread_count 
      FROM cached_notifications 
      WHERE is_read = 0 
        AND (expires_at IS NULL OR expires_at > ?)
    ''',
      [now],
    );
    if (res.isEmpty) return 0;
    return (res.first['unread_count'] as num?)?.toInt() ?? 0;
  }

  // ========== Diagnostic Reports (Milestone 2) ==========
  static const int maxPendingDiagnosticReports = 50;

  Future<int> insertDiagnosticReport(DiagnosticReport report) async {
    final db = await database;

    // Bounded storage: keep at most maxPendingDiagnosticReports (50).
    final countRes = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM diagnostic_reports',
    );
    final currentCount = (countRes.first['cnt'] as num?)?.toInt() ?? 0;
    if (currentCount >= maxPendingDiagnosticReports) {
      final excess = currentCount - maxPendingDiagnosticReports + 1;
      await db.rawDelete(
        '''
        DELETE FROM diagnostic_reports 
        WHERE id IN (
          SELECT id FROM diagnostic_reports 
          ORDER BY id ASC 
          LIMIT ?
        )
      ''',
        [excess],
      );
    }

    return db.insert(
      'diagnostic_reports',
      report.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DiagnosticReport>> getPendingDiagnosticReports({
    int limit = 10,
  }) async {
    final db = await database;
    final rows = await db.query(
      'diagnostic_reports',
      orderBy: 'id ASC',
      limit: limit,
    );
    return rows.map((r) => DiagnosticReport.fromDb(r)).toList();
  }

  Future<int> deleteDiagnosticReports(List<String> reportUuids) async {
    if (reportUuids.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(reportUuids.length, '?').join(',');
    return db.delete(
      'diagnostic_reports',
      where: 'report_uuid IN ($placeholders)',
      whereArgs: reportUuids,
    );
  }

  Future<int> clearAllDiagnosticReports() async {
    final db = await database;
    return db.delete('diagnostic_reports');
  }

  Future<int> getPendingDiagnosticReportCount() async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM diagnostic_reports',
    );
    if (res.isEmpty) return 0;
    return (res.first['cnt'] as num?)?.toInt() ?? 0;
  }

  // ========== Stocktake & Audit Log (Phase 5) ==========

  Future<StocktakeSession> createStocktakeSession({
    String? categoryFilter,
    String? notes,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final now = DateTime.now();
      final dateStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final sessionCountRow = await txn.rawQuery(
        "SELECT COUNT(*) as cnt FROM stocktake_sessions WHERE session_number LIKE 'ST-$dateStr-%'",
      );
      final seq = ((sessionCountRow.first['cnt'] as num?)?.toInt() ?? 0) + 1;
      final sessionNumber = 'ST-$dateStr-${seq.toString().padLeft(3, '0')}';

      // 1. Insert session
      final sessionId = await txn.insert('stocktake_sessions', {
        'session_number': sessionNumber,
        'status': StocktakeSession.statusInProgress,
        'started_at': now.toIso8601String(),
        'notes': notes,
        'category_filter': categoryFilter,
        'total_items': 0,
        'matched_items': 0,
        'discrepant_items': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // 2. Query products for session
      String where = "type = 'product' AND is_active = 1";
      List<Object?> args = [];
      if (categoryFilter != null && categoryFilter.isNotEmpty) {
        where += ' AND category = ?';
        args.add(categoryFilter);
      }

      final products = await txn.query(
        'products',
        where: where,
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'name ASC',
      );

      // 3. Insert stocktake_items
      final batch = txn.batch();
      for (final p in products) {
        batch.insert('stocktake_items', {
          'session_id': sessionId,
          'product_id': p['id'],
          'baseline_quantity': (p['stock_quantity'] as num?)?.toDouble() ?? 0.0,
          'counted_quantity': null,
          'reconciled_system_quantity': null,
          'variance': null,
          'unit_cost': (p['average_cost'] as num?)?.toDouble(),
          'notes': null,
          'status': StocktakeItem.statusPending,
        });
      }
      await batch.commit(noResult: true);

      // 4. Update session total
      await txn.update(
        'stocktake_sessions',
        {'total_items': products.length},
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      // 5. Audit log
      await txn.insert('audit_log', {
        'action': 'stocktake_started',
        'entity_type': 'stocktake_session',
        'entity_id': sessionId,
        'details':
            'session="$sessionNumber" items=${products.length}${categoryFilter != null ? " category=$categoryFilter" : ""}',
        'timestamp': now.toIso8601String(),
      });

      return StocktakeSession(
        id: sessionId,
        sessionNumber: sessionNumber,
        status: StocktakeSession.statusInProgress,
        startedAt: now,
        notes: notes,
        categoryFilter: categoryFilter,
        totalItems: products.length,
        createdAt: now,
        updatedAt: now,
      );
    });
  }

  Future<StocktakeSession?> getStocktakeSession(int id) async {
    final db = await database;
    final rows = await db.query(
      'stocktake_sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StocktakeSession.fromMap(rows.first);
  }

  Future<List<StocktakeSession>> getAllStocktakeSessions({
    int limit = 50,
  }) async {
    final db = await database;
    final rows = await db.query(
      'stocktake_sessions',
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return rows.map((r) => StocktakeSession.fromMap(r)).toList();
  }

  Future<List<StocktakeItem>> getStocktakeItems(int sessionId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT si.*,
             p.name AS product_name,
             p.unit AS product_unit,
             p.barcode AS product_barcode,
             p.code AS product_code,
             p.category AS product_category
      FROM stocktake_items si
      INNER JOIN products p ON p.id = si.product_id
      WHERE si.session_id = ?
      ORDER BY p.name ASC
    ''',
      [sessionId],
    );
    return rows.map((r) => StocktakeItem.fromMap(r)).toList();
  }

  Future<int> updateStocktakeItemCount(
    int itemId,
    double? countedQuantity, {
    String? notes,
  }) async {
    final db = await database;
    return db.update(
      'stocktake_items',
      {
        'counted_quantity': countedQuantity,
        'notes': notes,
        'status': countedQuantity != null
            ? StocktakeItem.statusCounted
            : StocktakeItem.statusPending,
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Future<Map<String, dynamic>> finalizeStocktakeSession(
    int sessionId, {
    String? notes,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final sessionRow = await txn.query(
        'stocktake_sessions',
        where: 'id = ?',
        whereArgs: [sessionId],
        limit: 1,
      );
      if (sessionRow.isEmpty) {
        throw StateError('Stocktake session not found');
      }
      final session = StocktakeSession.fromMap(sessionRow.first);
      if (session.isCompleted) {
        throw StateError('Stocktake session is already completed');
      }
      if (session.isCancelled) {
        throw StateError('Stocktake session is cancelled');
      }

      final items = await txn.rawQuery(
        '''
        SELECT si.*, p.stock_quantity AS current_stock, p.average_cost, p.cost_status, p.name AS product_name
        FROM stocktake_items si
        INNER JOIN products p ON p.id = si.product_id
        WHERE si.session_id = ?
      ''',
        [sessionId],
      );

      int matchedCount = 0;
      int discrepantCount = 0;
      int adjustedCount = 0;
      final now = DateTime.now();

      for (final row in items) {
        final itemId = row['id'] as int;
        final productId = row['product_id'] as int;
        final counted = (row['counted_quantity'] as num?)?.toDouble();
        final currentStock = (row['current_stock'] as num?)?.toDouble() ?? 0.0;
        final avgCost = (row['average_cost'] as num?)?.toDouble();
        final costStatus = (row['cost_status'] as String?) ?? 'unknown';

        if (counted == null) {
          // Uncounted item: do not alter stock
          await txn.update(
            'stocktake_items',
            {
              'reconciled_system_quantity': currentStock,
              'status': StocktakeItem.statusSkipped,
            },
            where: 'id = ?',
            whereArgs: [itemId],
          );
          continue;
        }

        final variance = counted - currentStock;
        if (variance == 0) {
          matchedCount++;
          await txn.update(
            'stocktake_items',
            {
              'reconciled_system_quantity': currentStock,
              'variance': 0.0,
              'status': StocktakeItem.statusMatched,
            },
            where: 'id = ?',
            whereArgs: [itemId],
          );
        } else {
          discrepantCount++;
          adjustedCount++;

          // 1. Atomically update product stock
          await txn.update(
            'products',
            {'stock_quantity': counted, 'updated_at': now.toIso8601String()},
            where: 'id = ?',
            whereArgs: [productId],
          );

          // 2. Insert stock movement
          final totalCost = avgCost != null ? (variance.abs() * avgCost) : null;

          await txn.insert('stock_movements', {
            'product_id': productId,
            'type': StockMovement.typeAdjustment,
            'quantity': variance,
            'unit_cost': avgCost,
            'total_cost': totalCost,
            'cost_status': costStatus,
            'provenance': 'stocktake',
            'date': now.toIso8601String(),
            'notes': 'تسوية جرد المخزون: ${session.sessionNumber}',
          });

          // 3. Update stocktake item record
          await txn.update(
            'stocktake_items',
            {
              'reconciled_system_quantity': currentStock,
              'variance': variance,
              'unit_cost': avgCost,
              'status': StocktakeItem.statusReconciled,
            },
            where: 'id = ?',
            whereArgs: [itemId],
          );
        }
      }

      // Finalize session
      await txn.update(
        'stocktake_sessions',
        {
          'status': StocktakeSession.statusCompleted,
          'completed_at': now.toIso8601String(),
          'matched_items': matchedCount,
          'discrepant_items': discrepantCount,
          'notes': notes ?? session.notes,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      // Audit log
      await txn.insert('audit_log', {
        'action': 'stocktake_finalized',
        'entity_type': 'stocktake_session',
        'entity_id': sessionId,
        'details':
            'session="${session.sessionNumber}" matched=$matchedCount discrepant=$discrepantCount adjusted=$adjustedCount',
        'timestamp': now.toIso8601String(),
      });

      return {
        'matched': matchedCount,
        'discrepant': discrepantCount,
        'adjusted': adjustedCount,
        'session_number': session.sessionNumber,
      };
    });
  }

  Future<void> cancelStocktakeSession(int sessionId) async {
    final db = await database;
    await db.transaction((txn) async {
      final sessionRow = await txn.query(
        'stocktake_sessions',
        where: 'id = ?',
        whereArgs: [sessionId],
        limit: 1,
      );
      if (sessionRow.isEmpty) return;
      final session = StocktakeSession.fromMap(sessionRow.first);
      if (session.isCompleted) {
        throw StateError('Cannot cancel completed stocktake session');
      }

      await txn.update(
        'stocktake_sessions',
        {
          'status': StocktakeSession.statusCancelled,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      await txn.insert('audit_log', {
        'action': 'stocktake_cancelled',
        'entity_type': 'stocktake_session',
        'entity_id': sessionId,
        'details': 'session="${session.sessionNumber}"',
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<List<Map<String, dynamic>>> getAuditEvents({
    String? action,
    String? entityType,
    int? entityId,
    DateTime? from,
    DateTime? to,
    int limit = 200,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <Object?>[];

    if (action != null && action.isNotEmpty && action != 'all') {
      conditions.add('action = ?');
      args.add(action);
    }
    if (entityType != null && entityType.isNotEmpty) {
      conditions.add('entity_type = ?');
      args.add(entityType);
    }
    if (entityId != null) {
      conditions.add('entity_id = ?');
      args.add(entityId);
    }
    if (from != null) {
      conditions.add('timestamp >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      conditions.add('timestamp <= ?');
      args.add(to.toIso8601String());
    }

    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    return db.query(
      'audit_log',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }
}
