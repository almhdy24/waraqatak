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
import '../models/product_unit.dart';
import '../models/stocktake.dart';
import '../services/accounting/journal_writer.dart';
import '../services/accounting/stock_ledger.dart';
import '../services/inventory_costing_service.dart';
import '../services/payment_allocator.dart';
import '../utils/arabic_search_utils.dart';
import '../core/catalog_events.dart';
import '../models/reference_pricing_types.dart';
import '../utils/format_utils.dart';
import '../utils/money_utils.dart';
import 'access_dao.dart';
import 'reference_pricing_dao.dart';
import '../services/access/access_context.dart';
import '../services/access/access_guard.dart';
import '../services/access/audit_service.dart';
import '../services/access/permission_registry.dart';
import '../models/digital_seal.dart';
import '../services/digital_seal_storage_service.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  DatabaseHelper._privateConstructor();

  static const int dbVersion = 33;

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
      'sort_order': 1,
      'is_predefined': 1,
    },
    {
      'key': 'bankak',
      'label_ar': 'بنكك',
      'label_en': 'Bankak',
      'is_enabled': 1,
      'is_default': 0,
      'sort_order': 2,
      'is_predefined': 1,
    },
    {
      'key': 'fawry',
      'label_ar': 'فوري',
      'label_en': 'Fawry',
      'is_enabled': 1,
      'is_default': 0,
      'sort_order': 3,
      'is_predefined': 1,
    },
    {
      'key': 'okash',
      'label_ar': 'أوكاش',
      'label_en': 'O-Cash',
      'is_enabled': 1,
      'is_default': 0,
      'sort_order': 4,
      'is_predefined': 1,
    },
    {
      'key': 'bank',
      'label_ar': 'تحويل بنكي',
      'label_en': 'Bank transfer',
      'is_enabled': 1,
      'is_default': 0,
      'sort_order': 5,
      'is_predefined': 1,
    },
    {
      'key': 'cheque',
      'label_ar': 'شيك',
      'label_en': 'Cheque',
      'is_enabled': 1,
      'is_default': 0,
      'sort_order': 6,
      'is_predefined': 1,
    },
  ];

  static Future<bool> _isPaymentMethodReferenced(
    DatabaseExecutor db,
    String key,
  ) async {
    try {
      final d = await db.rawQuery(
        'SELECT 1 FROM documents WHERE payment_method = ? LIMIT 1',
        [key],
      );
      if (d.isNotEmpty) return true;
    } catch (_) {}
    try {
      final dp = await db.rawQuery(
        'SELECT 1 FROM document_payments WHERE payment_method = ? LIMIT 1',
        [key],
      );
      if (dp.isNotEmpty) return true;
    } catch (_) {}
    return false;
  }

  /// Seeds or replaces the default payment methods:
  /// 1. Cash (نقداً) - selected by default (sort_order: 1)
  /// 2. Bankak (بنكك) - (sort_order: 2)
  /// 3. Fawry (فوري) - (sort_order: 3)
  /// 4. O-Cash (أوكاش) - (sort_order: 4)
  /// 5. Bank transfer (تحويل بنكي) - (sort_order: 5)
  /// 6. Cheque (شيك) - (sort_order: 6)
  ///
  /// Removes legacy seeded payment methods (deactivating them if referenced by existing records).
  /// Leaves user-added custom payment methods (is_predefined = 0) untouched.
  /// Runs idempotently without duplicate records on repeated invocations.
  static Future<void> replaceDefaultPaymentMethods(DatabaseExecutor db) async {
    const newKeys = {'cash', 'bankak', 'fawry', 'okash', 'bank', 'cheque'};

    // 1. Identify existing predefined payment methods
    final existingPredefined = await db.query(
      'payment_methods',
      where: 'is_predefined = 1',
    );

    for (final row in existingPredefined) {
      final key = row['key'] as String;
      if (!newKeys.contains(key)) {
        final inUse = await _isPaymentMethodReferenced(db, key);
        if (inUse) {
          // Deactivate/hide so old records and reports don't break
          await db.update(
            'payment_methods',
            {
              'is_enabled': 0,
              'is_default': 0,
              'sort_order': 900 + (row['sort_order'] as int? ?? 0),
            },
            where: 'key = ?',
            whereArgs: [key],
          );
        } else {
          // Unused legacy predefined method: remove
          await db.delete(
            'payment_methods',
            where: 'key = ?',
            whereArgs: [key],
          );
        }
      }
    }

    // 2. Clear default flag on existing predefined methods
    await db.update('payment_methods', {
      'is_default': 0,
    }, where: 'is_predefined = 1');

    // 3. Seed / upsert the 6 new defaults in exact order (sort_order 1 to 6)
    for (final seed in _paymentMethodSeeds) {
      final existing = await db.query(
        'payment_methods',
        where: 'key = ?',
        whereArgs: [seed['key']],
        limit: 1,
      );

      if (existing.isEmpty) {
        await db.insert('payment_methods', seed);
      } else {
        await db.update(
          'payment_methods',
          {
            'label_ar': seed['label_ar'],
            'label_en': seed['label_en'],
            'is_enabled': seed['is_enabled'],
            'is_default': seed['is_default'],
            'sort_order': seed['sort_order'],
            'is_predefined': 1,
          },
          where: 'key = ?',
          whereArgs: [seed['key']],
        );
      }
    }
  }

  static Future<void> _seedPaymentMethods(DatabaseExecutor db) async {
    await replaceDefaultPaymentMethods(db);
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
        wholesale_pricing_enabled INTEGER NOT NULL DEFAULT 0,
        invoice_title TEXT,
        legal_footer TEXT,
        currency_locked_at TEXT
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
        pricing_category TEXT NOT NULL DEFAULT 'retail',
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
        wholesale_price REAL,
        wholesale_min_quantity REAL,
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
        price_currency TEXT,
        reference_sale_price REAL,
        reference_wholesale_price REAL,
        reference_purchase_price REAL,
        image_path TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_products_name ON products(name)');
    if (version >= 27) {
      await db.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_products_barcode_unique ON products(barcode) WHERE barcode IS NOT NULL AND barcode != ''",
      );
    } else {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)',
      );
    }
    await db.execute(
      'CREATE INDEX idx_products_category ON products(category)',
    );
    await db.execute(
      'CREATE INDEX idx_products_price_currency ON products(price_currency)',
    );

    await db.execute('''
      CREATE TABLE product_units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        unit_name TEXT NOT NULL,
        conversion_factor REAL NOT NULL,
        sale_price REAL,
        wholesale_price REAL,
        is_default_sale INTEGER DEFAULT 0,
        reference_sale_price REAL,
        reference_wholesale_price REAL,
        reference_currency TEXT,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_product_units_product ON product_units(product_id)',
    );

    await db.execute('''
      CREATE TABLE exchange_rates (
        code TEXT PRIMARY KEY,
        name_ar TEXT NOT NULL,
        name_en TEXT,
        symbol TEXT NOT NULL,
        rate REAL NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_custom INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

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
        reason TEXT,
        target_movement_id INTEGER,
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
    await db.execute(
      'CREATE INDEX idx_stock_movements_ref_doc ON stock_movements(reference_document_id)',
    );
    await db.execute(
      'CREATE INDEX idx_stock_movements_date ON stock_movements(date)',
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
    await db.execute(
      'CREATE INDEX idx_documents_contact ON documents(contact_id)',
    );
    await db.execute(
      'CREATE INDEX idx_documents_related ON documents(related_document_id)',
    );
    await db.execute(
      'CREATE INDEX idx_documents_type_status_date ON documents(type, status, date)',
    );
    if (version >= 27) {
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_documents_type_docnum_unique ON documents(type, document_number)',
      );
    }

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
        pricing_category TEXT,
        sale_unit TEXT,
        unit_conversion_factor REAL DEFAULT 1.0,
        base_quantity REAL,
        FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_document_items_doc ON document_items(document_id)',
    );
    await db.execute(
      'CREATE INDEX idx_document_items_prod ON document_items(product_id)',
    );

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
        payment_origin TEXT,
        FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE,
        FOREIGN KEY (receipt_document_id) REFERENCES documents (id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_document_payments_doc ON document_payments(document_id)',
    );
    await db.execute(
      'CREATE INDEX idx_document_payments_receipt ON document_payments(receipt_document_id)',
    );
    await db.execute(
      'CREATE INDEX idx_document_payments_date ON document_payments(date)',
    );
    await db.execute(
      'CREATE INDEX idx_document_payments_origin ON document_payments(payment_origin)',
    );

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

    // Double-entry accounting backbone tables (Phase 1)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
        code TEXT PRIMARY KEY,
        name_ar TEXT NOT NULL,
        name_en TEXT NOT NULL,
        type TEXT NOT NULL,
        normal_side TEXT NOT NULL,
        is_system INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await seedAccounts(db);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS journal_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_no TEXT NOT NULL UNIQUE,
        effective_date TEXT NOT NULL,
        posted_at TEXT NOT NULL,
        source_type TEXT NOT NULL,
        source_id INTEGER,
        revision INTEGER NOT NULL DEFAULT 1,
        memo TEXT,
        reverses_entry_id INTEGER REFERENCES journal_entries(id),
        origin TEXT NOT NULL DEFAULT 'live'
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_journal_entries_date ON journal_entries(effective_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_journal_entries_source ON journal_entries(source_type, source_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_journal_entries_origin ON journal_entries(origin)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS journal_lines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_id INTEGER NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,
        account_code TEXT NOT NULL REFERENCES accounts(code),
        debit_minor INTEGER NOT NULL DEFAULT 0,
        credit_minor INTEGER NOT NULL DEFAULT 0,
        product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
        contact_id INTEGER REFERENCES contacts(id) ON DELETE SET NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_journal_lines_entry ON journal_lines(entry_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_journal_lines_account ON journal_lines(account_code)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_journal_lines_product ON journal_lines(product_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_journal_lines_contact ON journal_lines(contact_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await seedDefaultSettings(db);

    if (version >= 29) {
      await AccessDao.createAccessControlTables(db);
      await AccessDao.ensureAttributionColumns(db);
      await AccessDao.seedAccessControlDefaults(db);
    }

    if (version >= 30) {
      await AccessDao.createSecurityTriggers(db);
    }

    if (version >= 32) {
      await _createDigitalSealsTables(db);
    }
  }

  @visibleForTesting
  Future<void> createTablesForTest(Database db, [int version = dbVersion]) =>
      _createTables(db, version);

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

    Future<bool> tableExists(String table) async {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
        [table],
      );
      return tables.isNotEmpty;
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
      if (await columnExists('audit_log', 'action')) {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_audit_log_action ON audit_log(action)',
        );
      }
      if (await columnExists('audit_log', 'timestamp')) {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_audit_log_timestamp ON audit_log(timestamp)',
        );
      }
    }

    if (oldVersion < 17 && newVersion >= 17) {
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

    if (oldVersion < 18 && newVersion >= 18) {
      // Performance indexes for foreign keys, cascading deletes, and common queries
      if (await columnExists('documents', 'contact_id')) {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_documents_contact ON documents(contact_id)',
        );
      }
      if (await columnExists('documents', 'related_document_id')) {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_documents_related ON documents(related_document_id)',
        );
      }
      if (await columnExists('documents', 'type') &&
          await columnExists('documents', 'status') &&
          await columnExists('documents', 'date')) {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_documents_type_status_date ON documents(type, status, date)',
        );
      }
      if (await columnExists('document_items', 'document_id')) {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_document_items_doc ON document_items(document_id)',
        );
      }
      if (await columnExists('document_items', 'product_id')) {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_document_items_prod ON document_items(product_id)',
        );
      }
      if (await columnExists('document_payments', 'document_id')) {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_document_payments_doc ON document_payments(document_id)',
        );
      }
      if (await columnExists('document_payments', 'receipt_document_id')) {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_document_payments_receipt ON document_payments(receipt_document_id)',
        );
      }
      if (await columnExists('document_payments', 'date')) {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_document_payments_date ON document_payments(date)',
        );
      }
      if (await columnExists('stock_movements', 'reference_document_id')) {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_stock_movements_ref_doc ON stock_movements(reference_document_id)',
        );
      }
      if (await columnExists('stock_movements', 'date')) {
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_stock_movements_date ON stock_movements(date)',
        );
      }

      // Safe legacy stock reconciliation: create opening movement only for clean legacy
      // products that have stock > 0 but ZERO stock movements recorded in history.
      await _reconcileLegacyOpeningStock(db);
    }

    if (oldVersion < 19 && newVersion >= 19) {
      if (await tableExists('document_payments')) {
        if (!await columnExists('document_payments', 'payment_origin')) {
          await db.execute(
            'ALTER TABLE document_payments ADD COLUMN payment_origin TEXT',
          );
        }
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_document_payments_origin ON document_payments(payment_origin)',
        );
      }
    }

    if (oldVersion < 20 && newVersion >= 20) {
      await _repairLegacyCostingReplay(db);
    }

    if (oldVersion < 21 && newVersion >= 21) {
      if (!await columnExists('businesses', 'currency_locked_at')) {
        await db.execute(
          'ALTER TABLE businesses ADD COLUMN currency_locked_at TEXT',
        );
      }
      await backfillCurrencyLockIfNeeded(db);
    }

    if (oldVersion < 22 && newVersion >= 22) {
      if (!await columnExists('businesses', 'wholesale_pricing_enabled')) {
        await db.execute(
          'ALTER TABLE businesses ADD COLUMN wholesale_pricing_enabled INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (!await columnExists('products', 'wholesale_price')) {
        await db.execute(
          'ALTER TABLE products ADD COLUMN wholesale_price REAL',
        );
      }
      if (!await columnExists('products', 'wholesale_min_quantity')) {
        await db.execute(
          'ALTER TABLE products ADD COLUMN wholesale_min_quantity REAL',
        );
      }
      if (!await columnExists('contacts', 'pricing_category')) {
        await db.execute(
          "ALTER TABLE contacts ADD COLUMN pricing_category TEXT NOT NULL DEFAULT 'retail'",
        );
      }
      if (!await columnExists('document_items', 'pricing_category')) {
        await db.execute(
          'ALTER TABLE document_items ADD COLUMN pricing_category TEXT',
        );
      }
    }

    if (oldVersion < 23 && newVersion >= 23) {
      if (!await tableExists('product_units')) {
        await db.execute('''
          CREATE TABLE product_units (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id INTEGER NOT NULL,
            unit_name TEXT NOT NULL,
            conversion_factor REAL NOT NULL,
            sale_price REAL,
            wholesale_price REAL,
            is_default_sale INTEGER DEFAULT 0,
            FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_product_units_product ON product_units(product_id)',
        );
      }
      if (!await columnExists('document_items', 'sale_unit')) {
        await db.execute(
          'ALTER TABLE document_items ADD COLUMN sale_unit TEXT',
        );
      }
      if (!await columnExists('document_items', 'unit_conversion_factor')) {
        await db.execute(
          'ALTER TABLE document_items ADD COLUMN unit_conversion_factor REAL DEFAULT 1.0',
        );
      }
      if (!await columnExists('document_items', 'base_quantity')) {
        await db.execute(
          'ALTER TABLE document_items ADD COLUMN base_quantity REAL',
        );
      }
      await db.rawUpdate('''
        UPDATE document_items
        SET unit_conversion_factor = 1.0,
            base_quantity = quantity
        WHERE unit_conversion_factor IS NULL OR base_quantity IS NULL
      ''');
    }

    if (oldVersion < 24 && newVersion >= 24) {
      await replaceDefaultPaymentMethods(db);
    }

    if (oldVersion < 25 && newVersion >= 25) {
      if (!await tableExists('accounts')) {
        await db.execute('''
          CREATE TABLE accounts (
            code TEXT PRIMARY KEY,
            name_ar TEXT NOT NULL,
            name_en TEXT NOT NULL,
            type TEXT NOT NULL,
            normal_side TEXT NOT NULL,
            is_system INTEGER NOT NULL DEFAULT 1
          )
        ''');
      }
      await seedAccounts(db);

      if (!await tableExists('journal_entries')) {
        await db.execute('''
          CREATE TABLE journal_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entry_no TEXT NOT NULL UNIQUE,
            effective_date TEXT NOT NULL,
            posted_at TEXT NOT NULL,
            source_type TEXT NOT NULL,
            source_id INTEGER,
            revision INTEGER NOT NULL DEFAULT 1,
            memo TEXT,
            reverses_entry_id INTEGER REFERENCES journal_entries(id),
            origin TEXT NOT NULL DEFAULT 'live'
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_journal_entries_date ON journal_entries(effective_date)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_journal_entries_source ON journal_entries(source_type, source_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_journal_entries_origin ON journal_entries(origin)',
        );
      }

      if (!await tableExists('journal_lines')) {
        await db.execute('''
          CREATE TABLE journal_lines (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entry_id INTEGER NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,
            account_code TEXT NOT NULL REFERENCES accounts(code),
            debit_minor INTEGER NOT NULL DEFAULT 0,
            credit_minor INTEGER NOT NULL DEFAULT 0,
            product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
            contact_id INTEGER REFERENCES contacts(id) ON DELETE SET NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_journal_lines_entry ON journal_lines(entry_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_journal_lines_account ON journal_lines(account_code)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_journal_lines_product ON journal_lines(product_id)',
        );
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_journal_lines_contact ON journal_lines(contact_id)',
        );
      }

      if (!await tableExists('app_settings')) {
        await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      }
      await seedDefaultSettings(db);

      if (await tableExists('stock_movements')) {
        if (!await columnExists('stock_movements', 'reason')) {
          await db.execute(
            'ALTER TABLE stock_movements ADD COLUMN reason TEXT',
          );
        }
        if (!await columnExists('stock_movements', 'target_movement_id')) {
          await db.execute(
            'ALTER TABLE stock_movements ADD COLUMN target_movement_id INTEGER',
          );
        }
      }
    }

    if (oldVersion < 26 && newVersion >= 26) {
      await _upgradeToReferenceCurrencySchema(db);
    }

    // v26 was used by feat/reference-currency-pricing; this migration is v27.
    if (oldVersion < 27 && newVersion >= 27) {
      // 1. Products barcode cleanup & unique index
      if (await tableExists('products')) {
        await db.execute(
          "UPDATE products SET barcode = NULL WHERE barcode IS NOT NULL AND TRIM(barcode) = ''",
        );

        final dupBarcodes = await db.rawQuery('''
          SELECT barcode, COUNT(*) AS cnt
          FROM products
          WHERE barcode IS NOT NULL AND barcode != ''
          GROUP BY barcode
          HAVING cnt > 1
        ''');

        for (final row in dupBarcodes) {
          final bc = row['barcode'] as String;
          final prodRows = await db.query(
            'products',
            columns: ['id'],
            where: 'barcode = ?',
            whereArgs: [bc],
            orderBy: 'id ASC',
          );
          for (int i = 1; i < prodRows.length; i++) {
            final pId = prodRows[i]['id'] as int;
            final newBc = '${bc}_dup_$pId';
            await db.update(
              'products',
              {'barcode': newBc},
              where: 'id = ?',
              whereArgs: [pId],
            );
            await db.insert('audit_log', {
              'action': 'migration_v27_resolve_duplicate_barcode',
              'entity_type': 'product',
              'entity_id': pId,
              'details': 'Renamed duplicate barcode "$bc" to "$newBc"',
              'timestamp': DateTime.now().toIso8601String(),
            });
          }
        }

        await db.execute('DROP INDEX IF EXISTS idx_products_barcode');
        await db.execute(
          "CREATE UNIQUE INDEX IF NOT EXISTS idx_products_barcode_unique ON products(barcode) WHERE barcode IS NOT NULL AND barcode != ''",
        );
      }

      // 2. Documents (type, document_number) cleanup & unique index
      if (await tableExists('documents')) {
        final dupDocNums = await db.rawQuery('''
          SELECT type, document_number, COUNT(*) AS cnt
          FROM documents
          GROUP BY type, document_number
          HAVING cnt > 1
        ''');

        for (final row in dupDocNums) {
          final dType = row['type'] as String;
          final dNum = row['document_number'] as String;
          final docRows = await db.query(
            'documents',
            columns: ['id'],
            where: 'type = ? AND document_number = ?',
            whereArgs: [dType, dNum],
            orderBy: 'id ASC',
          );
          for (int i = 1; i < docRows.length; i++) {
            final dId = docRows[i]['id'] as int;
            final newDNum = '${dNum}_dup_$dId';
            await db.update(
              'documents',
              {'document_number': newDNum},
              where: 'id = ?',
              whereArgs: [dId],
            );
            await db.insert('audit_log', {
              'action': 'migration_v27_resolve_duplicate_document_number',
              'entity_type': 'document',
              'entity_id': dId,
              'details':
                  'Renamed duplicate document number "$dNum" to "$newDNum" for type "$dType"',
              'timestamp': DateTime.now().toIso8601String(),
            });
          }
        }

        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_documents_type_docnum_unique ON documents(type, document_number)',
        );
      }
    }

    if (oldVersion < 28 && newVersion >= 28) {
      await _upgradeToReferenceCurrencySchema(db);
    }

    if (oldVersion < 29 && newVersion >= 29) {
      await AccessDao.upgradeToSchemaV29(db);
    }

    if (oldVersion < 30 && newVersion >= 30) {
      await AccessDao.upgradeToSchemaV30(db);
    }

    if (oldVersion < 31 && newVersion >= 31) {
      if (!await columnExists('products', 'image_path')) {
        await db.execute('ALTER TABLE products ADD COLUMN image_path TEXT');
      }
    }

    if (oldVersion < 32 && newVersion >= 32) {
      await _upgradeToDigitalSealsSchema(db);
    }

    if (oldVersion < 33 && newVersion >= 33) {
      await _upgradeToProductImageBasenameSchema(db);
    }
  }

  static Future<void> _upgradeToProductImageBasenameSchema(
    DatabaseExecutor db,
  ) async {
    final rows = await db.rawQuery(
      "SELECT id, image_path FROM products WHERE image_path IS NOT NULL AND image_path != ''",
    );
    for (final row in rows) {
      final id = row['id'];
      final rawPath = row['image_path'] as String?;
      if (rawPath != null &&
          (rawPath.contains('/') || rawPath.contains(r'\'))) {
        final filename = basename(rawPath);
        await db.rawUpdate('UPDATE products SET image_path = ? WHERE id = ?', [
          filename,
          id,
        ]);
      }
    }
  }

  static Future<void> _createDigitalSealsTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS digital_assets (
        id TEXT PRIMARY KEY,
        business_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        filename TEXT NOT NULL,
        format TEXT NOT NULL,
        width INTEGER NOT NULL,
        height INTEGER NOT NULL,
        bytes_length INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (business_id) REFERENCES businesses (id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_digital_assets_business ON digital_assets(business_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS business_seal_configs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER NOT NULL,
        seal_type TEXT NOT NULL,
        asset_id TEXT,
        is_enabled INTEGER NOT NULL DEFAULT 0,
        start_ratio REAL NOT NULL,
        top_ratio REAL NOT NULL,
        width_ratio REAL NOT NULL,
        aspect_ratio REAL NOT NULL DEFAULT 1.0,
        opacity REAL NOT NULL,
        page_rule TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(business_id, seal_type),
        FOREIGN KEY (business_id) REFERENCES businesses (id),
        FOREIGN KEY (asset_id) REFERENCES digital_assets (id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_business_seal_configs_business ON business_seal_configs(business_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS document_seal_snapshots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_id INTEGER NOT NULL UNIQUE,
        business_id INTEGER NOT NULL,
        snapshot_data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE,
        FOREIGN KEY (business_id) REFERENCES businesses (id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_document_seal_snapshots_doc ON document_seal_snapshots(document_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS document_seal_snapshot_assets (
        snapshot_id INTEGER NOT NULL,
        asset_id TEXT NOT NULL,
        PRIMARY KEY (snapshot_id, asset_id),
        FOREIGN KEY (snapshot_id) REFERENCES document_seal_snapshots (id) ON DELETE CASCADE,
        FOREIGN KEY (asset_id) REFERENCES digital_assets (id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_snapshot_assets_asset ON document_seal_snapshot_assets(asset_id)',
    );
  }

  static Future<void> _upgradeToDigitalSealsSchema(DatabaseExecutor db) async {
    await _createDigitalSealsTables(db);
  }

  static Future<void> _upgradeToReferenceCurrencySchema(
    DatabaseExecutor db,
  ) async {
    Future<bool> columnExists(String table, String column) async {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      return columns.any((c) => c['name'] == column);
    }

    Future<bool> tableExists(String table) async {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
        [table],
      );
      return tables.isNotEmpty;
    }

    if (await tableExists('products')) {
      if (!await columnExists('products', 'price_currency')) {
        await db.execute('ALTER TABLE products ADD COLUMN price_currency TEXT');
      }
      if (!await columnExists('products', 'reference_sale_price')) {
        await db.execute(
          'ALTER TABLE products ADD COLUMN reference_sale_price REAL',
        );
      }
      if (!await columnExists('products', 'reference_wholesale_price')) {
        await db.execute(
          'ALTER TABLE products ADD COLUMN reference_wholesale_price REAL',
        );
      }
      if (!await columnExists('products', 'reference_purchase_price')) {
        await db.execute(
          'ALTER TABLE products ADD COLUMN reference_purchase_price REAL',
        );
      }
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_price_currency ON products(price_currency)',
      );
    }

    if (await tableExists('product_units')) {
      if (!await columnExists('product_units', 'reference_sale_price')) {
        await db.execute(
          'ALTER TABLE product_units ADD COLUMN reference_sale_price REAL',
        );
      }
      if (!await columnExists('product_units', 'reference_wholesale_price')) {
        await db.execute(
          'ALTER TABLE product_units ADD COLUMN reference_wholesale_price REAL',
        );
      }
      if (!await columnExists('product_units', 'reference_currency')) {
        await db.execute(
          'ALTER TABLE product_units ADD COLUMN reference_currency TEXT',
        );
      }
    }

    if (!await tableExists('exchange_rates')) {
      await db.execute('''
        CREATE TABLE exchange_rates (
          code TEXT PRIMARY KEY,
          name_ar TEXT NOT NULL,
          name_en TEXT,
          symbol TEXT NOT NULL,
          rate REAL NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1,
          is_custom INTEGER NOT NULL DEFAULT 0,
          updated_at TEXT NOT NULL
        )
      ''');
    }
  }

  static Future<void> backfillCurrencyLockIfNeeded(DatabaseExecutor db) async {
    final bRows = await db.rawQuery(
      'SELECT id, currency_locked_at FROM businesses LIMIT 1',
    );
    if (bRows.isEmpty) return;
    if (bRows.first['currency_locked_at'] != null) return;

    final docRows = await db.rawQuery(
      "SELECT 1 FROM documents WHERE status != '${DocumentStatus.draft}' LIMIT 1",
    );
    final payRows = await db.rawQuery(
      'SELECT 1 FROM document_payments LIMIT 1',
    );
    final smRows = await db.rawQuery(
      'SELECT 1 FROM stock_movements WHERE quantity != 0 LIMIT 1',
    );

    if (docRows.isNotEmpty || payRows.isNotEmpty || smRows.isNotEmpty) {
      final now = DateTime.now().toIso8601String();
      await db.rawUpdate(
        'UPDATE businesses SET currency_locked_at = ? WHERE currency_locked_at IS NULL',
        [now],
      );
    }
  }

  /// Seeds standard 13-account chart into accounts table if not already present.
  static Future<void> seedAccounts(DatabaseExecutor db) async {
    const systemAccounts = [
      {
        'code': '1110',
        'name_ar': 'الصندوق (النقدية)',
        'name_en': 'Cash on hand',
        'type': 'asset',
        'normal_side': 'debit',
        'is_system': 1,
      },
      {
        'code': '1120',
        'name_ar': 'البنوك والمحافظ الإلكترونية',
        'name_en': 'Bank & e-wallets',
        'type': 'asset',
        'normal_side': 'debit',
        'is_system': 1,
      },
      {
        'code': '1130',
        'name_ar': 'العملاء (ذمم مدينة)',
        'name_en': 'Accounts receivable',
        'type': 'asset',
        'normal_side': 'debit',
        'is_system': 1,
      },
      {
        'code': '1140',
        'name_ar': 'المخزون',
        'name_en': 'Inventory',
        'type': 'asset',
        'normal_side': 'debit',
        'is_system': 1,
      },
      {
        'code': '1150',
        'name_ar': 'ضريبة مستردة (مدخلات)',
        'name_en': 'Tax receivable (input)',
        'type': 'asset',
        'normal_side': 'debit',
        'is_system': 1,
      },
      {
        'code': '2110',
        'name_ar': 'الموردون (ذمم دائنة)',
        'name_en': 'Accounts payable',
        'type': 'liability',
        'normal_side': 'credit',
        'is_system': 1,
      },
      {
        'code': '2120',
        'name_ar': 'ضريبة مستحقة (مخرجات)',
        'name_en': 'Tax payable (output)',
        'type': 'liability',
        'normal_side': 'credit',
        'is_system': 1,
      },
      {
        'code': '3100',
        'name_ar': 'رأس المال / أرصدة افتتاحية',
        'name_en': 'Opening balance equity',
        'type': 'equity',
        'normal_side': 'credit',
        'is_system': 1,
      },
      {
        'code': '4100',
        'name_ar': 'إيرادات المبيعات',
        'name_en': 'Sales revenue',
        'type': 'revenue',
        'normal_side': 'credit',
        'is_system': 1,
      },
      {
        'code': '4900',
        'name_ar': 'إيرادات أخرى',
        'name_en': 'Other income',
        'type': 'revenue',
        'normal_side': 'credit',
        'is_system': 1,
      },
      {
        'code': '5100',
        'name_ar': 'تكلفة البضاعة المباعة',
        'name_en': 'Cost of goods sold',
        'type': 'expense',
        'normal_side': 'debit',
        'is_system': 1,
      },
      {
        'code': '5200',
        'name_ar': 'عجز وتسويات المخزون',
        'name_en': 'Inventory adjustments',
        'type': 'expense',
        'normal_side': 'debit',
        'is_system': 1,
      },
      {
        'code': '6100',
        'name_ar': 'المصروفات التشغيلية',
        'name_en': 'Operating expenses',
        'type': 'expense',
        'normal_side': 'debit',
        'is_system': 1,
      },
    ];

    for (final acc in systemAccounts) {
      await db.insert(
        'accounts',
        acc,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  /// Seeds default app settings into app_settings table if not already present.
  static Future<void> seedDefaultSettings(DatabaseExecutor db) async {
    const defaults = {
      'journal_shadow_write': 'true',
      'journal_reports_enabled': 'false',
    };
    for (final entry in defaults.entries) {
      await db.insert('app_settings', {
        'key': entry.key,
        'value': entry.value,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  /// Retrieves a value from app_settings by key.
  Future<String?> getSetting(String key, {DatabaseExecutor? txn}) async {
    final exec = txn ?? (await database);
    final rows = await exec.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  /// Inserts or updates a value in app_settings.
  Future<void> setSetting(
    String key,
    String? value, {
    DatabaseExecutor? txn,
  }) async {
    final exec = txn ?? (await database);
    await exec.insert('app_settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Flag indicating whether shadow posting to the journal is active (default true).
  Future<bool> isJournalShadowWriteEnabled({DatabaseExecutor? txn}) async {
    final val = await getSetting('journal_shadow_write', txn: txn);
    return val == null || val.toLowerCase() == 'true';
  }

  /// Flag indicating whether reporting displays persisted journal data (default false).
  Future<bool> isJournalReportsEnabled({DatabaseExecutor? txn}) async {
    final val = await getSetting('journal_reports_enabled', txn: txn);
    return val != null && val.toLowerCase() == 'true';
  }

  /// Returns the period lock cutoff date, if any.
  Future<DateTime?> getBooksClosedThrough({DatabaseExecutor? txn}) async {
    final val = await getSetting('books_closed_through', txn: txn);
    if (val == null || val.isEmpty) return null;
    return DateTime.tryParse(val);
  }

  /// Sets or clears the period lock cutoff date.
  Future<void> setBooksClosedThrough(
    DateTime? date, {
    DatabaseExecutor? txn,
  }) async {
    AccessGuard.require(PermissionRegistry.accountingPeriodLock);
    await setSetting(
      'books_closed_through',
      date?.toIso8601String().substring(0, 10),
      txn: txn,
    );
  }

  /// Checks if a given transaction date is closed by the period lock.
  Future<bool> isPeriodClosed(DateTime date, {DatabaseExecutor? txn}) async {
    final lockDate = await getBooksClosedThrough(txn: txn);
    if (lockDate == null) return false;
    final entryDay = DateTime(date.year, date.month, date.day);
    final lockDay = DateTime(lockDate.year, lockDate.month, lockDate.day);
    return !entryDay.isAfter(lockDay);
  }

  /// Asserts that a transaction date is open. Throws [StateError] if closed.
  Future<void> assertPeriodOpen(DateTime date, {DatabaseExecutor? txn}) async {
    if (await isPeriodClosed(date, txn: txn)) {
      final lockDate = await getBooksClosedThrough(txn: txn);
      final dateStr = lockDate != null
          ? '${lockDate.year.toString().padLeft(4, '0')}-${lockDate.month.toString().padLeft(2, '0')}-${lockDate.day.toString().padLeft(2, '0')}'
          : '';
      throw StateError('Accounting period is closed through $dateStr');
    }
  }

  static Future<void> _lockCurrencyTxn(DatabaseExecutor txn) async {
    final now = DateTime.now().toIso8601String();
    await txn.rawUpdate(
      'UPDATE businesses SET currency_locked_at = ? WHERE currency_locked_at IS NULL',
      [now],
    );
  }

  static Future<int> _insertDocumentPaymentTxn(
    DatabaseExecutor txn,
    Map<String, Object?> values,
  ) async {
    final copy = Map<String, Object?>.from(values);
    copy['created_by'] ??= AccessContext.currentUserId;
    copy['origin_device_id'] ??= AccessContext.currentDeviceId;
    final id = await txn.insert('document_payments', copy);
    final amount = (values['amount'] as num?)?.toDouble() ?? 0.0;
    if (amount > 0) {
      await _lockCurrencyTxn(txn);
    }
    return id;
  }

  static Future<bool> _isCurrencyLockedTxn(
    DatabaseExecutor txn,
    Business business,
  ) async {
    if (business.isCurrencyLocked) return true;

    final docRows = await txn.rawQuery(
      "SELECT 1 FROM documents WHERE status != '${DocumentStatus.draft}' LIMIT 1",
    );
    if (docRows.isNotEmpty) return true;

    final payRows = await txn.rawQuery(
      'SELECT 1 FROM document_payments LIMIT 1',
    );
    if (payRows.isNotEmpty) return true;

    final smRows = await txn.rawQuery(
      'SELECT 1 FROM stock_movements WHERE quantity != 0 LIMIT 1',
    );
    return smRows.isNotEmpty;
  }

  static Future<void> _reconcileLegacyOpeningStock(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info(products)');
    final hasCreatedAt = columns.any((c) => c['name'] == 'created_at');
    final createdAtCol = hasCreatedAt ? 'p.created_at' : 'NULL AS created_at';
    final productsWithMissingOpening = await db.rawQuery('''
      SELECT p.id, p.stock_quantity, $createdAtCol
      FROM products p
      LEFT JOIN stock_movements sm ON sm.product_id = p.id
      WHERE (p.type = 'product' OR p.type IS NULL)
        AND p.stock_quantity > 0.0001
        AND sm.id IS NULL
    ''');

    if (productsWithMissingOpening.isEmpty) return;

    for (final row in productsWithMissingOpening) {
      final pid = row['id'] as int;
      final qty = (row['stock_quantity'] as num).toDouble();
      final createdAtStr = row['created_at'] as String?;

      // Query earliest finalized inventory-affecting document (invoice or purchase).
      // Drafts, quotations, vouchers, and cancelled documents never affect stock.
      final productDocRows = await db.rawQuery(
        '''
        SELECT MIN(d.date) AS min_date
        FROM document_items di
        JOIN documents d ON d.id = di.document_id
        WHERE di.product_id = ?
          AND d.type IN ('invoice', 'purchase')
          AND d.status NOT IN ('${DocumentStatus.draft}', '${DocumentStatus.cancelled}')
      ''',
        [pid],
      );
      final productEarliestDocStr = productDocRows.isNotEmpty
          ? productDocRows.first['min_date'] as String?
          : null;

      final String movementDate;
      if (productEarliestDocStr != null && productEarliestDocStr.isNotEmpty) {
        // Document exists. Determine same-day or preceding calendar date:
        final docDatePart = productEarliestDocStr.length >= 10
            ? productEarliestDocStr.substring(0, 10)
            : productEarliestDocStr;
        final createdDatePart =
            (createdAtStr != null && createdAtStr.length >= 10)
            ? createdAtStr.substring(0, 10)
            : null;

        if (createdDatePart != null &&
            createdDatePart.compareTo(docDatePart) < 0) {
          // Authentic catalog creation date occurred on a calendar day before first transaction.
          movementDate = createdAtStr!;
        } else {
          // Opening stock belongs to the earliest document's calendar day.
          // Anchor to T00:00:00.000 on that same day, preserving timezone suffix.
          movementDate = _startOfCalendarDay(productEarliestDocStr);
        }
      } else if (createdAtStr != null && createdAtStr.isNotEmpty) {
        // Authentic catalog creation date exists with zero conflicting documents.
        movementDate = createdAtStr;
      } else {
        // No defensible historical date exists (NULL created_at and zero finalized documents).
        // Defer reconciliation for this product: preserve stock_quantity and unknown cost
        // without fabricating timestamps or substituting Unix epoch / migration time.
        continue;
      }

      await db.insert('stock_movements', {
        'product_id': pid,
        'type': StockMovement.typeOpening,
        'quantity': qty,
        'reference_document_id': null,
        'date': movementDate,
        'notes': 'Legacy opening stock reconciliation',
        'unit_cost': null,
        'total_cost': null,
        'cost_status': StockMovement.costStatusUnknown,
        'provenance': 'migration_legacy_opening',
      });
    }
  }

  /// Formats the start of the calendar day (T00:00:00.000) for a given ISO date string,
  /// preserving any explicit trailing timezone suffix ('Z', '+HH:MM', '-HH:MM').
  static String _startOfCalendarDay(String dateStr) {
    final trimmed = dateStr.trim();
    final tIdx = trimmed.indexOf('T');
    if (tIdx < 0) {
      return '${trimmed}T00:00:00.000';
    }
    final datePart = trimmed.substring(0, tIdx);
    final timeAndZone = trimmed.substring(tIdx + 1);

    String tzSuffix = '';
    if (timeAndZone.endsWith('Z')) {
      tzSuffix = 'Z';
    } else {
      final plusIdx = timeAndZone.indexOf('+');
      final minusIdx = timeAndZone.lastIndexOf('-');
      if (plusIdx >= 0) {
        tzSuffix = timeAndZone.substring(plusIdx);
      } else if (minusIdx >= 0) {
        tzSuffix = timeAndZone.substring(minusIdx);
      }
    }
    return '${datePart}T00:00:00.000$tzSuffix';
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

    // 5. Products: reconstruct current average cost for products with demonstrably
    // clean, solvent history. Otherwise, leave or mark as unknown.
    final products = await db.query(
      'products',
      columns: ['id', 'stock_quantity'],
    );
    for (final p in products) {
      final pid = p['id'] as int;
      final stock = (p['stock_quantity'] as num?)?.toDouble() ?? 0.0;
      if (stock <= 0) continue;

      final reconstructedAvg = await _reconstructProductCostBasis(
        db,
        pid,
        stock,
      );
      if (reconstructedAvg != null) {
        await db.update(
          'products',
          {
            'average_cost': reconstructedAvg,
            'cost_status': Product.costStatusKnown,
          },
          where: 'id = ?',
          whereArgs: [pid],
        );
      } else {
        await db.update(
          'products',
          {'average_cost': null, 'cost_status': Product.costStatusUnknown},
          where: 'id = ?',
          whereArgs: [pid],
        );
      }
    }

    // Historical invoice document_items repair is handled exclusively by
    // _repairInvoiceItemCosts in the v17 migration branch. This prevents legacy
    // step 6 from prematurely populating invoice costs with catalog averages
    // during a direct v14-to-v17 upgrade.
  }

  /// Safely replays stock movements for a product to compute its perpetual
  /// moving weighted-average cost.
  ///
  /// Invariants:
  /// 1. Replays costs only when the complete movement history is demonstrably clean,
  ///    solvent, and reconciles with physical stock.
  /// 2. If any movement has missing or unknown cost, returns null (indeterminate).
  ///    Zero-cost (0.0) is accepted ONLY when explicitly marked with cost_status='known'.
  ///    Negative costs are rejected.
  /// 3. If running stock drops below zero at any point, returns null (overselling / date ambiguity).
  /// 4. If purchase cancellation makes valuation negative (prevVal < removedCost), returns null (insolvent).
  /// 5. For sale cancellations (mQty > 0), preserves current runtime behavior (restores quantity
  ///    without applying an unverified weighted-average return policy).
  /// 6. If final replayed stock differs from physical stock_quantity, returns null (unexplained discrepancy).
  static Future<double?> _reconstructProductCostBasis(
    DatabaseExecutor db,
    int productId,
    double currentStock,
  ) async {
    if (currentStock <= 0) return null;

    final invalidOrUnknownCount =
        Sqflite.firstIntValue(
          await db.rawQuery(
            '''
      SELECT COUNT(*) FROM stock_movements
      WHERE product_id = ?
        AND (
          cost_status = '${StockMovement.costStatusUnknown}'
          OR cost_status IS NULL
          OR unit_cost IS NULL
          OR unit_cost < 0
          OR (unit_cost = 0 AND cost_status != '${StockMovement.costStatusKnown}')
        )
    ''',
            [productId],
          ),
        ) ??
        0;

    if (invalidOrUnknownCount > 0) return null;

    final movements = await db.rawQuery(
      '''
      SELECT id, type, quantity, unit_cost, total_cost, cost_status
      FROM stock_movements
      WHERE product_id = ?
      ORDER BY date ASC, id ASC
    ''',
      [productId],
    );

    if (movements.isEmpty) return null;

    // Temporal ordering invariant: verify movement IDs are monotonically
    // non-decreasing across the date-ordered sequence.
    // If an entry created later in real time (higher id) has an earlier date
    // than a previously created entry, a backdated insertion occurred and
    // chronological consistency cannot be proven unambiguously.
    int? prevId;
    for (final m in movements) {
      final mId = m['id'] as int;
      if (prevId != null && mId < prevId) {
        return null; // Ambiguous historical execution order: reject replay.
      }
      prevId = mId;
    }

    double runningStock = 0.0;
    double? runningAvg;

    for (final m in movements) {
      final mType = m['type'] as String;
      final mQty = (m['quantity'] as num).toDouble();
      final mCost = (m['unit_cost'] as num?)?.toDouble();
      final tCost = (m['total_cost'] as num?)?.toDouble();

      if (mType == StockMovement.typePurchase ||
          (mType == StockMovement.typeOpening && mQty > 0) ||
          (mType == StockMovement.typeAdjustment && mQty > 0)) {
        if (mCost == null || mCost < 0) return null;
        runningAvg = InventoryCostingService.calculateNewWeightedAverage(
          currentStock: runningStock,
          currentAvgCost: runningAvg,
          incomingQty: mQty,
          incomingUnitCost: mCost,
        );
        runningStock += mQty;
      } else if (mType == StockMovement.typeSale ||
          (mType == StockMovement.typeAdjustment && mQty < 0)) {
        runningStock += mQty; // mQty is negative
        if (runningStock < -0.0001) {
          // Historical negative stock: timeline is ambiguous or oversold
          return null;
        }
        if (runningStock.abs() <= 0.0001) {
          runningStock = 0.0;
          runningAvg = null;
        }
      } else if (mType == StockMovement.typeCancellation) {
        if (mQty > 0) {
          // Sale cancellation: restore quantity without applying a new return policy
          runningStock += mQty;
        } else if (mQty < 0) {
          // Purchase cancellation / reversal
          final removedQty = -mQty;
          final removedCost = tCost != null
              ? tCost.abs()
              : (removedQty * (mCost ?? 0.0));
          final newStock = runningStock - removedQty;
          if (newStock < -0.0001) {
            return null;
          }
          if (newStock.abs() <= 0.0001) {
            runningStock = 0.0;
            runningAvg = null;
          } else {
            final prevVal = runningStock * (runningAvg ?? 0.0);
            if (prevVal - removedCost < -0.001) {
              // Insolvent valuation: subsequent transactions consumed the purchase value
              return null;
            }
            final remainVal = (prevVal - removedCost).clamp(
              0.0,
              double.infinity,
            );
            runningAvg = remainVal / newStock;
            runningStock = newStock;
          }
        }
      } else {
        // Unknown movement type
        return null;
      }
    }

    // Final reconciliation check: movement net sum must explain physical stock
    if ((runningStock - currentStock).abs() > 0.01) {
      return null;
    }
    if (runningAvg == null || runningAvg < 0) {
      return null;
    }

    return runningAvg;
  }

  /// Migration v20: Narrow, fail-safe repair of historical product average_cost.
  ///
  /// Targets candidate products with evidence of legacy migration defects:
  /// - Products with cancellations, adjustments, or legacy opening stock (from v18 or pre-v15).
  /// - Products with average_cost populated despite having unknown-cost movements.
  ///
  /// Invariants:
  /// - Replays only when temporal monotonicity and solvent history are proven.
  /// - If reconstruction fails due to temporal ambiguity, preserves existing live-maintained cost.
  /// - Sets average_cost = NULL and cost_status = 'unknown' ONLY when concrete evidence
  ///   of a defect exists (e.g. populated average_cost with unknown-cost movements).
  /// - Preserves physical stock_quantity.
  /// - Does NOT modify movements, documents, document_items, or document_payments.
  static Future<void> _repairLegacyCostingReplay(DatabaseExecutor db) async {
    final candidateProducts = await db.rawQuery('''
      SELECT p.id, p.stock_quantity, p.average_cost, p.cost_status,
        CASE WHEN EXISTS (
          SELECT 1 FROM stock_movements sm_unk
          WHERE sm_unk.product_id = p.id
            AND (
              sm_unk.cost_status = '${StockMovement.costStatusUnknown}'
              OR sm_unk.cost_status IS NULL
              OR sm_unk.unit_cost IS NULL
              OR sm_unk.unit_cost < 0
              OR (sm_unk.unit_cost = 0 AND sm_unk.cost_status != '${StockMovement.costStatusKnown}')
            )
        ) THEN 1 ELSE 0 END AS has_unknown_movements
      FROM products p
      WHERE (p.type = 'product' OR p.type IS NULL)
        AND p.stock_quantity > 0.0001
        AND (
          EXISTS (
            SELECT 1 FROM stock_movements sm
            WHERE sm.product_id = p.id
              AND (
                sm.type IN ('${StockMovement.typeCancellation}', '${StockMovement.typeAdjustment}')
                OR sm.provenance IN ('legacy_opening', 'migration_legacy_opening')
              )
          )
          OR (
            p.average_cost IS NOT NULL AND EXISTS (
              SELECT 1 FROM stock_movements sm_unk
              WHERE sm_unk.product_id = p.id
                AND (
                  sm_unk.cost_status = '${StockMovement.costStatusUnknown}'
                  OR sm_unk.cost_status IS NULL
                  OR sm_unk.unit_cost IS NULL
                  OR sm_unk.unit_cost < 0
                  OR (sm_unk.unit_cost = 0 AND sm_unk.cost_status != '${StockMovement.costStatusKnown}')
                )
            )
          )
        )
    ''');

    if (candidateProducts.isEmpty) return;

    for (final cp in candidateProducts) {
      final pid = cp['id'] as int;
      final stock = (cp['stock_quantity'] as num).toDouble();
      final currentAvg = (cp['average_cost'] as num?)?.toDouble();
      final currentStatus =
          cp['cost_status'] as String? ?? Product.costStatusUnknown;
      final hasProvenDefect = (cp['has_unknown_movements'] as int? ?? 0) == 1;

      final reconstructed = await _reconstructProductCostBasis(db, pid, stock);

      if (reconstructed != null) {
        if (currentAvg == null ||
            (currentAvg - reconstructed).abs() > 0.0001 ||
            currentStatus != Product.costStatusKnown) {
          await db.update(
            'products',
            {
              'average_cost': reconstructed,
              'cost_status': Product.costStatusKnown,
            },
            where: 'id = ?',
            whereArgs: [pid],
          );
        }
      } else if (hasProvenDefect) {
        // Concrete evidence of defect (average_cost populated despite unknown movements):
        // safely mark unknown, preserving physical stock_quantity.
        if (currentAvg != null || currentStatus != Product.costStatusUnknown) {
          await db.update(
            'products',
            {'average_cost': null, 'cost_status': Product.costStatusUnknown},
            where: 'id = ?',
            whereArgs: [pid],
          );
        }
      }
      // If reconstructed == null due to temporal ambiguity without a proven defect,
      // preserve the existing live-maintained average_cost and cost_status.
    }
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
          AND (cost_status = '${StockMovement.costStatusUnknown}' OR cost_status IS NULL OR unit_cost IS NULL OR unit_cost < 0 OR (unit_cost = 0 AND cost_status != '${StockMovement.costStatusKnown}'))
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
            AND unit_cost >= 0
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
    AccessGuard.require(PermissionRegistry.settingsManage);
    final db = await database;
    final map = b.toMap();
    map['updated_by'] = AccessContext.currentUserId;
    return db.insert('businesses', map);
  }

  Future<Business?> getFirstBusiness({DatabaseExecutor? txn}) async {
    final exec = txn ?? (await database);
    final maps = await exec.query('businesses', limit: 1);
    if (maps.isEmpty) return null;
    return Business.fromMap(maps.first);
  }

  Future<bool> isCurrencyLocked() async {
    final db = await database;
    final b = await getFirstBusiness();
    if (b == null) return false;
    return _isCurrencyLockedTxn(db, b);
  }

  Future<int> updateBusiness(Business b) async {
    AccessGuard.require(PermissionRegistry.settingsManage);
    final db = await database;
    return db.transaction((txn) async {
      final currentRows = await txn.query(
        'businesses',
        where: 'id = ?',
        whereArgs: [b.id],
        limit: 1,
      );
      if (currentRows.isEmpty) return 0;

      final current = Business.fromMap(currentRows.first);
      if (current.currencyCode != b.currencyCode) {
        if (await ReferencePricingDao.blocksBaseCurrencyChange(txn)) {
          throw const ReferencePricingException(
            ReferencePricingError.baseCurrencyChangeBlocked,
            'Base currency cannot be changed when exchange rates or reference products exist.',
          );
        }
        final isLocked = await _isCurrencyLockedTxn(txn, current);
        if (isLocked) {
          throw StateError(
            'Business currency is permanent and cannot be modified after '
            'financial transactions or stock movements are recorded.',
          );
        }
      }

      final map = b.toMap();
      map['updated_by'] = AccessContext.currentUserId;
      return txn.update('businesses', map, where: 'id = ?', whereArgs: [b.id]);
    });
  }

  // ========== Digital Seals (Stamps & Signatures) ==========

  Future<void> insertDigitalAsset(
    DigitalSealAsset asset, {
    DatabaseExecutor? txn,
  }) async {
    final exec = txn ?? (await database);
    await exec.insert(
      'digital_assets',
      asset.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DigitalSealAsset?> getDigitalAsset(
    String id, {
    int? businessId,
    DatabaseExecutor? txn,
  }) async {
    final exec = txn ?? (await database);
    final whereClause = businessId != null
        ? 'id = ? AND business_id = ?'
        : 'id = ?';
    final whereArgs = businessId != null ? [id, businessId] : [id];
    final rows = await exec.query(
      'digital_assets',
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DigitalSealAsset.fromMap(rows.first);
  }

  Future<List<DigitalSealAsset>> getDigitalAssetsForBusiness(
    int businessId, {
    SealType? type,
    bool includeDeleted = false,
    DatabaseExecutor? txn,
  }) async {
    final exec = txn ?? (await database);
    String where = 'business_id = ?';
    final args = <dynamic>[businessId];
    if (type != null) {
      where += ' AND type = ?';
      args.add(type.name);
    }
    if (!includeDeleted) {
      where += ' AND is_deleted = 0';
    }
    final rows = await exec.query(
      'digital_assets',
      where: where,
      whereArgs: args,
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => DigitalSealAsset.fromMap(r)).toList();
  }

  Future<void> softDeleteDigitalAsset(
    String id, {
    required int businessId,
    DatabaseExecutor? txn,
  }) async {
    final exec = txn ?? (await database);
    await exec.update(
      'digital_assets',
      {'is_deleted': 1},
      where: 'id = ? AND business_id = ?',
      whereArgs: [id, businessId],
    );
  }

  Future<DigitalSealConfig?> getBusinessSealConfig(
    int businessId,
    SealType type, {
    DatabaseExecutor? txn,
  }) async {
    final exec = txn ?? (await database);
    final rows = await exec.query(
      'business_seal_configs',
      where: 'business_id = ? AND seal_type = ?',
      whereArgs: [businessId, type.name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DigitalSealConfig.fromMap(rows.first, type);
  }

  Future<void> saveBusinessSealConfig(
    int businessId,
    DigitalSealConfig config, {
    DatabaseExecutor? txn,
  }) async {
    final exec = txn ?? (await database);
    if (config.assetId != null && config.assetId!.isNotEmpty) {
      final assetRows = await exec.query(
        'digital_assets',
        columns: ['id'],
        where: 'id = ? AND business_id = ?',
        whereArgs: [config.assetId, businessId],
        limit: 1,
      );
      if (assetRows.isEmpty) {
        throw ArgumentError(
          'Security violation: Asset (${config.assetId}) does not belong to business ($businessId).',
        );
      }
    }

    final map = config.toMap();
    map['business_id'] = businessId;
    map['updated_at'] = DateTime.now().toIso8601String();

    await exec.insert(
      'business_seal_configs',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DocumentSealSnapshot?> getDocumentSealSnapshot(
    int documentId, {
    DatabaseExecutor? txn,
  }) async {
    final exec = txn ?? (await database);
    final rows = await exec.query(
      'document_seal_snapshots',
      where: 'document_id = ?',
      whereArgs: [documentId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DocumentSealSnapshot.fromRow(rows.first);
  }

  Future<void> captureDocumentSealSnapshotTxn(
    DatabaseExecutor txn, {
    required int documentId,
    required int businessId,
  }) async {
    final existing = await txn.query(
      'document_seal_snapshots',
      columns: ['id'],
      where: 'document_id = ?',
      whereArgs: [documentId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return; // Immutable: never overwrite historical snapshot
    }

    final configs = await txn.query(
      'business_seal_configs',
      where: 'business_id = ? AND is_enabled = 1 AND asset_id IS NOT NULL',
      whereArgs: [businessId],
    );

    DigitalSealConfig? stampConfig;
    DigitalSealConfig? sigConfig;
    final referencedAssetIds = <String>[];

    for (final row in configs) {
      final typeStr = row['seal_type'] as String?;
      final assetId = row['asset_id'] as String?;
      if (assetId == null || assetId.isEmpty) continue;

      final assetRows = await txn.query(
        'digital_assets',
        columns: ['id', 'width', 'height'],
        where: 'id = ? AND business_id = ?',
        whereArgs: [assetId, businessId],
        limit: 1,
      );
      if (assetRows.isEmpty) continue;

      final config = DigitalSealConfig.fromMap(row);
      if (typeStr == SealType.stamp.name) {
        stampConfig = config;
        referencedAssetIds.add(assetId);
      } else if (typeStr == SealType.signature.name) {
        sigConfig = config;
        referencedAssetIds.add(assetId);
      }
    }

    if (stampConfig == null && sigConfig == null) {
      return;
    }

    final now = DateTime.now();
    final snapshotJson = DocumentSealSnapshot.serializeData(
      businessId: businessId,
      issuedAt: now,
      stamp: stampConfig,
      signature: sigConfig,
    );

    final snapshotId = await txn.insert('document_seal_snapshots', {
      'document_id': documentId,
      'business_id': businessId,
      'snapshot_data': snapshotJson,
      'created_at': now.toIso8601String(),
    });

    for (final assetId in referencedAssetIds) {
      await txn.insert('document_seal_snapshot_assets', {
        'snapshot_id': snapshotId,
        'asset_id': assetId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<int> cleanupUnreferencedAssets({
    int? businessId,
    DatabaseExecutor? txn,
  }) async {
    final exec = txn ?? (await database);
    String where = 'is_deleted = 1';
    final args = <dynamic>[];
    if (businessId != null) {
      where += ' AND business_id = ?';
      args.add(businessId);
    }

    final candidates = await exec.query(
      'digital_assets',
      columns: ['id', 'filename'],
      where: where,
      whereArgs: args.isEmpty ? null : args,
    );

    int deletedCount = 0;
    for (final c in candidates) {
      final assetId = c['id'] as String;
      final filename = c['filename'] as String;

      final configRefRows = await exec.rawQuery(
        'SELECT COUNT(*) as c FROM business_seal_configs WHERE asset_id = ?',
        [assetId],
      );
      final configRefs = Sqflite.firstIntValue(configRefRows) ?? 0;
      if (configRefs > 0) continue;

      final snapshotRefRows = await exec.rawQuery(
        'SELECT COUNT(*) as c FROM document_seal_snapshot_assets WHERE asset_id = ?',
        [assetId],
      );
      final snapshotRefs = Sqflite.firstIntValue(snapshotRefRows) ?? 0;
      if (snapshotRefs > 0) continue;

      await DigitalSealStorageService.deleteAssetFile(filename);
      await exec.delete(
        'digital_assets',
        where: 'id = ?',
        whereArgs: [assetId],
      );
      deletedCount++;
    }
    return deletedCount;
  }

  // ========== Contacts ==========
  Future<int> insertContact(Contact c) async {
    AccessGuard.require(PermissionRegistry.contactsManage);
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final map = c.toMap();
    map['created_at'] ??= now;
    map['updated_at'] ??= now;
    map['created_by'] ??= AccessContext.currentUserId;
    map['updated_by'] ??= AccessContext.currentUserId;
    map['origin_device_id'] ??= AccessContext.currentDeviceId;
    return db.insert('contacts', map);
  }

  Future<int> updateContact(Contact c) async {
    AccessGuard.require(PermissionRegistry.contactsManage);
    final db = await database;
    final map = c.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();
    map['updated_by'] = AccessContext.currentUserId;
    return db.update('contacts', map, where: 'id = ?', whereArgs: [c.id]);
  }

  Future<int> countContactDocuments(int id) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM documents WHERE contact_id = ?',
      [id],
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<int> deleteContact(int id) async {
    AccessGuard.require(PermissionRegistry.contactsDelete);
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.rawQuery(
        'SELECT COUNT(*) AS c FROM documents WHERE contact_id = ?',
        [id],
      );
      final count = (rows.first['c'] as num?)?.toInt() ?? 0;
      if (count > 0) {
        throw StateError('Cannot delete contact referenced in documents');
      }
      return txn.delete('contacts', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> setContactActive(int id, {required bool active}) async {
    AccessGuard.require(PermissionRegistry.contactsManage);
    final db = await database;
    await db.update(
      'contacts',
      {
        'active': active ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': AccessContext.currentUserId,
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
    final normalizedQuery = ArabicSearchUtils.normalize(query);
    final normName = ArabicSearchUtils.sqlNormalize('name');
    String where = '($normName LIKE ? OR phone LIKE ?)';
    final args = ['%$normalizedQuery%', '%$normalizedQuery%'];
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

  /// Returns outstanding balances grouped by currency code for a given contact and docType.
  /// Never sums amounts across distinct currencies into one nominal total.
  Future<Map<String, double>> getContactOutstandingByCurrency(
    int contactId,
    String docType,
  ) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT currency_code, COALESCE(SUM(remaining), 0) AS outstanding
      FROM documents
      WHERE contact_id = ? AND type = ? AND status NOT IN ('${DocumentStatus.draft}', '${DocumentStatus.cancelled}')
      GROUP BY currency_code
      HAVING outstanding > 0
    ''',
      [contactId, docType],
    );
    final map = <String, double>{};
    for (final r in rows) {
      final code = (r['currency_code'] as String?) ?? 'SDG';
      final val = (r['outstanding'] as num?)?.toDouble() ?? 0.0;
      if (val > 0) {
        map[code] = val;
      }
    }
    return map;
  }

  // ========== Products ==========
  Future<int> _insertProductTxn(DatabaseExecutor txn, Product p) async {
    p = await ReferencePricingDao.deriveProduct(txn, p);
    final hasKnownCost =
        p.isProduct && p.stockQuantity > 0 && p.purchasePrice > 0;
    final avgCost = hasKnownCost ? p.purchasePrice : null;
    final costStatus = hasKnownCost
        ? Product.costStatusKnown
        : Product.costStatusUnknown;

    final pMap = p.toMap();
    pMap['average_cost'] = avgCost;
    pMap['cost_status'] = costStatus;
    pMap['created_by'] ??= AccessContext.currentUserId;
    pMap['updated_by'] ??= AccessContext.currentUserId;
    pMap['origin_device_id'] ??= AccessContext.currentDeviceId;

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
  }

  Future<int> _updateProductTxn(
    DatabaseExecutor txn,
    Product p, {
    required bool allowClearReferencePricing,
  }) async {
    final existingRows = await txn.query(
      'products',
      columns: ['stock_quantity', 'type', 'price_currency'],
      where: 'id = ?',
      whereArgs: [p.id],
    );
    String? previous;
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
      previous = existingRows.first['price_currency'] as String?;
    }

    if (previous != null &&
        p.priceCurrency == null &&
        !allowClearReferencePricing) {
      throw const ReferencePricingException(
        ReferencePricingError.implicitClear,
        'Cannot clear reference pricing implicitly without allowClearReferencePricing flag',
      );
    }

    p = await ReferencePricingDao.deriveProduct(
      txn,
      p,
      previousCurrency: previous,
    );

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
    map['updated_by'] = AccessContext.currentUserId;

    final count = await txn.update(
      'products',
      map,
      where: 'id = ?',
      whereArgs: [p.id],
    );

    if (previous != p.priceCurrency && p.id != null) {
      await ReferencePricingDao.clearUnitReferences(txn, p.id!);
    }

    return count;
  }

  Future<int> insertProduct(Product p) async {
    AccessGuard.require(PermissionRegistry.productsManage);
    final db = await database;
    final id = await db.transaction((txn) => _insertProductTxn(txn, p));
    CatalogEvents.notifyPricesChanged();
    return id;
  }

  Future<int> updateProduct(
    Product p, {
    bool allowClearReferencePricing = false,
  }) async {
    AccessGuard.require(PermissionRegistry.productsManage);
    final db = await database;
    final count = await db.transaction(
      (txn) => _updateProductTxn(
        txn,
        p,
        allowClearReferencePricing: allowClearReferencePricing,
      ),
    );
    CatalogEvents.notifyPricesChanged();
    return count;
  }

  /// Atomically saves a product and its units in a single transaction.
  ///
  /// Replaces separate insert/update and syncProductUnits calls.
  Future<int> saveProductWithUnits(
    Product p,
    List<ProductUnit> units, {
    bool allowClearReferencePricing = false,
  }) async {
    AccessGuard.require(PermissionRegistry.productsManage);
    final db = await database;
    final productId = await db.transaction<int>((txn) async {
      final int id;
      if (p.id == null) {
        id = await _insertProductTxn(txn, p);
      } else {
        await _updateProductTxn(
          txn,
          p,
          allowClearReferencePricing: allowClearReferencePricing,
        );
        id = p.id!;
      }
      await _syncProductUnitsTxn(txn, id, units);
      return id;
    });
    CatalogEvents.notifyPricesChanged();
    return productId;
  }

  /// Returns whether any exchange rates are registered.
  Future<bool> hasExchangeRates() async {
    final db = await database;
    return ReferencePricingDao.hasAnyRate(db);
  }

  Future<int> deleteProduct(int id) async {
    AccessGuard.require(PermissionRegistry.productsDelete);
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
      final moveRows = await txn.query(
        'stock_movements',
        columns: ['id'],
        where: 'product_id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (moveRows.isNotEmpty) {
        throw StateError('Cannot delete product with stock history');
      }
      return txn.delete('products', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<bool> isProductReferenced(int id) async {
    final db = await database;
    final docRows = await db.query(
      'document_items',
      columns: ['id'],
      where: 'product_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (docRows.isNotEmpty) return true;
    final moveRows = await db.query(
      'stock_movements',
      columns: ['id'],
      where: 'product_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return moveRows.isNotEmpty;
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
    final normalizedQuery = ArabicSearchUtils.normalize(query);
    final normName = ArabicSearchUtils.sqlNormalize('name');
    final conditions = <String>[
      '($normName LIKE ? OR code LIKE ? OR barcode LIKE ?)',
    ];
    final args = <Object?>[
      '%$normalizedQuery%',
      '%$normalizedQuery%',
      '%$normalizedQuery%',
    ];
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
      "SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND TRIM(category) != '' ORDER BY category",
    );
    return results.map((r) => r['category'] as String).toList();
  }

  Future<List<Product>> searchActiveProducts(
    String query, {
    int limit = 10,
  }) async {
    final db = await database;
    final normalizedQuery = ArabicSearchUtils.normalize(query);
    final normName = ArabicSearchUtils.sqlNormalize('name');
    final maps = await db.query(
      'products',
      where:
          '($normName LIKE ? OR code LIKE ? OR barcode LIKE ?) AND is_active = 1',
      whereArgs: [
        '%$normalizedQuery%',
        '%$normalizedQuery%',
        '%$normalizedQuery%',
      ],
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

  Future<Product?> getProductByCode(String code) async {
    final db = await database;
    final normalized = code.trim();
    if (normalized.isEmpty) return null;
    final maps = await db.query(
      'products',
      where: 'TRIM(code) = ? AND is_active = 1',
      whereArgs: [normalized],
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
    AccessGuard.require(PermissionRegistry.productsManage);
    final db = await database;
    await db.update(
      'products',
      {'is_active': active ? 1 : 0, 'updated_by': AccessContext.currentUserId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== Product Units ==========
  Future<Map<int, List<ProductUnit>>> getAllProductUnits() async {
    final db = await database;
    final rows = await db.query(
      'product_units',
      orderBy: 'is_default_sale DESC, id ASC',
    );
    final map = <int, List<ProductUnit>>{};
    for (final r in rows) {
      final u = ProductUnit.fromMap(r);
      map.putIfAbsent(u.productId, () => []).add(u);
    }
    return map;
  }

  Future<List<ProductUnit>> getProductUnits(int productId) async {
    final db = await database;
    final rows = await db.query(
      'product_units',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'is_default_sale DESC, id ASC',
    );
    return rows.map((r) => ProductUnit.fromMap(r)).toList();
  }

  Future<int> _insertProductUnitTxn(
    DatabaseExecutor txn,
    ProductUnit unit,
  ) async {
    if (unit.conversionFactor <= 0) {
      throw ArgumentError('Conversion factor must be greater than zero');
    }
    if (unit.unitName.trim().isEmpty) {
      throw ArgumentError('Unit name cannot be empty');
    }
    final prodRows = await txn.query(
      'products',
      columns: ['price_currency'],
      where: 'id = ?',
      whereArgs: [unit.productId],
      limit: 1,
    );
    final productCurrency = prodRows.isNotEmpty
        ? prodRows.first['price_currency'] as String?
        : null;

    final normalized = await ReferencePricingDao.normalizeUnit(
      txn,
      productCurrency: productCurrency,
      unit: unit,
    );
    return await txn.insert('product_units', normalized.toMap());
  }

  Future<int> insertProductUnit(ProductUnit unit) async {
    final db = await database;
    final id = await db.transaction((txn) => _insertProductUnitTxn(txn, unit));
    CatalogEvents.notifyPricesChanged();
    return id;
  }

  Future<int> _updateProductUnitTxn(
    DatabaseExecutor txn,
    ProductUnit unit,
  ) async {
    if (unit.id == null) throw ArgumentError('Unit id required for update');
    if (unit.conversionFactor <= 0) {
      throw ArgumentError('Conversion factor must be greater than zero');
    }
    if (unit.unitName.trim().isEmpty) {
      throw ArgumentError('Unit name cannot be empty');
    }
    final prodRows = await txn.query(
      'products',
      columns: ['price_currency'],
      where: 'id = ?',
      whereArgs: [unit.productId],
      limit: 1,
    );
    final productCurrency = prodRows.isNotEmpty
        ? prodRows.first['price_currency'] as String?
        : null;

    final normalized = await ReferencePricingDao.normalizeUnit(
      txn,
      productCurrency: productCurrency,
      unit: unit,
    );
    return await txn.update(
      'product_units',
      normalized.toMap(),
      where: 'id = ?',
      whereArgs: [unit.id],
    );
  }

  Future<int> updateProductUnit(ProductUnit unit) async {
    final db = await database;
    final count = await db.transaction(
      (txn) => _updateProductUnitTxn(txn, unit),
    );
    CatalogEvents.notifyPricesChanged();
    return count;
  }

  Future<int> deleteProductUnit(int id) async {
    final db = await database;
    return await db.delete('product_units', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _syncProductUnitsTxn(
    DatabaseExecutor txn,
    int productId,
    List<ProductUnit> units,
  ) async {
    final prodRows = await txn.query(
      'products',
      columns: ['price_currency'],
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    final productCurrency = prodRows.isNotEmpty
        ? prodRows.first['price_currency'] as String?
        : null;

    await txn.delete(
      'product_units',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
    for (final rawUnit in units) {
      if (rawUnit.conversionFactor <= 0) {
        throw ArgumentError('Conversion factor must be greater than zero');
      }
      if (rawUnit.unitName.trim().isEmpty) {
        throw ArgumentError('Unit name cannot be empty');
      }
      final u = await ReferencePricingDao.normalizeUnit(
        txn,
        productCurrency: productCurrency,
        unit: rawUnit,
      );
      final map = u.toMap();
      map['product_id'] = productId;
      map.remove('id');
      await txn.insert('product_units', map);
    }
  }

  Future<void> syncProductUnits(int productId, List<ProductUnit> units) async {
    final db = await database;
    await db.transaction((txn) => _syncProductUnitsTxn(txn, productId, units));
    CatalogEvents.notifyPricesChanged();
  }

  // ========== Stock Movements ==========
  /// Validates that sufficient physical inventory is available for sale items.
  ///
  /// Aggregates required base quantities across all lines by product ID.
  /// If [documentId] is provided (e.g. during an update), any existing sale
  /// movements previously deducted by that document are added back to current
  /// stock to calculate true available stock before new writes occur.
  Future<void> _assertSaleStockAvailable(
    DatabaseExecutor txn,
    Iterable<dynamic> items, {
    int? documentId,
  }) async {
    final Map<int, double> requiredBaseQtyByProduct = {};
    for (final raw in items) {
      final int? productId;
      final double qty;
      final double effectiveBaseQty;
      if (raw is DocumentItem) {
        productId = raw.productId;
        qty = raw.quantity;
        effectiveBaseQty = raw.effectiveBaseQuantity;
      } else if (raw is Map<String, dynamic>) {
        productId = raw['product_id'] as int?;
        qty = (raw['quantity'] as num?)?.toDouble() ?? 0.0;
        effectiveBaseQty =
            (raw['base_quantity'] as num?)?.toDouble() ??
            (qty *
                ((raw['unit_conversion_factor'] as num?)?.toDouble() ?? 1.0));
      } else {
        continue;
      }

      if (productId == null || qty <= 0 || effectiveBaseQty <= 0) continue;
      requiredBaseQtyByProduct[productId] =
          (requiredBaseQtyByProduct[productId] ?? 0.0) + effectiveBaseQty;
    }

    if (requiredBaseQtyByProduct.isEmpty) return;

    final Map<int, double> previouslyDeductedByProduct = {};
    if (documentId != null) {
      final oldMovements = await txn.query(
        'stock_movements',
        where: 'reference_document_id = ? AND type = ?',
        whereArgs: [documentId, StockMovement.typeSale],
      );
      for (final m in oldMovements) {
        final pId = m['product_id'] as int?;
        final mQty = (m['quantity'] as num?)?.toDouble() ?? 0.0;
        if (pId != null && mQty < 0) {
          previouslyDeductedByProduct[pId] =
              (previouslyDeductedByProduct[pId] ?? 0.0) + (-mQty);
        }
      }
    }

    for (final entry in requiredBaseQtyByProduct.entries) {
      final productId = entry.key;
      final requiredBaseQty = entry.value;

      final pRows = await txn.query(
        'products',
        columns: ['name', 'type', 'stock_quantity'],
        where: 'id = ?',
        whereArgs: [productId],
      );
      if (pRows.isEmpty) continue;
      final pType = pRows.first['type'] as String? ?? 'product';
      if (pType != 'product') continue;

      final currentStock =
          (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0.0;
      final previouslyDeducted = previouslyDeductedByProduct[productId] ?? 0.0;
      final availableStock = currentStock + previouslyDeducted;

      if (requiredBaseQty - availableStock > 1e-9) {
        final name = pRows.first['name'] as String? ?? '';
        throw StateError(
          'Insufficient stock for "$name": available ${FormatUtils.formatQuantity(availableStock)}, required ${FormatUtils.formatQuantity(requiredBaseQty)}',
        );
      }
    }
  }

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
    String? reason,
    int? targetMovementId,
  }) async {
    await StockLedger.record(
      txn,
      productId: productId,
      deltaQuantity: quantity,
      type: type,
      referenceDocumentId: referenceDocumentId,
      notes: notes,
      unitCost: unitCost,
      totalCost: totalCost,
      costStatus: costStatus,
      provenance: provenance,
      date: date,
      reason: reason,
      targetMovementId: targetMovementId,
      skipProductUpdate: true, // Product row managed by calling context
    );
  }

  Future<List<StockMovement>> getStockMovements(int productId) async {
    final db = await database;
    const sql = '''
      SELECT sm.*, p.name AS product_name, p.unit AS product_unit,
             d.document_number AS reference_document_number,
             d.type AS reference_document_type
      FROM stock_movements sm
      LEFT JOIN products p ON sm.product_id = p.id
      LEFT JOIN documents d ON sm.reference_document_id = d.id
      WHERE sm.product_id = ?
      ORDER BY sm.date DESC, sm.id DESC
    ''';
    final maps = await db.rawQuery(sql, [productId]);
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
      SELECT sm.*, p.name AS product_name, p.unit AS product_unit,
             d.document_number AS reference_document_number,
             d.type AS reference_document_type
      FROM stock_movements sm
      LEFT JOIN products p ON sm.product_id = p.id
      LEFT JOIN documents d ON sm.reference_document_id = d.id
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
    String? reason,
    DateTime? date,
  }) async {
    AccessGuard.require(PermissionRegistry.stockAdjust);
    final adjDate = date ?? DateTime.now();
    final db = await database;
    await db.transaction((txn) async {
      await assertPeriodOpen(adjDate, txn: txn);
      await InventoryCostingService.onStockAdjusted(
        txn,
        productId: productId,
        delta: delta,
        notes: notes,
        reason: reason,
        date: adjDate,
      );
      await logAuditEvent(
        'stock_adjusted',
        entityType: 'product',
        entityId: productId,
        details:
            'delta=$delta${reason != null ? " reason=$reason" : ""}${notes != null ? " notes=$notes" : ""}',
        txn: txn,
      );
    });
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
      final bRows = await txn.query('businesses', limit: 1);
      final baseCurrency = bRows.isNotEmpty
          ? (bRows.first['currency_code'] as String? ?? 'SDG')
          : 'SDG';
      if (doc.currencyCode != baseCurrency) {
        throw ArgumentError(
          'Document currency (${doc.currencyCode}) must match business base currency ($baseCurrency).',
        );
      }

      await assertPeriodOpen(doc.date, txn: txn);

      if (doc.type == 'purchase') {
        AccessGuard.require(PermissionRegistry.purchasesCreate);
      } else if (doc.type == 'payment_receipt' ||
          doc.type == 'expense_voucher') {
        AccessGuard.require(PermissionRegistry.vouchersCreate);
      } else {
        AccessGuard.require(PermissionRegistry.salesCreate);
      }

      int? contactId = doc.contactId;
      if (contact != null) {
        contactId = contact.id ?? await txn.insert('contacts', contact.toMap());
      }

      final docNumber = await getNextDocumentNumber(txn, doc.type);
      var newDoc = Document(
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

      Map<String, dynamic> buildDocMap(Document d) {
        final m = d.toMap();
        m['created_by'] ??= AccessContext.currentUserId;
        m['updated_by'] ??= AccessContext.currentUserId;
        m['origin_device_id'] ??= AccessContext.currentDeviceId;
        return m;
      }

      int docId;
      try {
        docId = await txn.insert('documents', buildDocMap(newDoc));
      } on DatabaseException catch (e) {
        if (e.isUniqueConstraintError() ||
            e.toString().toLowerCase().contains('unique')) {
          final retryNumber = await getNextDocumentNumber(txn, doc.type);
          newDoc = newDoc.copyWith(documentNumber: retryNumber);
          docId = await txn.insert('documents', buildDocMap(newDoc));
        } else {
          rethrow;
        }
      }
      final isDraft = doc.status == DocumentStatus.draft;
      if (!isDraft || doc.paid > 0) {
        await _lockCurrencyTxn(txn);
      }

      // Pre-check stock availability for non-draft invoices
      if (doc.type == 'invoice' && !isDraft && strictStock) {
        await _assertSaleStockAvailable(txn, items);
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

              final effectiveBaseQty = item.effectiveBaseQuantity;
              final double deductQty;
              if (strictStock) {
                deductQty = effectiveBaseQty;
              } else {
                deductQty = currentStock > 0
                    ? (currentStock >= effectiveBaseQty
                          ? effectiveBaseQty
                          : currentStock)
                    : 0.0;
              }
              final bool isFullyBacked = deductQty >= effectiveBaseQty;
              if (deductQty > 0) {
                // If stock was partially oversold, cost for the whole line is incomplete
                // and must NOT be marked as fully trusted on document_items.
                itemUnitCost = (isCostKnown && isFullyBacked) ? avgCost : null;
                itemTotalCost = (isCostKnown && isFullyBacked)
                    ? effectiveBaseQty * avgCost
                    : null;
                final movementCost = isCostKnown ? deductQty * avgCost : null;
                final movementCostStatus = isCostKnown
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
              if (priorCostStatus == Product.costStatusKnown) {
                newAvgCost =
                    InventoryCostingService.calculateNewWeightedAverage(
                      currentStock: currentStock,
                      currentAvgCost: currentAvg,
                      incomingQty: incomingQty,
                      incomingUnitCost: incomingUnitCost,
                    );
                newCostStatus = Product.costStatusKnown;
              } else if (currentStock <= 0) {
                final movementSumRows = await txn.rawQuery(
                  'SELECT COALESCE(SUM(quantity), 0) AS total_qty FROM stock_movements WHERE product_id = ?',
                  [item.productId],
                );
                final movementTotal =
                    (movementSumRows.first['total_qty'] as num).toDouble();
                final isCleanLedger =
                    (movementTotal - currentStock).abs() <= 0.001 &&
                    movementTotal >= -0.0001;

                final unknownCostRows = await txn.rawQuery(
                  "SELECT 1 FROM stock_movements WHERE product_id = ? AND (cost_status != '${StockMovement.costStatusKnown}' OR unit_cost IS NULL) LIMIT 1",
                  [item.productId],
                );
                final hasUnknownHistory = unknownCostRows.isNotEmpty;

                if (isCleanLedger && !hasUnknownHistory) {
                  newAvgCost = incomingUnitCost;
                  newCostStatus = Product.costStatusKnown;
                } else {
                  newAvgCost = incomingUnitCost;
                  newCostStatus = Product.costStatusUnknown;
                }
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
          'pricing_category': item.pricingCategory,
          'sale_unit': item.saleUnit,
          'unit_conversion_factor': item.unitConversionFactor,
          'base_quantity': item.effectiveBaseQuantity,
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
        await _insertDocumentPaymentTxn(txn, {
          'document_id': docId,
          'amount': doc.paid,
          'payment_method': doc.paymentMethod,
          'date': doc.date.toIso8601String(),
          'notes': doc.type == 'invoice'
              ? 'Initial payment'
              : 'Initial purchase payment',
          'receipt_document_id': null,
          'payment_origin': PaymentOrigin.upfront,
        });
      }

      final itemRows = await txn.query(
        'document_items',
        where: 'document_id = ?',
        whereArgs: [docId],
      );
      final persistedItems = itemRows.map(DocumentItem.fromMap).toList();

      final insertedDoc = newDoc.copyWith(id: docId);
      if (newDoc.type == 'payment_receipt' ||
          newDoc.type == 'expense_voucher') {
        if (contactId != null) {
          await _allocateVoucherFifoTxn(txn, insertedDoc);
        }
      }
      await JournalWriter.postDocumentIssued(txn, insertedDoc, persistedItems);

      if (!isDraft) {
        final businessId = bRows.isNotEmpty
            ? (bRows.first['id'] as int? ?? 1)
            : 1;
        await captureDocumentSealSnapshotTxn(
          txn,
          documentId: docId,
          businessId: businessId,
        );
      }

      return docId;
    });
  }

  /// Authoritative single delta routine for stock movements on document edits.
  /// Computes and applies per-product delta between old and new effective quantities
  /// (and costs for purchases) atomically. Metadata-only edits produce zero movements.
  Future<void> _applyDocumentEditStockDeltas(
    DatabaseExecutor txn, {
    required Document oldDoc,
    required Document newDoc,
    required List<Map<String, dynamic>> oldItems,
    required List<DocumentItem> newItems,
    required bool strictStock,
  }) async {
    final oldQtyByProduct = <int, double>{};
    final oldCostByProduct = <int, double>{};
    for (final old in oldItems) {
      final pid = old['product_id'] as int?;
      if (pid == null) continue;
      final qty = (old['quantity'] as num?)?.toDouble() ?? 0.0;
      final factor = (old['unit_conversion_factor'] as num?)?.toDouble() ?? 1.0;
      final baseQty =
          (old['base_quantity'] as num?)?.toDouble() ?? (qty * factor);
      final price = (old['price'] as num?)?.toDouble() ?? 0.0;
      if (baseQty > 0) {
        oldQtyByProduct[pid] = (oldQtyByProduct[pid] ?? 0.0) + baseQty;
        oldCostByProduct[pid] = (oldCostByProduct[pid] ?? 0.0) + (qty * price);
      }
    }

    final newQtyByProduct = <int, double>{};
    final newCostByProduct = <int, double>{};
    for (final newItem in newItems) {
      final pid = newItem.productId;
      if (pid == null) continue;
      final baseQty = newItem.effectiveBaseQuantity;
      final price = newItem.price;
      if (baseQty > 0) {
        newQtyByProduct[pid] = (newQtyByProduct[pid] ?? 0.0) + baseQty;
        newCostByProduct[pid] =
            (newCostByProduct[pid] ?? 0.0) + (newItem.quantity * price);
      }
    }

    final allProductIds = {...oldQtyByProduct.keys, ...newQtyByProduct.keys};

    if (newDoc.type == 'purchase') {
      for (final pid in allProductIds) {
        final oldQty = oldQtyByProduct[pid] ?? 0.0;
        final newQty = newQtyByProduct[pid] ?? 0.0;
        final oldCost = oldCostByProduct[pid] ?? 0.0;
        final newCost = newCostByProduct[pid] ?? 0.0;

        final deltaQty = newQty - oldQty;
        final deltaCost = newCost - oldCost;

        if (deltaQty.abs() < 0.0001 && deltaCost.abs() < 0.0001) {
          continue;
        }

        final pRows = await txn.query(
          'products',
          columns: [
            'name',
            'type',
            'stock_quantity',
            'average_cost',
            'cost_status',
          ],
          where: 'id = ?',
          whereArgs: [pid],
        );
        if (pRows.isEmpty ||
            (pRows.first['type'] as String? ?? 'product') != 'product') {
          continue;
        }

        final name = pRows.first['name'] as String? ?? '';
        final currentStock =
            (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0.0;
        final currentAvg = (pRows.first['average_cost'] as num?)?.toDouble();
        final currentStatus =
            pRows.first['cost_status'] as String? ?? Product.costStatusUnknown;

        if (deltaQty > 0.0001) {
          final incomingQty = deltaQty;
          final incomingCost = deltaCost;
          final incomingUnitCost = incomingQty > 0
              ? (incomingCost / incomingQty)
              : 0.0;

          final double newAvgCost;
          final String newCostStatus;
          if (currentStatus == Product.costStatusKnown) {
            newAvgCost = InventoryCostingService.calculateNewWeightedAverage(
              currentStock: currentStock,
              currentAvgCost: currentAvg,
              incomingQty: incomingQty,
              incomingUnitCost: incomingUnitCost,
            );
            newCostStatus = Product.costStatusKnown;
          } else if (currentStock <= 0) {
            newAvgCost = incomingUnitCost;
            newCostStatus = Product.costStatusKnown;
          } else {
            newAvgCost = incomingUnitCost;
            newCostStatus = Product.costStatusUnknown;
          }

          final newStock = currentStock + incomingQty;
          await txn.update(
            'products',
            {
              'stock_quantity': newStock,
              'average_cost': newAvgCost,
              'cost_status': newCostStatus,
            },
            where: 'id = ?',
            whereArgs: [pid],
          );

          await _insertStockMovement(
            txn,
            productId: pid,
            type: StockMovement.typePurchase,
            quantity: incomingQty,
            unitCost: incomingUnitCost,
            totalCost: incomingCost,
            costStatus: newCostStatus,
            provenance: 'purchase_edit',
            referenceDocumentId: newDoc.id,
            date: newDoc.date,
          );
        } else if (deltaQty < -0.0001) {
          final removedQty = -deltaQty;
          final removedCost = -deltaCost;

          if (currentStock < removedQty) {
            throw StateError(
              'Cannot edit purchase for "$name" because subsequent sales or movements consumed this stock '
              '(available: ${FormatUtils.formatQuantity(currentStock)}, purchased: ${FormatUtils.formatQuantity(removedQty)})',
            );
          }

          final newStock = currentStock - removedQty;
          double? newAvgCost = currentAvg;
          String newCostStatus = currentStatus;

          if (newStock <= 0) {
            newAvgCost = null;
            newCostStatus = Product.costStatusUnknown;
          } else if (currentAvg != null &&
              currentStatus == Product.costStatusKnown) {
            final prevVal = currentStock * currentAvg;
            if (prevVal - removedCost < -0.001) {
              throw StateError(
                'Cannot edit purchase for "$name" because subsequent sales or movements consumed this stock value',
              );
            }
            final remainVal = (prevVal - removedCost).clamp(
              0.0,
              double.infinity,
            );
            newAvgCost = remainVal / newStock;
            newCostStatus = (newAvgCost > 0)
                ? Product.costStatusKnown
                : Product.costStatusUnknown;
          }

          await txn.update(
            'products',
            {
              'stock_quantity': newStock,
              'average_cost': newAvgCost,
              'cost_status': newCostStatus,
            },
            where: 'id = ?',
            whereArgs: [pid],
          );

          final avgUnitCost = removedQty > 0
              ? (removedCost / removedQty)
              : null;
          await _insertStockMovement(
            txn,
            productId: pid,
            type: StockMovement.typeCancellation,
            quantity: -removedQty,
            unitCost: avgUnitCost,
            totalCost: -removedCost,
            costStatus: newCostStatus,
            provenance: 'purchase_reversal',
            referenceDocumentId: newDoc.id,
            date: newDoc.date,
          );
        } else {
          // deltaQty == 0, but deltaCost != 0 (price change only)
          if (currentStock > 0 &&
              currentAvg != null &&
              currentStatus == Product.costStatusKnown) {
            final prevVal = currentStock * currentAvg;
            final newVal = prevVal + deltaCost;
            if (newVal < -0.001) {
              throw StateError(
                'Cannot edit purchase for "$name" because subsequent sales or movements consumed this stock value',
              );
            }
            final newAvgCost = (newVal / currentStock).clamp(
              0.0,
              double.infinity,
            );
            await txn.update(
              'products',
              {'average_cost': newAvgCost},
              where: 'id = ?',
              whereArgs: [pid],
            );
          }
        }
      }
    } else if (newDoc.type == 'invoice') {
      for (final pid in allProductIds) {
        final oldQty = oldQtyByProduct[pid] ?? 0.0;
        final newQty = newQtyByProduct[pid] ?? 0.0;
        final deltaQty = newQty - oldQty;

        if (deltaQty.abs() < 0.0001) {
          continue;
        }

        final pRows = await txn.query(
          'products',
          columns: [
            'name',
            'type',
            'stock_quantity',
            'average_cost',
            'cost_status',
          ],
          where: 'id = ?',
          whereArgs: [pid],
        );
        if (pRows.isEmpty ||
            (pRows.first['type'] as String? ?? 'product') != 'product') {
          continue;
        }

        final currentStock =
            (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0.0;
        final avgCost = (pRows.first['average_cost'] as num?)?.toDouble();
        final costStatus =
            pRows.first['cost_status'] as String? ?? Product.costStatusUnknown;
        final isCostKnown =
            costStatus == Product.costStatusKnown && avgCost != null;

        if (deltaQty > 0.0001) {
          final double deductQty;
          if (strictStock) {
            deductQty = deltaQty;
          } else {
            deductQty = currentStock > 0
                ? (currentStock >= deltaQty ? deltaQty : currentStock)
                : 0.0;
          }
          final bool isFullyBacked = deductQty >= deltaQty;
          if (deductQty > 0) {
            final movementCost = isCostKnown ? deductQty * avgCost : null;
            final movementCostStatus = isCostKnown
                ? StockMovement.costStatusKnown
                : StockMovement.costStatusUnknown;

            await txn.rawUpdate(
              'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
              [deductQty, pid],
            );
            await _insertStockMovement(
              txn,
              productId: pid,
              type: StockMovement.typeSale,
              quantity: -deductQty,
              unitCost: isCostKnown ? avgCost : null,
              totalCost: movementCost,
              costStatus: movementCostStatus,
              provenance: isFullyBacked
                  ? 'sales_invoice'
                  : 'sales_invoice_partial',
              referenceDocumentId: newDoc.id,
              date: newDoc.date,
            );
          }
        } else if (deltaQty < -0.0001) {
          final restoreQty = -deltaQty;
          final movementCost = isCostKnown ? restoreQty * avgCost : null;
          final movementCostStatus = isCostKnown
              ? StockMovement.costStatusKnown
              : StockMovement.costStatusUnknown;

          await txn.rawUpdate(
            'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
            [restoreQty, pid],
          );
          await _insertStockMovement(
            txn,
            productId: pid,
            type: StockMovement.typeCancellation,
            quantity: restoreQty,
            unitCost: isCostKnown ? avgCost : null,
            totalCost: movementCost,
            costStatus: movementCostStatus,
            provenance: 'sale_reversal',
            referenceDocumentId: newDoc.id,
            date: newDoc.date,
          );
        }
      }
    }
  }

  Future<void> updateDocumentWithItems(
    Document doc,
    List<DocumentItem> newItems, {
    Contact? contact,
    bool strictStock = true,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      if (doc.type == 'purchase') {
        AccessGuard.require(PermissionRegistry.purchasesEdit);
      } else {
        AccessGuard.require(PermissionRegistry.salesEdit);
      }

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
        where: 'id = ?',
        whereArgs: [doc.id],
      );
      if (existingRows.isEmpty) throw StateError('Document not found');

      final oldDoc = Document.fromMap(existingRows.first);
      await assertPeriodOpen(oldDoc.date, txn: txn);
      await assertPeriodOpen(doc.date, txn: txn);
      final oldType = oldDoc.type;
      final oldStatus = oldDoc.status;

      if (oldType == 'payment_receipt' || oldType == 'expense_voucher') {
        final hasAlloc = await hasActiveAllocations(oldDoc.id!, txn: txn);
        if (hasAlloc) {
          throw StateError(
            'Allocated vouchers cannot be edited. Cancel and re-issue.',
          );
        }
      }

      if (oldStatus == DocumentStatus.cancelled) {
        throw StateError('Cannot edit a cancelled document');
      }
      if (oldStatus != DocumentStatus.draft &&
          doc.status == DocumentStatus.draft) {
        throw StateError('Cannot convert an issued document to draft');
      }
      if (oldStatus != DocumentStatus.draft &&
          doc.currencyCode != oldDoc.currencyCode) {
        throw ArgumentError(
          'Cannot change currency of an issued document (${oldDoc.currencyCode} to ${doc.currencyCode}).',
        );
      }

      if ((oldType == 'payment_receipt' || oldType == 'expense_voucher') &&
          doc.relatedDocumentId != oldDoc.relatedDocumentId) {
        throw StateError(
          'Cannot reassign an existing payment receipt or expense voucher to a different parent document.',
        );
      }

      final newIsDraft = doc.status == DocumentStatus.draft;
      if (oldStatus == DocumentStatus.draft && !newIsDraft) {
        final bRows = await txn.query('businesses', limit: 1);
        final baseCurrency = bRows.isNotEmpty
            ? (bRows.first['currency_code'] as String? ?? 'SDG')
            : 'SDG';
        if (doc.currencyCode != baseCurrency) {
          throw ArgumentError(
            'Cannot finalize draft with currency (${doc.currencyCode}) that does not match business base currency ($baseCurrency).',
          );
        }
      }
      if (!newIsDraft || doc.paid > 0) {
        await _lockCurrencyTxn(txn);
      }

      // Authoritative stock availability check before any writes or reversals occur
      if (doc.type == 'invoice' && !newIsDraft && strictStock) {
        await _assertSaleStockAvailable(txn, newItems, documentId: doc.id);
      }

      final oldWasIssued =
          (oldType == 'invoice' || oldType == 'purchase') &&
          oldStatus != DocumentStatus.draft &&
          oldStatus != DocumentStatus.cancelled;
      final newIsIssued =
          (doc.type == 'invoice' || doc.type == 'purchase') &&
          !newIsDraft &&
          doc.status != DocumentStatus.cancelled;

      if (oldWasIssued && newIsIssued) {
        await _applyDocumentEditStockDeltas(
          txn,
          oldDoc: oldDoc,
          newDoc: doc,
          oldItems: oldItems,
          newItems: newItems,
          strictStock: strictStock,
        );
      }

      double effectiveSubtotal = doc.subtotal;
      double effectiveTotal = doc.total;
      double effectivePaid = doc.paid;
      double effectiveRemaining = doc.remaining;
      String effectiveStatus = doc.status;

      if (doc.type == 'payment_receipt' || doc.type == 'expense_voucher') {
        final decimalDigits = Currency.decimalDigitsForCode(doc.currencyCode);
        final canonicalAmount = MoneyUtils.round(doc.paid, decimalDigits);
        if (canonicalAmount <= 0) {
          throw ArgumentError('Payment amount must be greater than zero');
        }

        final paymentRows = await txn.query(
          'document_payments',
          where: 'receipt_document_id = ?',
          whereArgs: [doc.id],
        );

        if (paymentRows.isNotEmpty) {
          final pRow = paymentRows.first;
          final oldAmount = (pRow['amount'] as num).toDouble();
          final amountDiff = canonicalAmount - oldAmount;

          if (oldDoc.relatedDocumentId != null) {
            final parentRows = await txn.query(
              'documents',
              where: 'id = ?',
              whereArgs: [oldDoc.relatedDocumentId],
            );
            if (parentRows.isNotEmpty) {
              final parent = Document.fromMap(parentRows.first);
              if (parent.status == DocumentStatus.cancelled) {
                throw StateError(
                  'Cannot modify payment for a cancelled parent document',
                );
              }
              final parentDecimalDigits = Currency.decimalDigitsForCode(
                parent.currencyCode,
              );
              final newParentPaid = MoneyUtils.round(
                parent.paid + amountDiff,
                parentDecimalDigits,
              );
              if (newParentPaid < 0) {
                throw StateError(
                  'Updated payment amount would result in negative paid balance on parent document',
                );
              }
              if (MoneyUtils.isOverpayment(
                newParentPaid,
                parent.total,
                parentDecimalDigits,
              )) {
                throw StateError(
                  'Updated payment amount exceeds parent document remaining balance',
                );
              }
              final newParentRemaining = MoneyUtils.calculateRemaining(
                parent.total,
                newParentPaid,
                parentDecimalDigits,
              );
              final newParentStatus = DocumentStatus.fromPayment(
                newParentPaid,
                parent.total,
                decimalDigits: parentDecimalDigits,
              );

              await txn.update(
                'documents',
                {
                  'paid': newParentPaid,
                  'remaining': newParentRemaining,
                  'status': newParentStatus,
                },
                where: 'id = ?',
                whereArgs: [oldDoc.relatedDocumentId],
              );
            }
          }

          await txn.update(
            'document_payments',
            {
              'amount': canonicalAmount,
              'payment_method': doc.paymentMethod,
              'date': doc.date.toIso8601String(),
              'notes': doc.notes,
              'payment_origin': PaymentOrigin.receipt,
            },
            where: 'id = ?',
            whereArgs: [pRow['id']],
          );
        }

        effectivePaid = canonicalAmount;
        effectiveRemaining = 0.0;
        effectiveSubtotal = canonicalAmount;
        effectiveTotal = canonicalAmount;
        effectiveStatus = DocumentStatus.issued;
      } else if (doc.type == 'invoice' || doc.type == 'purchase') {
        final decimalDigits = Currency.decimalDigitsForCode(doc.currencyCode);
        final canonicalIncomingPaid = MoneyUtils.round(doc.paid, decimalDigits);
        final canonicalOldPaid = MoneyUtils.round(oldDoc.paid, decimalDigits);
        final canonicalIncomingTotal = MoneyUtils.round(
          doc.total,
          decimalDigits,
        );
        final canonicalOldTotal = MoneyUtils.round(oldDoc.total, decimalDigits);
        final epsilon = 1.0 / math.pow(10, decimalDigits + 1);

        if (canonicalIncomingPaid < 0) {
          throw ArgumentError('Paid amount cannot be negative');
        }
        if (MoneyUtils.isOverpayment(
          canonicalIncomingPaid,
          canonicalIncomingTotal,
          decimalDigits,
        )) {
          throw ArgumentError('Paid amount cannot exceed total');
        }

        if (oldStatus == DocumentStatus.draft &&
            doc.status == DocumentStatus.draft) {
          effectivePaid = canonicalIncomingPaid;
          effectiveRemaining = MoneyUtils.calculateRemaining(
            canonicalIncomingTotal,
            canonicalIncomingPaid,
            decimalDigits,
          );
          effectiveStatus = DocumentStatus.draft;
        } else {
          final paymentRows = await txn.query(
            'document_payments',
            where: 'document_id = ?',
            whereArgs: [doc.id],
            orderBy: 'id ASC',
          );

          final totalExistingLedgerPaid = MoneyUtils.round(
            paymentRows.fold<double>(
              0.0,
              (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0.0),
            ),
            decimalDigits,
          );

          final isUserAlteringPaid =
              (canonicalIncomingPaid - canonicalOldPaid).abs() > epsilon;
          final isUserAlteringTotal =
              (canonicalIncomingTotal - canonicalOldTotal).abs() > epsilon;
          final isLedgerDiscrepant =
              (canonicalOldPaid - totalExistingLedgerPaid).abs() > epsilon;

          // 1. Genuine upfront rows: explicitly recorded upfront down-payments (must have no linked receipt)
          final upfrontRows = paymentRows
              .where(
                (r) =>
                    r['payment_origin'] == PaymentOrigin.upfront &&
                    r['receipt_document_id'] == null,
              )
              .toList();

          // 2. Receipt and reversal rows: associated with payment receipts or expense vouchers
          final linkedReceiptRows = paymentRows
              .where(
                (r) =>
                    r['receipt_document_id'] != null ||
                    r['payment_origin'] == PaymentOrigin.receipt ||
                    r['payment_origin'] == PaymentOrigin.reversal,
              )
              .toList();

          // 3. Unclassified legacy rows: rows from older versions where payment_origin is NULL and receipt_document_id is NULL
          final unclassifiedLegacyRows = paymentRows
              .where(
                (r) =>
                    r['receipt_document_id'] == null &&
                    r['payment_origin'] == null,
              )
              .toList();

          final netLinkedReceiptPaid = MoneyUtils.round(
            linkedReceiptRows.fold<double>(
              0.0,
              (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0.0),
            ),
            decimalDigits,
          );

          if (!isUserAlteringPaid) {
            // User did NOT modify the paid amount.
            if (isLedgerDiscrepant) {
              // Document has pre-existing discrepancy between documents.paid and document_payments.
              if (isUserAlteringTotal) {
                // Modifying total requires computing remaining, which cannot be done reliably without choosing a balance.
                throw StateError(
                  'Cannot modify financial totals: document has discrepant payment records (document paid: $canonicalOldPaid, recorded payments: $totalExistingLedgerPaid). Please resolve payment records before modifying totals.',
                );
              }
              // Harmless non-financial edit (notes, contact, date, items with identical total):
              // NEVER fabricate, mutate, or delete payment rows. Preserve existing financial values intact!
              effectivePaid = oldDoc.paid;
              effectiveRemaining = oldDoc.remaining;
              effectiveStatus = oldDoc.status;
            } else {
              // Clean document (ledger matches documents.paid).
              if (MoneyUtils.isOverpayment(
                totalExistingLedgerPaid,
                canonicalIncomingTotal,
                decimalDigits,
              )) {
                throw StateError(
                  'Cannot reduce total ($canonicalIncomingTotal) below recorded payments ($totalExistingLedgerPaid). '
                  'Please refund or reverse payments first.',
                );
              }

              effectivePaid = totalExistingLedgerPaid;
              effectiveRemaining = MoneyUtils.calculateRemaining(
                canonicalIncomingTotal,
                totalExistingLedgerPaid,
                decimalDigits,
              );
              effectiveStatus = DocumentStatus.fromPayment(
                totalExistingLedgerPaid,
                canonicalIncomingTotal,
                decimalDigits: decimalDigits,
              );
            }
          } else {
            // User actively attempted to alter the paid amount.
            AccessGuard.require(PermissionRegistry.paymentsRecord);
            if (isLedgerDiscrepant) {
              throw StateError(
                'Cannot modify paid amount: document has discrepant payment records (document paid: $canonicalOldPaid, recorded payments: $totalExistingLedgerPaid). Please review payment records.',
              );
            }

            if (unclassifiedLegacyRows.isNotEmpty) {
              throw StateError(
                'Cannot modify paid amount: document contains legacy unclassified payment records. '
                'Please record payments via payment receipts instead.',
              );
            }

            if (netLinkedReceiptPaid > epsilon) {
              throw StateError(
                'Cannot modify paid amount directly on a document with active linked payment receipts/vouchers '
                '(active receipts total: $netLinkedReceiptPaid). '
                'Please record, cancel, or delete payment receipts instead.',
              );
            }

            if (upfrontRows.length > 1) {
              throw StateError(
                'Cannot modify paid amount: multiple historical upfront payment records exist. '
                'Please review payment records.',
              );
            }

            if (canonicalIncomingPaid == 0) {
              if (upfrontRows.isNotEmpty) {
                await txn.delete(
                  'document_payments',
                  where: 'id = ?',
                  whereArgs: [upfrontRows.first['id']],
                );
              }
            } else {
              if (upfrontRows.isNotEmpty) {
                await txn.update(
                  'document_payments',
                  {
                    'amount': canonicalIncomingPaid,
                    'payment_method': doc.paymentMethod,
                    'date': doc.date.toIso8601String(),
                    'payment_origin': PaymentOrigin.upfront,
                  },
                  where: 'id = ?',
                  whereArgs: [upfrontRows.first['id']],
                );
                if (canonicalIncomingPaid > 0) {
                  await _lockCurrencyTxn(txn);
                }
              } else {
                await _insertDocumentPaymentTxn(txn, {
                  'document_id': doc.id,
                  'amount': canonicalIncomingPaid,
                  'payment_method': doc.paymentMethod,
                  'date': doc.date.toIso8601String(),
                  'notes': doc.type == 'invoice'
                      ? 'Initial payment'
                      : 'Initial purchase payment',
                  'receipt_document_id': null,
                  'payment_origin': PaymentOrigin.upfront,
                });
              }
            }

            effectivePaid = canonicalIncomingPaid;
            effectiveRemaining = MoneyUtils.calculateRemaining(
              canonicalIncomingTotal,
              canonicalIncomingPaid,
              decimalDigits,
            );
            effectiveStatus = DocumentStatus.fromPayment(
              canonicalIncomingPaid,
              canonicalIncomingTotal,
              decimalDigits: decimalDigits,
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
          'subtotal': effectiveSubtotal,
          'discount': doc.discount,
          'tax_rate': doc.taxRate,
          'tax_amount': doc.taxAmount,
          'total': effectiveTotal,
          'paid': effectivePaid,
          'remaining': effectiveRemaining,
          'payment_method': doc.paymentMethod,
          'valid_until': doc.validUntil?.toIso8601String(),
          'notes': doc.notes,
          'related_document_id': doc.relatedDocumentId,
          'status': effectiveStatus,
          'currency_code': doc.currencyCode,
          'updated_by': AccessContext.currentUserId,
        },
        where: 'id = ?',
        whereArgs: [doc.id],
      );

      await txn.delete(
        'document_items',
        where: 'document_id = ?',
        whereArgs: [doc.id],
      );

      for (final item in newItems) {
        double? itemUnitCost;
        double? itemTotalCost;

        if (item.productId != null && item.quantity > 0) {
          if (!oldWasIssued && newIsIssued) {
            if (doc.type == 'invoice') {
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
                final avgCost = (pRows.first['average_cost'] as num?)
                    ?.toDouble();
                final costStatus =
                    pRows.first['cost_status'] as String? ??
                    Product.costStatusUnknown;
                final isCostKnown =
                    costStatus == Product.costStatusKnown && avgCost != null;

                final effectiveBaseQty = item.effectiveBaseQuantity;
                final double deductQty;
                if (strictStock) {
                  deductQty = effectiveBaseQty;
                } else {
                  deductQty = currentStock > 0
                      ? (currentStock >= effectiveBaseQty
                            ? effectiveBaseQty
                            : currentStock)
                      : 0.0;
                }
                final bool isFullyBacked = deductQty >= effectiveBaseQty;
                if (deductQty > 0) {
                  // If stock was partially oversold, cost for the whole line is incomplete
                  // and must NOT be marked as fully trusted on document_items.
                  itemUnitCost = (isCostKnown && isFullyBacked)
                      ? avgCost
                      : null;
                  itemTotalCost = (isCostKnown && isFullyBacked)
                      ? effectiveBaseQty * avgCost
                      : null;
                  final movementCost = isCostKnown ? deductQty * avgCost : null;
                  final movementCostStatus = isCostKnown
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
            } else if (doc.type == 'purchase') {
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
                if (priorCostStatus == Product.costStatusKnown) {
                  newAvgCost =
                      InventoryCostingService.calculateNewWeightedAverage(
                        currentStock: currentStock,
                        currentAvgCost: currentAvg,
                        incomingQty: incomingQty,
                        incomingUnitCost: incomingUnitCost,
                      );
                  newCostStatus = Product.costStatusKnown;
                } else if (currentStock <= 0) {
                  final movementSumRows = await txn.rawQuery(
                    'SELECT COALESCE(SUM(quantity), 0) AS total_qty FROM stock_movements WHERE product_id = ?',
                    [item.productId],
                  );
                  final movementTotal =
                      (movementSumRows.first['total_qty'] as num).toDouble();
                  final isCleanLedger =
                      (movementTotal - currentStock).abs() <= 0.001 &&
                      movementTotal >= -0.0001;

                  final unknownCostRows = await txn.rawQuery(
                    "SELECT 1 FROM stock_movements WHERE product_id = ? AND (cost_status != '${StockMovement.costStatusKnown}' OR unit_cost IS NULL) LIMIT 1",
                    [item.productId],
                  );
                  final hasUnknownHistory = unknownCostRows.isNotEmpty;

                  if (isCleanLedger && !hasUnknownHistory) {
                    newAvgCost = incomingUnitCost;
                    newCostStatus = Product.costStatusKnown;
                  } else {
                    newAvgCost = incomingUnitCost;
                    newCostStatus = Product.costStatusUnknown;
                  }
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
          } else if (oldWasIssued && newIsIssued) {
            // Document was already issued; stock deltas were applied in _applyDocumentEditStockDeltas.
            if (doc.type == 'invoice') {
              final pRows = await txn.query(
                'products',
                columns: ['average_cost', 'cost_status'],
                where: 'id = ?',
                whereArgs: [item.productId],
              );
              if (pRows.isNotEmpty) {
                final avgCost = (pRows.first['average_cost'] as num?)
                    ?.toDouble();
                final costStatus =
                    pRows.first['cost_status'] as String? ??
                    Product.costStatusUnknown;
                if (costStatus == Product.costStatusKnown && avgCost != null) {
                  itemUnitCost = avgCost;
                  itemTotalCost = item.effectiveBaseQuantity * avgCost;
                }
              }
            } else if (doc.type == 'purchase') {
              itemUnitCost = item.price;
              itemTotalCost = item.quantity * item.price;
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
          'pricing_category': item.pricingCategory,
          'sale_unit': item.saleUnit,
          'unit_conversion_factor': item.unitConversionFactor,
          'base_quantity': item.effectiveBaseQuantity,
        });
      }

      final shadowEnabled = await isJournalShadowWriteEnabled(txn: txn);
      if (shadowEnabled) {
        final wasIssued =
            oldDoc.status != DocumentStatus.draft &&
            oldDoc.status != DocumentStatus.cancelled &&
            oldDoc.type != 'quotation';
        final isIssued =
            effectiveStatus != DocumentStatus.draft &&
            effectiveStatus != DocumentStatus.cancelled &&
            doc.type != 'quotation';

        if (!wasIssued && isIssued) {
          final itemRows = await txn.query(
            'document_items',
            where: 'document_id = ?',
            whereArgs: [doc.id],
          );
          final persistedItems = itemRows.map(DocumentItem.fromMap).toList();
          final finalDoc = doc.copyWith(
            paid: effectivePaid,
            remaining: effectiveRemaining,
            status: effectiveStatus,
            subtotal: effectiveSubtotal,
            total: effectiveTotal,
          );
          await JournalWriter.postDocumentIssued(txn, finalDoc, persistedItems);
        } else if (wasIssued && isIssued) {
          final isMetadataOnly = _isMetadataOnlyDocumentEdit(
            oldDoc: oldDoc,
            newDoc: doc,
            oldItems: oldItems,
            newItems: newItems,
            effectivePaid: effectivePaid,
            effectiveTotal: effectiveTotal,
            effectiveSubtotal: effectiveSubtotal,
          );

          if (!isMetadataOnly) {
            await JournalWriter.reverseDocument(txn, doc.id!);
            final itemRows = await txn.query(
              'document_items',
              where: 'document_id = ?',
              whereArgs: [doc.id],
            );
            final persistedItems = itemRows.map(DocumentItem.fromMap).toList();
            final finalDoc = doc.copyWith(
              paid: effectivePaid,
              remaining: effectiveRemaining,
              status: effectiveStatus,
              subtotal: effectiveSubtotal,
              total: effectiveTotal,
            );
            await JournalWriter.postDocumentIssued(
              txn,
              finalDoc,
              persistedItems,
            );
          }
        }
      }
    });
  }

  bool _isMetadataOnlyDocumentEdit({
    required Document oldDoc,
    required Document newDoc,
    required List<Map<String, Object?>> oldItems,
    required List<DocumentItem> newItems,
    required double effectivePaid,
    required double effectiveTotal,
    required double effectiveSubtotal,
  }) {
    if (oldDoc.date != newDoc.date) return false;
    if (oldDoc.paymentMethod != newDoc.paymentMethod) return false;
    if (oldDoc.contactId != newDoc.contactId) return false;
    if ((oldDoc.total - effectiveTotal).abs() > 1e-6) return false;
    if ((oldDoc.subtotal - effectiveSubtotal).abs() > 1e-6) return false;
    if ((oldDoc.taxAmount - newDoc.taxAmount).abs() > 1e-6) return false;
    if ((oldDoc.paid - effectivePaid).abs() > 1e-6) return false;
    if (oldDoc.status != newDoc.status) return false;

    if (oldItems.length != newItems.length) return false;
    for (var i = 0; i < oldItems.length; i++) {
      final o = oldItems[i];
      final n = newItems[i];
      final oProductId = o['product_id'] as int?;
      final oQty = (o['quantity'] as num?)?.toDouble() ?? 0.0;
      final oPrice = (o['price'] as num?)?.toDouble() ?? 0.0;
      final oTotal = (o['total'] as num?)?.toDouble() ?? 0.0;
      final oSaleUnit = o['sale_unit'] as String?;
      final oFactor = (o['unit_conversion_factor'] as num?)?.toDouble() ?? 1.0;

      if (oProductId != n.productId) return false;
      if ((oQty - n.quantity).abs() > 1e-6) return false;
      if ((oPrice - n.price).abs() > 1e-6) return false;
      if ((oTotal - n.total).abs() > 1e-6) return false;
      if (oSaleUnit != n.saleUnit) return false;
      if ((oFactor - n.unitConversionFactor).abs() > 1e-6) return false;
    }
    return true;
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
      if (doc.type == 'purchase') {
        AccessGuard.require(PermissionRegistry.purchasesDelete);
      } else {
        AccessGuard.require(PermissionRegistry.salesDelete);
      }
      await assertPeriodOpen(doc.date, txn: txn);

      // Payment receipts & expense vouchers: block hard deletion if financial ledger history exists.
      // Financial history must remain intact and auditable; cancellations must be used instead.
      if (doc.type == 'payment_receipt' || doc.type == 'expense_voucher') {
        final paymentHistory = await txn.query(
          'document_payments',
          columns: ['id'],
          where: 'receipt_document_id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (paymentHistory.isNotEmpty) {
          throw StateError(
            'Cannot delete ${doc.type} with recorded payment history. Please cancel the document instead to preserve accounting records.',
          );
        }
      }

      // Guard against deleting an invoice or purchase with active payment receipts/vouchers or payment history
      if (doc.type == 'invoice' || doc.type == 'purchase') {
        final activeReceipts = await txn.rawQuery(
          '''
          SELECT DISTINCT d.document_number
          FROM document_payments dp
          JOIN documents d ON dp.receipt_document_id = d.id
          WHERE dp.document_id = ?
            AND (dp.payment_origin IS NULL OR dp.payment_origin != ?)
            AND dp.amount > 0
            AND d.status != ?
          UNION
          SELECT document_number
          FROM documents
          WHERE related_document_id = ?
            AND type IN ('payment_receipt', 'expense_voucher')
            AND status != ?
        ''',
          [
            id,
            PaymentOrigin.reversal,
            DocumentStatus.cancelled,
            id,
            DocumentStatus.cancelled,
          ],
        );
        if (activeReceipts.isNotEmpty) {
          final receiptNums = activeReceipts
              .map((r) => r['document_number'] as String)
              .join(', ');
          throw StateError(
            'Cannot delete document with active payment receipts/vouchers ($receiptNums). Please cancel or delete the receipts first.',
          );
        }

        final paymentHistory = await txn.query(
          'document_payments',
          columns: ['id'],
          where: 'document_id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (paymentHistory.isNotEmpty || doc.paid > 0) {
          throw StateError(
            'Cannot delete ${doc.type} with recorded payment history. Please cancel the document instead to preserve accounting records.',
          );
        }
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
          final netPurchaseCostByProduct = <int, double?>{};
          if (movements.isNotEmpty) {
            for (final m in movements) {
              final productId = m['product_id'] as int;
              final mType = m['type'] as String;
              final mQty = (m['quantity'] as num).toDouble();
              final uCost = (m['unit_cost'] as num?)?.toDouble();
              final tCost =
                  (m['total_cost'] as num?)?.toDouble() ??
                  (uCost != null ? mQty * uCost : null);
              if (mType == StockMovement.typePurchase) {
                netPurchaseQtyByProduct[productId] =
                    (netPurchaseQtyByProduct[productId] ?? 0.0) + mQty;
                if (tCost != null) {
                  netPurchaseCostByProduct[productId] =
                      (netPurchaseCostByProduct[productId] ?? 0.0) + tCost;
                }
              } else if (mType == StockMovement.typeCancellation && mQty < 0) {
                netPurchaseQtyByProduct[productId] =
                    (netPurchaseQtyByProduct[productId] ?? 0.0) + mQty;
                if (tCost != null) {
                  netPurchaseCostByProduct[productId] =
                      (netPurchaseCostByProduct[productId] ?? 0.0) + tCost;
                }
              }
            }
          } else {
            final items = await txn.query(
              'document_items',
              where: 'document_id = ?',
              whereArgs: [id],
            );
            for (final item in items) {
              final productId = item['product_id'] as int?;
              final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
              final price = (item['price'] as num?)?.toDouble();
              if (productId == null || qty <= 0) continue;
              netPurchaseQtyByProduct[productId] =
                  (netPurchaseQtyByProduct[productId] ?? 0.0) + qty;
              if (price != null) {
                netPurchaseCostByProduct[productId] =
                    (netPurchaseCostByProduct[productId] ?? 0.0) +
                    (qty * price);
              }
            }
          }

          for (final entry in netPurchaseQtyByProduct.entries) {
            final productId = entry.key;
            final netQty = entry.value;
            if (netQty <= 0) continue;
            final pRows = await txn.query(
              'products',
              columns: [
                'name',
                'type',
                'stock_quantity',
                'average_cost',
                'cost_status',
              ],
              where: 'id = ?',
              whereArgs: [productId],
            );
            if (pRows.isNotEmpty &&
                (pRows.first['type'] as String? ?? 'product') == 'product') {
              final name = pRows.first['name'] as String? ?? '';
              final stock =
                  (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0.0;
              if (stock < netQty) {
                throw StateError(
                  'Insufficient stock to reverse purchase for "$name": available ${FormatUtils.formatQuantity(stock)}, required ${FormatUtils.formatQuantity(netQty)}',
                );
              }

              final currentAvg = (pRows.first['average_cost'] as num?)
                  ?.toDouble();
              final currentStatus =
                  pRows.first['cost_status'] as String? ??
                  Product.costStatusUnknown;
              final removedCost = netPurchaseCostByProduct[productId];
              final newStock = stock - netQty;

              double? newAvgCost = currentAvg;
              String newCostStatus = currentStatus;

              if (newStock <= 0) {
                newAvgCost = null;
                newCostStatus = Product.costStatusUnknown;
              } else if (currentAvg != null && removedCost != null) {
                final prevVal = stock * currentAvg;
                if (prevVal - removedCost < -0.001) {
                  throw StateError(
                    'Cannot delete purchase for "$name" because subsequent sales or movements consumed this stock',
                  );
                }
                final remainVal = (prevVal - removedCost).clamp(
                  0.0,
                  double.infinity,
                );
                newAvgCost = remainVal / newStock;
                newCostStatus = (newAvgCost > 0)
                    ? Product.costStatusKnown
                    : Product.costStatusUnknown;
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
            }
          }
        } else if (doc.type == 'invoice') {
          if (movements.isNotEmpty) {
            final netSalesQtyByProduct = <int, double>{};
            for (final m in movements) {
              final productId = m['product_id'] as int;
              final mType = m['type'] as String;
              final mQty = (m['quantity'] as num).toDouble();
              if (mType == StockMovement.typeSale ||
                  mType == StockMovement.typeCancellation) {
                netSalesQtyByProduct[productId] =
                    (netSalesQtyByProduct[productId] ?? 0.0) + mQty;
              }
            }
            for (final entry in netSalesQtyByProduct.entries) {
              final productId = entry.key;
              final netQty = entry.value;
              final revertQty = -netQty;
              if (revertQty > 0) {
                await txn.rawUpdate(
                  'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
                  [revertQty, productId],
                );
              }
            }
          } else {
            final items = await txn.query(
              'document_items',
              where: 'document_id = ?',
              whereArgs: [id],
            );
            for (final item in items) {
              final productId = item['product_id'] as int?;
              final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
              final factor =
                  (item['unit_conversion_factor'] as num?)?.toDouble() ?? 1.0;
              final baseQty =
                  (item['base_quantity'] as num?)?.toDouble() ?? (qty * factor);
              if (productId != null && baseQty > 0) {
                await txn.rawUpdate(
                  'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
                  [baseQty, productId],
                );
              }
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

      // Guard against deleting an invoice or purchase with active payment receipts/vouchers
      if (doc.type == 'invoice' || doc.type == 'purchase') {
        final activeReceipts = await txn.query(
          'documents',
          columns: ['id', 'document_number'],
          where:
              "related_document_id = ? AND type IN ('payment_receipt', 'expense_voucher') AND status != '${DocumentStatus.cancelled}'",
          whereArgs: [id],
        );
        if (activeReceipts.isNotEmpty) {
          final receiptNums = activeReceipts
              .map((r) => r['document_number'] as String)
              .join(', ');
          throw StateError(
            'Cannot delete document with active payment receipts/vouchers ($receiptNums). Please cancel or delete the receipts first.',
          );
        }
      }

      // Nullify related_document_id on any documents that reference this one.
      // Without this, the FK constraint prevents deletion when other documents
      // (e.g. payment receipts) still point to this document.
      await txn.rawUpdate(
        'UPDATE documents SET related_document_id = NULL WHERE related_document_id = ?',
        [id],
      );

      await JournalWriter.reverseDocument(
        txn,
        id,
        memo: 'Document hard deleted',
      );

      return txn.delete('documents', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> cancelDocument(
    int id, {
    String? refundStatus,
    String? refundNotes,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final docRows = await txn.query(
        'documents',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (docRows.isEmpty) return;
      final doc = Document.fromMap(docRows.first);
      if (doc.type == 'purchase') {
        AccessGuard.require(PermissionRegistry.purchasesCancel);
      } else {
        AccessGuard.require(PermissionRegistry.salesCancel);
      }
      if (refundStatus != null) {
        AccessGuard.require(PermissionRegistry.salesRefund);
      }
      await assertPeriodOpen(doc.date, txn: txn);

      if (doc.status == DocumentStatus.cancelled) {
        throw StateError('Document is already cancelled');
      }

      // Payment receipts & expense vouchers: reverse allocations and cancel
      if (doc.type == 'payment_receipt' || doc.type == 'expense_voucher') {
        await _reverseReceiptPayment(txn, id);
        return;
      }

      // Guard against cancelling an invoice or purchase with active payment receipts/vouchers
      if (doc.type == 'invoice' || doc.type == 'purchase') {
        final activeReceipts = await txn.rawQuery(
          '''
          SELECT DISTINCT d.document_number
          FROM document_payments dp
          JOIN documents d ON dp.receipt_document_id = d.id
          WHERE dp.document_id = ?
            AND (dp.payment_origin IS NULL OR dp.payment_origin != ?)
            AND dp.amount > 0
            AND d.status != ?
          UNION
          SELECT document_number
          FROM documents
          WHERE related_document_id = ?
            AND type IN ('payment_receipt', 'expense_voucher')
            AND status != ?
        ''',
          [
            id,
            PaymentOrigin.reversal,
            DocumentStatus.cancelled,
            id,
            DocumentStatus.cancelled,
          ],
        );
        if (activeReceipts.isNotEmpty) {
          final receiptNums = activeReceipts
              .map((r) => r['document_number'] as String)
              .join(', ');
          throw StateError(
            'Cannot cancel document with active payment receipts/vouchers ($receiptNums). Please cancel or delete the receipts first.',
          );
        }
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

        if (doc.type == 'purchase') {
          final netPurchaseQtyByProduct = <int, double>{};
          final netPurchaseCostByProduct = <int, double?>{};
          final movements = await txn.query(
            'stock_movements',
            where: 'reference_document_id = ?',
            whereArgs: [id],
          );
          if (movements.isNotEmpty) {
            for (final m in movements) {
              final productId = m['product_id'] as int;
              final mType = m['type'] as String;
              final mQty = (m['quantity'] as num).toDouble();
              final uCost = (m['unit_cost'] as num?)?.toDouble();
              final tCost =
                  (m['total_cost'] as num?)?.toDouble() ??
                  (uCost != null ? mQty * uCost : null);
              if (mType == StockMovement.typePurchase) {
                netPurchaseQtyByProduct[productId] =
                    (netPurchaseQtyByProduct[productId] ?? 0.0) + mQty;
                if (tCost != null) {
                  netPurchaseCostByProduct[productId] =
                      (netPurchaseCostByProduct[productId] ?? 0.0) + tCost;
                }
              } else if (mType == StockMovement.typeCancellation && mQty < 0) {
                netPurchaseQtyByProduct[productId] =
                    (netPurchaseQtyByProduct[productId] ?? 0.0) + mQty;
                if (tCost != null) {
                  netPurchaseCostByProduct[productId] =
                      (netPurchaseCostByProduct[productId] ?? 0.0) + tCost;
                }
              }
            }
          } else {
            for (final item in items) {
              final productId = item['product_id'] as int?;
              final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
              final price = (item['price'] as num?)?.toDouble();
              if (productId == null || qty <= 0) continue;
              netPurchaseQtyByProduct[productId] =
                  (netPurchaseQtyByProduct[productId] ?? 0.0) + qty;
              if (price != null) {
                netPurchaseCostByProduct[productId] =
                    (netPurchaseCostByProduct[productId] ?? 0.0) +
                    (qty * price);
              }
            }
          }

          for (final entry in netPurchaseQtyByProduct.entries) {
            final productId = entry.key;
            final netQty = entry.value;
            if (netQty <= 0) continue;
            final pRows = await txn.query(
              'products',
              columns: [
                'name',
                'type',
                'stock_quantity',
                'average_cost',
                'cost_status',
              ],
              where: 'id = ?',
              whereArgs: [productId],
            );
            if (pRows.isNotEmpty &&
                (pRows.first['type'] as String? ?? 'product') == 'product') {
              final name = pRows.first['name'] as String? ?? '';
              final stock =
                  (pRows.first['stock_quantity'] as num?)?.toDouble() ?? 0.0;
              if (stock < netQty) {
                throw StateError(
                  'Insufficient stock to cancel purchase for "$name": available ${FormatUtils.formatQuantity(stock)}, required ${FormatUtils.formatQuantity(netQty)}',
                );
              }

              final currentAvg = (pRows.first['average_cost'] as num?)
                  ?.toDouble();
              final currentStatus =
                  pRows.first['cost_status'] as String? ??
                  Product.costStatusUnknown;
              final removedCost = netPurchaseCostByProduct[productId];
              final newStock = stock - netQty;

              double? newAvgCost = currentAvg;
              String newCostStatus = currentStatus;

              if (newStock <= 0) {
                newAvgCost = null;
                newCostStatus = Product.costStatusUnknown;
              } else if (currentAvg != null && removedCost != null) {
                final prevVal = stock * currentAvg;
                if (prevVal - removedCost < -0.001) {
                  throw StateError(
                    'Cannot cancel purchase for "$name" because subsequent sales or movements consumed this stock',
                  );
                }
                final remainVal = (prevVal - removedCost).clamp(
                  0.0,
                  double.infinity,
                );
                newAvgCost = remainVal / newStock;
                newCostStatus = (newAvgCost > 0)
                    ? Product.costStatusKnown
                    : Product.costStatusUnknown;
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

              final avgUnitCost = (removedCost != null && netQty > 0)
                  ? removedCost / netQty
                  : null;
              await _insertStockMovement(
                txn,
                productId: productId,
                type: StockMovement.typeCancellation,
                quantity: -netQty,
                unitCost: avgUnitCost,
                totalCost: removedCost != null ? -removedCost : null,
                costStatus: newCostStatus,
                provenance: 'purchase_cancellation',
                referenceDocumentId: id,
                date: doc.date,
              );
            }
          }
        } else if (doc.type == 'invoice') {
          final movements = await txn.query(
            'stock_movements',
            where: 'reference_document_id = ? AND type IN (?, ?)',
            whereArgs: [
              id,
              StockMovement.typeSale,
              StockMovement.typeCancellation,
            ],
          );
          if (movements.isNotEmpty) {
            final netSalesQtyByProduct = <int, double>{};
            final lastCostByProduct = <int, double?>{};
            final lastStatusByProduct = <int, String>{};

            for (final m in movements) {
              final productId = m['product_id'] as int;
              final mQty = (m['quantity'] as num).toDouble();
              netSalesQtyByProduct[productId] =
                  (netSalesQtyByProduct[productId] ?? 0.0) + mQty;
              if (m['unit_cost'] != null) {
                lastCostByProduct[productId] = (m['unit_cost'] as num)
                    .toDouble();
              }
              if (m['cost_status'] != null) {
                lastStatusByProduct[productId] = m['cost_status'] as String;
              }
            }

            for (final entry in netSalesQtyByProduct.entries) {
              final productId = entry.key;
              final netQty = entry.value;
              final revertQty = -netQty;
              if (revertQty > 0) {
                final unitCost = lastCostByProduct[productId];
                final totalCost = unitCost != null
                    ? revertQty * unitCost
                    : null;
                final costStatus =
                    lastStatusByProduct[productId] ??
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
                  provenance: 'sale_cancellation',
                  referenceDocumentId: id,
                  date: doc.date,
                );
              }
            }
          } else {
            for (final item in items) {
              final productId = item['product_id'] as int?;
              final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
              final factor =
                  (item['unit_conversion_factor'] as num?)?.toDouble() ?? 1.0;
              final baseQty =
                  (item['base_quantity'] as num?)?.toDouble() ?? (qty * factor);
              if (productId != null && baseQty > 0) {
                await txn.rawUpdate(
                  'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
                  [baseQty, productId],
                );
                await _insertStockMovement(
                  txn,
                  productId: productId,
                  type: StockMovement.typeCancellation,
                  quantity: baseQty,
                  unitCost: (item['unit_cost'] as num?)?.toDouble(),
                  totalCost: (item['total_cost'] as num?)?.toDouble(),
                  costStatus: StockMovement.costStatusUnknown,
                  provenance: 'sale_cancellation_legacy',
                  referenceDocumentId: id,
                  date: doc.date,
                );
              }
            }
          }
        }
      }

      await txn.update(
        'documents',
        {
          'status': DocumentStatus.cancelled,
          'updated_by': AccessContext.currentUserId,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      await JournalWriter.reverseDocument(txn, id);

      if (refundStatus != null && doc.paid > 0) {
        await logAuditEvent(
          'document_refund_status',
          entityType: 'document',
          entityId: id,
          details: jsonEncode({
            'status': refundStatus,
            'amount': doc.paid,
            'currency': doc.currencyCode,
            'doc_type': doc.type,
            if (refundNotes != null && refundNotes.isNotEmpty)
              'notes': refundNotes,
          }),
          txn: txn,
        );
      }
    });
  }

  /// Updates or records a document refund status for an existing document.
  Future<void> updateDocumentRefundStatus({
    required int documentId,
    required String status,
    String? notes,
  }) async {
    AccessGuard.require(PermissionRegistry.salesRefund);
    final db = await database;
    final docRows = await db.query(
      'documents',
      columns: ['id', 'type', 'paid', 'currency_code'],
      where: 'id = ?',
      whereArgs: [documentId],
    );
    if (docRows.isEmpty) throw StateError('Document not found');
    final r = docRows.first;
    await logAuditEvent(
      'document_refund_status',
      entityType: 'document',
      entityId: documentId,
      details: jsonEncode({
        'status': status,
        'amount': (r['paid'] as num?)?.toDouble() ?? 0.0,
        'currency': (r['currency_code'] as String?) ?? 'SDG',
        'doc_type': r['type'] as String?,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      }),
    );
  }

  /// Queries the latest refund status recorded for a document in audit_log.
  Future<Map<String, dynamic>?> getLatestDocumentRefundStatus(
    int documentId,
  ) async {
    final db = await database;
    final rows = await db.query(
      'audit_log',
      where:
          "entity_type = 'document' AND entity_id = ? AND action = 'document_refund_status'",
      whereArgs: [documentId],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    try {
      final detailsStr = row['details'] as String?;
      final details = detailsStr != null
          ? jsonDecode(detailsStr) as Map<String, dynamic>
          : <String, dynamic>{};
      return {
        'status': details['status'] as String?,
        'amount': (details['amount'] as num?)?.toDouble(),
        'currency': details['currency'] as String?,
        'timestamp': DateTime.tryParse(row['timestamp'] as String? ?? ''),
        'notes': details['notes'] as String?,
      };
    } catch (_) {
      return {
        'status': null,
        'timestamp': DateTime.tryParse(row['timestamp'] as String? ?? ''),
      };
    }
  }

  /// Checks whether an issued voucher has active allocations recorded in document_payments.
  Future<bool> hasActiveAllocations(
    int voucherId, {
    DatabaseExecutor? txn,
  }) async {
    final exec = txn ?? await database;
    final rows = await exec.rawQuery(
      '''
      SELECT 1 FROM document_payments
      WHERE receipt_document_id = ?
        AND (payment_origin IS NULL OR payment_origin != ?)
        AND amount > 0
      LIMIT 1
    ''',
      [voucherId, PaymentOrigin.reversal],
    );
    return rows.isNotEmpty;
  }

  /// Authoritative automatic FIFO allocation for customer receipts and supplier payments.
  /// Allocates [voucher.total] across eligible open invoices (for payment_receipt) or
  /// purchases (for expense_voucher) in deterministic FIFO order (date ASC, id ASC).
  Future<void> _allocateVoucherFifoTxn(
    DatabaseExecutor txn,
    Document voucher,
  ) async {
    if (voucher.id == null) {
      throw StateError('Cannot allocate a voucher without an ID');
    }
    if (voucher.contactId == null) {
      // Standalone / no-contact voucher: independent behavior preserved
      return;
    }

    final targetType = voucher.type == 'payment_receipt'
        ? 'invoice'
        : (voucher.type == 'expense_voucher' ? 'purchase' : null);
    if (targetType == null) return;

    // Contact verification
    final contactRows = await txn.query(
      'contacts',
      where: 'id = ?',
      whereArgs: [voucher.contactId],
    );
    if (contactRows.isEmpty) {
      throw StateError('Contact with ID ${voucher.contactId} not found.');
    }
    final contactType = contactRows.first['type'] as String? ?? 'customer';
    if (voucher.type == 'payment_receipt' && contactType != 'customer') {
      throw ArgumentError(
        'Payment receipts can only be allocated to customer contacts.',
      );
    }
    if (voucher.type == 'expense_voucher' && contactType != 'supplier') {
      throw ArgumentError(
        'Expense vouchers can only be allocated to supplier contacts.',
      );
    }

    final decimalDigits = Currency.decimalDigitsForCode(voucher.currencyCode);
    final voucherTotal = MoneyUtils.round(voucher.total, decimalDigits);
    if (voucherTotal <= 0) {
      throw ArgumentError('Voucher amount must be greater than zero.');
    }

    // 1. Fetch all non-draft, non-cancelled open documents for this contact and targetType
    final allOpenRows = await txn.query(
      'documents',
      where:
          "contact_id = ? AND type = ? AND status NOT IN ('${DocumentStatus.draft}', '${DocumentStatus.cancelled}', '${DocumentStatus.paid}') AND remaining > 0",
      whereArgs: [voucher.contactId, targetType],
      orderBy: 'date ASC, id ASC',
    );

    if (allOpenRows.isEmpty) {
      throw StateError(
        'No eligible outstanding $targetType documents found for contact.',
      );
    }

    // 2. Currency segregation check
    final foreignCurrencyRows = allOpenRows
        .where(
          (r) =>
              (r['currency_code'] as String? ?? 'SDG') != voucher.currencyCode,
        )
        .toList();
    if (foreignCurrencyRows.isNotEmpty &&
        !allOpenRows.any(
          (r) =>
              (r['currency_code'] as String? ?? 'SDG') == voucher.currencyCode,
        )) {
      throw ArgumentError(
        'Voucher currency (${voucher.currencyCode}) does not match outstanding currency.',
      );
    }

    final eligibleRows = allOpenRows
        .where(
          (r) =>
              (r['currency_code'] as String? ?? 'SDG') == voucher.currencyCode,
        )
        .toList();
    if (eligibleRows.isEmpty) {
      throw StateError(
        'No eligible outstanding $targetType documents found in currency ${voucher.currencyCode}.',
      );
    }

    // 3. Overpayment calculation & strict rejection
    double totalOutstanding = 0.0;
    for (final r in eligibleRows) {
      totalOutstanding += (r['remaining'] as num).toDouble();
    }
    totalOutstanding = MoneyUtils.round(totalOutstanding, decimalDigits);

    if (MoneyUtils.isOverpayment(
      voucherTotal,
      totalOutstanding,
      decimalDigits,
    )) {
      throw ArgumentError(
        'Voucher amount ($voucherTotal) exceeds total outstanding balance ($totalOutstanding). Overpayment is not allowed.',
      );
    }

    // 4. FIFO Allocation loop
    double unallocated = voucherTotal;
    for (final target in eligibleRows) {
      if (unallocated <= 0) break;
      final targetId = target['id'] as int;
      final targetTotal = (target['total'] as num).toDouble();
      final targetPaid = (target['paid'] as num).toDouble();
      final targetRemaining = (target['remaining'] as num).toDouble();

      final allocAmount = MoneyUtils.round(
        math.min(unallocated, targetRemaining),
        decimalDigits,
      );
      if (allocAmount <= 0) continue;

      // Insert document_payments row
      await _insertDocumentPaymentTxn(txn, {
        'document_id': targetId,
        'amount': allocAmount,
        'payment_method': voucher.paymentMethod,
        'date': voucher.date.toIso8601String(),
        'notes': voucher.notes,
        'receipt_document_id': voucher.id,
        'payment_origin': PaymentOrigin.receipt,
      });

      // Update target document paid, remaining, and status
      final newPaid = MoneyUtils.round(targetPaid + allocAmount, decimalDigits);
      final newRemaining = MoneyUtils.calculateRemaining(
        targetTotal,
        newPaid,
        decimalDigits,
      );
      final newStatus = DocumentStatus.fromPayment(
        newPaid,
        targetTotal,
        decimalDigits: decimalDigits,
      );

      await txn.update(
        'documents',
        {'paid': newPaid, 'remaining': newRemaining, 'status': newStatus},
        where: 'id = ?',
        whereArgs: [targetId],
      );

      unallocated = MoneyUtils.round(unallocated - allocAmount, decimalDigits);
    }

    if (unallocated > 0) {
      throw StateError(
        'Failed to fully allocate voucher. Unallocated remainder: $unallocated',
      );
    }
  }

  Future<void> _reverseReceiptPayment(
    DatabaseExecutor txn,
    int receiptId,
  ) async {
    final receiptRows = await txn.query(
      'documents',
      where: 'id = ?',
      whereArgs: [receiptId],
    );
    if (receiptRows.isEmpty) return;
    final receipt = Document.fromMap(receiptRows.first);
    await assertPeriodOpen(receipt.date, txn: txn);

    final paymentRows = await txn.query(
      'document_payments',
      where: 'receipt_document_id = ?',
      whereArgs: [receiptId],
      orderBy: 'id ASC',
    );

    // Group active positive allocations by document_id
    final activeAllocations = paymentRows.where((r) {
      final origin = r['payment_origin'] as String?;
      final amount = (r['amount'] as num?)?.toDouble() ?? 0.0;
      return origin != PaymentOrigin.reversal && amount > 0;
    }).toList();

    final allocationsByDocId = <int, double>{};
    for (final r in activeAllocations) {
      final docId = r['document_id'] as int;
      final amt = (r['amount'] as num).toDouble();
      allocationsByDocId[docId] = (allocationsByDocId[docId] ?? 0.0) + amt;
    }

    // Support legacy vouchers where allocations were not in document_payments but relatedDocumentId was set
    if (allocationsByDocId.isEmpty && receipt.relatedDocumentId != null) {
      allocationsByDocId[receipt.relatedDocumentId!] = receipt.total;
    }

    final docNum = receipt.documentNumber.isNotEmpty
        ? receipt.documentNumber
        : receiptId.toString();
    final docType = receipt.type;

    for (final entry in allocationsByDocId.entries) {
      final targetId = entry.key;
      final targetRows = await txn.query(
        'documents',
        where: 'id = ?',
        whereArgs: [targetId],
      );
      if (targetRows.isEmpty) continue;
      final target = Document.fromMap(targetRows.first);
      final decimalDigits = Currency.decimalDigitsForCode(target.currencyCode);
      final canonicalReverse = MoneyUtils.round(entry.value, decimalDigits);

      if (canonicalReverse > 0) {
        // Auditable reversal entry in document_payments linked to original receipt
        await _insertDocumentPaymentTxn(txn, {
          'document_id': targetId,
          'amount': -canonicalReverse,
          'payment_method': receipt.paymentMethod,
          'date': receipt.date.toIso8601String(),
          'notes': 'Reversal: cancelled $docType $docNum',
          'receipt_document_id': receiptId,
          'payment_origin': PaymentOrigin.reversal,
        });

        if (target.status != DocumentStatus.cancelled) {
          final newPaid = math.max(
            0.0,
            MoneyUtils.round(target.paid - canonicalReverse, decimalDigits),
          );
          final newRemaining = MoneyUtils.calculateRemaining(
            target.total,
            newPaid,
            decimalDigits,
          );
          final newStatus = DocumentStatus.fromPayment(
            newPaid,
            target.total,
            decimalDigits: decimalDigits,
          );
          await txn.update(
            'documents',
            {'paid': newPaid, 'remaining': newRemaining, 'status': newStatus},
            where: 'id = ?',
            whereArgs: [targetId],
          );
        }
      }
    }

    // Cancel the receipt/voucher document
    await txn.update(
      'documents',
      {'status': DocumentStatus.cancelled},
      where: 'id = ?',
      whereArgs: [receiptId],
    );

    await JournalWriter.reverseDocument(txn, receiptId);
  }

  Future<void> recordPayment({
    required int documentId,
    required double amount,
    String? paymentMethod,
    String? notes,
  }) async {
    AccessGuard.require(PermissionRegistry.paymentsRecord);
    final db = await database;
    await db.transaction((txn) async {
      await assertPeriodOpen(DateTime.now(), txn: txn);
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
      final decimalDigits = Currency.decimalDigitsForCode(doc.currencyCode);
      final canonicalAmount = MoneyUtils.round(amount, decimalDigits);

      if (canonicalAmount <= 0) {
        throw ArgumentError('Payment amount must be greater than zero');
      }
      if (MoneyUtils.isOverpayment(
        canonicalAmount,
        doc.remaining,
        decimalDigits,
      )) {
        throw ArgumentError('Payment cannot exceed remaining amount');
      }

      final paymentDate = DateTime.now();
      final paymentId = await _insertDocumentPaymentTxn(txn, {
        'document_id': documentId,
        'amount': canonicalAmount,
        'payment_method': paymentMethod,
        'date': paymentDate.toIso8601String(),
        'notes': notes,
        'payment_origin': PaymentOrigin.receipt,
      });

      final newPaid = MoneyUtils.round(
        doc.paid + canonicalAmount,
        decimalDigits,
      );
      final newRemaining = MoneyUtils.calculateRemaining(
        doc.total,
        newPaid,
        decimalDigits,
      );
      final newStatus = DocumentStatus.fromPayment(
        newPaid,
        doc.total,
        decimalDigits: decimalDigits,
      );

      await txn.update(
        'documents',
        {'paid': newPaid, 'remaining': newRemaining, 'status': newStatus},
        where: 'id = ?',
        whereArgs: [documentId],
      );

      final payment = DocumentPayment(
        id: paymentId,
        documentId: documentId,
        amount: canonicalAmount,
        paymentMethod: paymentMethod,
        date: paymentDate,
        notes: notes,
      );
      await JournalWriter.postPaymentRecorded(
        txn,
        payment: payment,
        parentDoc: doc,
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
    AccessGuard.require(PermissionRegistry.paymentsRecord);
    final db = await database;
    return await db.transaction(
      (txn) => _recordPaymentTxn(
        txn,
        documentId: documentId,
        amount: amount,
        paymentMethod: paymentMethod,
        notes: notes,
      ),
    );
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
    await assertPeriodOpen(DateTime.now(), txn: txn);

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
    if (MoneyUtils.isOverpayment(
      canonicalAmount,
      doc.remaining,
      decimalDigits,
    )) {
      throw ArgumentError('Payment cannot exceed remaining amount');
    }

    // Create the linked voucher document (payment_receipt for invoices, expense_voucher for purchases)
    final linkedType = doc.type == 'purchase'
        ? 'expense_voucher'
        : 'payment_receipt';
    final linkedNumber = await getNextDocumentNumber(txn, linkedType);
    final now = DateTime.now();
    int receiptId;
    String finalLinkedNumber = linkedNumber;
    try {
      receiptId = await txn.insert('documents', {
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
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError() ||
          e.toString().toLowerCase().contains('unique')) {
        final retryNumber = await getNextDocumentNumber(txn, linkedType);
        finalLinkedNumber = retryNumber;
        receiptId = await txn.insert('documents', {
          'type': linkedType,
          'document_number': retryNumber,
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
      } else {
        rethrow;
      }
    }

    // Record the payment row linked to the receipt
    await _insertDocumentPaymentTxn(txn, {
      'document_id': documentId,
      'amount': canonicalAmount,
      'payment_method': paymentMethod,
      'date': now.toIso8601String(),
      'notes': notes,
      'receipt_document_id': receiptId,
      'payment_origin': PaymentOrigin.receipt,
    });

    // Update invoice totals
    final newPaid = MoneyUtils.round(doc.paid + canonicalAmount, decimalDigits);
    final newRemaining = MoneyUtils.calculateRemaining(
      doc.total,
      newPaid,
      decimalDigits,
    );
    final newStatus = DocumentStatus.fromPayment(
      newPaid,
      doc.total,
      decimalDigits: decimalDigits,
    );

    await txn.update(
      'documents',
      {'paid': newPaid, 'remaining': newRemaining, 'status': newStatus},
      where: 'id = ?',
      whereArgs: [documentId],
    );

    final receiptDoc = Document(
      id: receiptId,
      type: linkedType,
      documentNumber: finalLinkedNumber,
      date: now,
      contactId: doc.contactId,
      recipientName: doc.recipientName,
      recipientPhone: doc.recipientPhone,
      subtotal: canonicalAmount,
      discount: 0.0,
      taxRate: 0.0,
      taxAmount: 0.0,
      total: canonicalAmount,
      paid: canonicalAmount,
      remaining: 0.0,
      paymentMethod: paymentMethod,
      validUntil: null,
      notes: doc.documentNumber,
      relatedDocumentId: documentId,
      status: DocumentStatus.issued,
      currencyCode: doc.currencyCode,
    );

    await JournalWriter.postDocumentIssued(
      txn,
      receiptDoc,
      const [],
      parentDoc: doc,
    );

    await logAuditEvent(
      'payment_recorded',
      entityType: 'document',
      entityId: documentId,
      details: 'amount=$canonicalAmount method=$paymentMethod',
      txn: txn,
    );

    return receiptId;
  }

  /// Returns non-draft, non-cancelled documents with remaining balance > 0
  /// for [contactId] where type matches [documentType] ('invoice' or 'purchase').
  /// Only documents in the base business currency are included.
  /// Ordered oldest-first: date ASC, id ASC.
  Future<List<Map<String, Object?>>> getOpenDocumentsForContact(
    int contactId,
    String documentType, {
    DatabaseExecutor? txn,
  }) async {
    final exec = txn ?? (await database);
    final biz = await getFirstBusiness(txn: exec);
    final baseCurrency = biz?.currencyCode ?? 'SDG';

    final rows = await exec.query(
      'documents',
      columns: [
        'id',
        'document_number',
        'date',
        'total',
        'paid',
        'remaining',
        'currency_code',
      ],
      where:
          "contact_id = ? AND type = ? AND status NOT IN ('${DocumentStatus.draft}', '${DocumentStatus.cancelled}', '${DocumentStatus.paid}') AND remaining > 0 AND (currency_code = ? OR currency_code IS NULL)",
      whereArgs: [contactId, documentType, baseCurrency],
      orderBy: 'date ASC, id ASC',
    );
    return rows;
  }

  /// Allocates payment across open documents for [contactId] using oldest-first (FIFO) order.
  /// Executes inside a single database transaction.
  Future<List<int>> recordFifoPayment({
    required int contactId,
    required String documentType,
    required double amount,
    String? paymentMethod,
    String? notes,
  }) async {
    AccessGuard.require(PermissionRegistry.paymentsRecord);
    final db = await database;
    return db.transaction((txn) async {
      final now = DateTime.now();
      await assertPeriodOpen(now, txn: txn);

      final openDocs = await getOpenDocumentsForContact(
        contactId,
        documentType,
        txn: txn,
      );

      final biz = await getFirstBusiness(txn: txn);
      final currencyCode = biz?.currencyCode ?? 'SDG';
      final decimalDigits = Currency.decimalDigitsForCode(currencyCode);

      final openBalances = openDocs.map((d) {
        final rem =
            (d['remaining'] as num?)?.toDouble() ??
            ((d['total'] as num).toDouble() - (d['paid'] as num).toDouble());
        return OpenDocumentBalance(id: d['id'] as int, remaining: rem);
      }).toList();

      final plan = PaymentAllocator.planFifo(
        open: openBalances,
        amount: amount,
        decimalDigits: decimalDigits,
      );

      final receiptIds = <int>[];
      for (final alloc in plan) {
        final receiptId = await _recordPaymentTxn(
          txn,
          documentId: alloc.documentId,
          amount: alloc.amount,
          paymentMethod: paymentMethod,
          notes: notes,
        );
        receiptIds.add(receiptId);
      }
      return receiptIds;
    });
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
  getLedgerData({DatabaseExecutor? txn}) async {
    if (txn != null) {
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
    }
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

      final bRows = await txn.query('businesses', limit: 1);
      final baseCurrency = bRows.isNotEmpty
          ? (bRows.first['currency_code'] as String? ?? 'SDG')
          : 'SDG';
      if (quotation.currencyCode != baseCurrency) {
        throw StateError(
          'Cannot convert quotation with legacy currency (${quotation.currencyCode}) '
          'to invoice because active business currency is ($baseCurrency).',
        );
      }

      final invoiceNumber = await getNextDocumentNumber(txn, 'invoice');
      final now = DateTime.now();

      int invoiceId;
      try {
        invoiceId = await txn.insert('documents', {
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
      } on DatabaseException catch (e) {
        if (e.isUniqueConstraintError() ||
            e.toString().toLowerCase().contains('unique')) {
          final retryNumber = await getNextDocumentNumber(txn, 'invoice');
          invoiceId = await txn.insert('documents', {
            'type': 'invoice',
            'document_number': retryNumber,
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
        } else {
          rethrow;
        }
      }

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
          'tax_rate': item['tax_rate'],
          'pricing_category': item['pricing_category'],
          'sale_unit': item['sale_unit'],
          'unit_conversion_factor': item['unit_conversion_factor'] ?? 1.0,
          'base_quantity': item['base_quantity'] ?? item['quantity'],
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

      // Authoritative authorization check before any mutations or ledger postings
      if (doc.type == 'purchase') {
        AccessGuard.require(PermissionRegistry.purchasesCreate);
      } else if (doc.type == 'payment_receipt' ||
          doc.type == 'expense_voucher') {
        AccessGuard.require(PermissionRegistry.vouchersCreate);
      } else {
        AccessGuard.require(PermissionRegistry.salesCreate);
      }

      if (doc.paid > 0 && (doc.type == 'invoice' || doc.type == 'purchase')) {
        AccessGuard.require(PermissionRegistry.paymentsRecord);
      }

      await assertPeriodOpen(doc.date, txn: txn);

      final bRows = await txn.query('businesses', limit: 1);
      final baseCurrency = bRows.isNotEmpty
          ? (bRows.first['currency_code'] as String? ?? 'SDG')
          : 'SDG';
      if (doc.currencyCode != baseCurrency) {
        throw ArgumentError(
          'Cannot issue draft with currency (${doc.currencyCode}) that does not match business base currency ($baseCurrency).',
        );
      }
      await _lockCurrencyTxn(txn);

      final items = await txn.query(
        'document_items',
        where: 'document_id = ?',
        whereArgs: [id],
      );

      if (doc.type == 'invoice') {
        if (strictStock) {
          // Authoritative stock availability check
          await _assertSaleStockAvailable(txn, items);
        }
        for (final item in items) {
          final productId = item['product_id'] as int?;
          final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
          if (productId == null || qty <= 0) continue;
          final effectiveQty =
              (item['base_quantity'] as num?)?.toDouble() ??
              (qty *
                  ((item['unit_conversion_factor'] as num?)?.toDouble() ??
                      1.0));
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
              deductQty = effectiveQty;
            } else {
              deductQty = currentStock > 0
                  ? (currentStock >= effectiveQty ? effectiveQty : currentStock)
                  : 0.0;
            }
            final bool isFullyBacked = deductQty >= effectiveQty;
            if (deductQty > 0) {
              final unitCost = (isCostKnown && isFullyBacked) ? avgCost : null;
              final totalCost = (isCostKnown && isFullyBacked)
                  ? effectiveQty * avgCost
                  : null;
              final movementCost = isCostKnown ? deductQty * avgCost : null;
              final movementCostStatus = isCostKnown
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
            if (priorCostStatus == Product.costStatusKnown) {
              newAvgCost = InventoryCostingService.calculateNewWeightedAverage(
                currentStock: currentStock,
                currentAvgCost: currentAvg,
                incomingQty: incomingQty,
                incomingUnitCost: incomingUnitCost,
              );
              newCostStatus = Product.costStatusKnown;
            } else if (currentStock <= 0) {
              final movementSumRows = await txn.rawQuery(
                'SELECT COALESCE(SUM(quantity), 0) AS total_qty FROM stock_movements WHERE product_id = ?',
                [productId],
              );
              final movementTotal = (movementSumRows.first['total_qty'] as num)
                  .toDouble();
              final isCleanLedger =
                  (movementTotal - currentStock).abs() <= 0.001 &&
                  movementTotal >= -0.0001;

              final unknownCostRows = await txn.rawQuery(
                "SELECT 1 FROM stock_movements WHERE product_id = ? AND (cost_status != '${StockMovement.costStatusKnown}' OR unit_cost IS NULL) LIMIT 1",
                [productId],
              );
              final hasUnknownHistory = unknownCostRows.isNotEmpty;

              if (isCleanLedger && !hasUnknownHistory) {
                newAvgCost = incomingUnitCost;
                newCostStatus = Product.costStatusKnown;
              } else {
                newAvgCost = incomingUnitCost;
                newCostStatus = Product.costStatusUnknown;
              }
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

      final decimalDigits = Currency.decimalDigitsForCode(doc.currencyCode);
      final canonicalPaid = MoneyUtils.round(doc.paid, decimalDigits);
      final canonicalTotal = MoneyUtils.round(doc.total, decimalDigits);
      double effectivePaid = canonicalPaid;

      // Ensure upfront payments recorded at draft creation are persisted to document_payments exactly once
      if ((doc.type == 'invoice' || doc.type == 'purchase')) {
        final existingPayments = await txn.query(
          'document_payments',
          where: 'document_id = ?',
          whereArgs: [id],
        );
        final totalExistingPaid = MoneyUtils.round(
          existingPayments.fold<double>(
            0.0,
            (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0.0),
          ),
          decimalDigits,
        );

        if (canonicalPaid > totalExistingPaid) {
          final missingAmount = MoneyUtils.round(
            canonicalPaid - totalExistingPaid,
            decimalDigits,
          );
          await _insertDocumentPaymentTxn(txn, {
            'document_id': id,
            'amount': missingAmount,
            'payment_method': doc.paymentMethod,
            'date': doc.date.toIso8601String(),
            'notes': doc.type == 'invoice'
                ? 'Initial payment'
                : 'Initial purchase payment',
            'receipt_document_id': null,
            'payment_origin': PaymentOrigin.upfront,
          });
        } else if (totalExistingPaid > canonicalPaid) {
          effectivePaid = totalExistingPaid;
        }
      }

      final effectiveRemaining = MoneyUtils.calculateRemaining(
        canonicalTotal,
        effectivePaid,
        decimalDigits,
      );
      final newStatus = (doc.type == 'invoice' || doc.type == 'purchase')
          ? DocumentStatus.fromPayment(
              effectivePaid,
              canonicalTotal,
              decimalDigits: decimalDigits,
            )
          : DocumentStatus.issued;

      await txn.update(
        'documents',
        {
          'status': newStatus,
          'paid': effectivePaid,
          'remaining': effectiveRemaining,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      final updatedDoc = doc.copyWith(
        status: newStatus,
        paid: effectivePaid,
        remaining: effectiveRemaining,
      );
      final itemRows = await txn.query(
        'document_items',
        where: 'document_id = ?',
        whereArgs: [id],
      );
      final persistedItems = itemRows.map(DocumentItem.fromMap).toList();
      await JournalWriter.postDocumentIssued(txn, updatedDoc, persistedItems);

      final businessId = bRows.isNotEmpty
          ? (bRows.first['id'] as int? ?? 1)
          : 1;
      await captureDocumentSealSnapshotTxn(
        txn,
        documentId: id,
        businessId: businessId,
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

      final bRows = await txn.query('businesses', limit: 1);
      final baseCurrency = bRows.isNotEmpty
          ? (bRows.first['currency_code'] as String? ?? 'SDG')
          : 'SDG';
      if (source.currencyCode != baseCurrency) {
        throw StateError(
          'Cannot duplicate document in legacy currency (${source.currencyCode}) '
          'because active business currency is ($baseCurrency).',
        );
      }

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

      int newId;
      try {
        newId = await txn.insert('documents', {
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
      } on DatabaseException catch (e) {
        if (e.isUniqueConstraintError() ||
            e.toString().toLowerCase().contains('unique')) {
          final retryNumber = await getNextDocumentNumber(txn, source.type);
          newId = await txn.insert('documents', {
            'type': source.type,
            'document_number': retryNumber,
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
        } else {
          rethrow;
        }
      }

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
            'tax_rate': item['tax_rate'],
            'pricing_category': item['pricing_category'],
            'sale_unit': item['sale_unit'],
            'unit_conversion_factor': item['unit_conversion_factor'] ?? 1.0,
            'base_quantity': item['base_quantity'] ?? item['quantity'],
          });
        }
      }

      if (newStatus == DocumentStatus.issued) {
        final businessId = bRows.isNotEmpty
            ? (bRows.first['id'] as int? ?? 1)
            : 1;
        await captureDocumentSealSnapshotTxn(
          txn,
          documentId: newId,
          businessId: businessId,
        );
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
    }

    // Ensure candidate number is not already used in documents table
    String candidate;
    while (true) {
      candidate = '$prefix-${next.toString().padLeft(5, '0')}';
      final existing = await txn.query(
        'documents',
        columns: ['id'],
        where: 'type = ? AND document_number = ?',
        whereArgs: [type, candidate],
        limit: 1,
      );
      if (existing.isEmpty) {
        break;
      }
      next++;
    }

    if (rows.isNotEmpty) {
      await txn.update(
        'document_counters',
        {'next_number': next + 1},
        where: 'type = ?',
        whereArgs: [type],
      );
    } else {
      await txn.insert('document_counters', {
        'type': type,
        'next_number': next + 1,
      });
    }
    return candidate;
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
    final normalizedQuery = ArabicSearchUtils.normalize(query);
    final normNotes = ArabicSearchUtils.sqlNormalize('notes');
    final normRecip = ArabicSearchUtils.sqlNormalize('recipient_name');
    final normContactName = ArabicSearchUtils.sqlNormalize('name');
    String where =
        '(document_number LIKE ? OR $normNotes LIKE ? OR $normRecip LIKE ? OR recipient_phone LIKE ? OR contact_id IN (SELECT id FROM contacts WHERE $normContactName LIKE ? OR phone LIKE ?))';
    final args = [
      '%$normalizedQuery%',
      '%$normalizedQuery%',
      '%$normalizedQuery%',
      '%$normalizedQuery%',
      '%$normalizedQuery%',
      '%$normalizedQuery%',
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

  Future<Map<String, double>> getTodaySummary({String? currencyCode}) async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final whereBuffer = StringBuffer('''
      date >= ? AND date < ?
        AND status != '${DocumentStatus.draft}'
        AND status != '${DocumentStatus.cancelled}'
      ''');
    final args = <Object?>[start.toIso8601String(), end.toIso8601String()];
    if (currencyCode != null && currencyCode.isNotEmpty) {
      whereBuffer.write(' AND currency_code = ?');
      args.add(currencyCode);
    }
    final result = await db.rawQuery('''
      SELECT
        SUM(CASE WHEN type = 'invoice' THEN total ELSE 0 END) as sales,
        SUM(CASE WHEN type = 'invoice' THEN remaining ELSE 0 END) as outstanding
      FROM documents
      WHERE $whereBuffer
    ''', args);
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
  /// Computes segregated totals per currency code to prevent nominal cross-currency aggregation.
  /// When [currencyCode] is provided, top-level scalar fields represent that currency.
  /// When multiple currencies exist and [currencyCode] is null, top-level scalar fields remain 0.0
  /// and callers inspect [totalsByCurrency] to prevent invalid cross-currency additions.
  Future<Map<String, dynamic>> getPeriodSummary({
    required DateTime from,
    required DateTime to,
    String? currencyCode,
  }) async {
    final db = await database;
    final fromStr = from.toIso8601String();
    final toStr = to.toIso8601String();

    // 1. Period financial totals (sales & purchases) grouped by currency
    final finRows = await db.rawQuery(
      '''
      SELECT
        currency_code,
        COALESCE(SUM(CASE WHEN type = 'invoice'  THEN total ELSE 0 END), 0) AS sales,
        COALESCE(SUM(CASE WHEN type = 'purchase' THEN total ELSE 0 END), 0) AS purchases
      FROM documents
      WHERE status NOT IN ('${DocumentStatus.draft}', '${DocumentStatus.cancelled}')
        AND date >= ? AND date <= ?
      GROUP BY currency_code
    ''',
      [fromStr, toStr],
    );

    // 2. Period payments in & out grouped by document currency
    final payRows = await db.rawQuery(
      '''
      SELECT
        d.currency_code,
        COALESCE(SUM(CASE WHEN d.type = 'invoice'  THEN dp.amount ELSE 0 END), 0) AS paymentsIn,
        COALESCE(SUM(CASE WHEN d.type = 'purchase' THEN dp.amount ELSE 0 END), 0) AS paymentsOut
      FROM document_payments dp
      JOIN documents d ON d.id = dp.document_id
      WHERE d.status != '${DocumentStatus.cancelled}'
        AND dp.date >= ? AND dp.date <= ?
      GROUP BY d.currency_code
    ''',
      [fromStr, toStr],
    );

    // 3. All-time outstanding balances grouped by currency
    final balRows = await db.rawQuery('''
      SELECT
        currency_code,
        COALESCE(SUM(CASE WHEN type = 'invoice'  THEN remaining ELSE 0 END), 0) AS customerOutstanding,
        COALESCE(SUM(CASE WHEN type = 'purchase' THEN remaining ELSE 0 END), 0) AS supplierPayable
      FROM documents
      WHERE status NOT IN ('${DocumentStatus.draft}', '${DocumentStatus.cancelled}')
      GROUP BY currency_code
    ''');

    final allCurrencies = <String>{};
    final finMap = <String, ({double sales, double purchases})>{};
    for (final r in finRows) {
      final code = (r['currency_code'] as String?)?.trim() ?? 'SDG';
      if (code.isNotEmpty) {
        allCurrencies.add(code);
        finMap[code] = (
          sales: (r['sales'] as num?)?.toDouble() ?? 0.0,
          purchases: (r['purchases'] as num?)?.toDouble() ?? 0.0,
        );
      }
    }

    final payMap = <String, ({double paymentsIn, double paymentsOut})>{};
    for (final r in payRows) {
      final code = (r['currency_code'] as String?)?.trim() ?? 'SDG';
      if (code.isNotEmpty) {
        allCurrencies.add(code);
        payMap[code] = (
          paymentsIn: (r['paymentsIn'] as num?)?.toDouble() ?? 0.0,
          paymentsOut: (r['paymentsOut'] as num?)?.toDouble() ?? 0.0,
        );
      }
    }

    final balMap =
        <String, ({double customerOutstanding, double supplierPayable})>{};
    for (final r in balRows) {
      final code = (r['currency_code'] as String?)?.trim() ?? 'SDG';
      if (code.isNotEmpty) {
        final cust = (r['customerOutstanding'] as num?)?.toDouble() ?? 0.0;
        final supp = (r['supplierPayable'] as num?)?.toDouble() ?? 0.0;
        if (cust > 0 || supp > 0) {
          allCurrencies.add(code);
        }
        balMap[code] = (customerOutstanding: cust, supplierPayable: supp);
      }
    }

    final totalsByCurrency =
        <
          String,
          ({
            double sales,
            double purchases,
            double paymentsIn,
            double paymentsOut,
            double customerOutstanding,
            double supplierPayable,
          })
        >{};

    for (final c in allCurrencies) {
      totalsByCurrency[c] = (
        sales: finMap[c]?.sales ?? 0.0,
        purchases: finMap[c]?.purchases ?? 0.0,
        paymentsIn: payMap[c]?.paymentsIn ?? 0.0,
        paymentsOut: payMap[c]?.paymentsOut ?? 0.0,
        customerOutstanding: balMap[c]?.customerOutstanding ?? 0.0,
        supplierPayable: balMap[c]?.supplierPayable ?? 0.0,
      );
    }

    double sales = 0.0;
    double purchases = 0.0;
    double paymentsIn = 0.0;
    double paymentsOut = 0.0;
    double customerOutstanding = 0.0;
    double supplierPayable = 0.0;

    final biz = await getFirstBusiness();
    final baseCurrency = (biz != null && biz.currencyCode.trim().isNotEmpty)
        ? biz.currencyCode.trim()
        : 'SDG';
    final targetCode = (currencyCode != null && currencyCode.trim().isNotEmpty)
        ? currencyCode.trim()
        : baseCurrency;
    final target = totalsByCurrency[targetCode];
    if (target != null) {
      sales = target.sales;
      purchases = target.purchases;
      paymentsIn = target.paymentsIn;
      paymentsOut = target.paymentsOut;
      customerOutstanding = target.customerOutstanding;
      supplierPayable = target.supplierPayable;
    }

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
      'currencies': allCurrencies,
      'totalsByCurrency': totalsByCurrency,
      'hasMultipleCurrencies': allCurrencies.length > 1,
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

  /// Contact balance summary for customer/supplier report (all-time), optionally filtered by currency.
  /// When [currencyCode] is provided, balances are strictly filtered to that currency.
  /// When [currencyCode] is null, results are grouped by (contact, currency) so amounts in different
  /// currencies are NEVER aggregated nominally together into one row.
  Future<List<Map<String, dynamic>>> getContactBalances(
    String contactType,
    String docType, {
    String? currencyCode,
  }) async {
    final db = await database;
    if (currencyCode != null && currencyCode.isNotEmpty) {
      return db.rawQuery(
        '''
        SELECT
          c.id AS contact_id,
          c.name,
          c.phone,
          ? AS currency_code,
          COALESCE(SUM(d.total), 0)     AS total_amount,
          COALESCE(SUM(d.paid), 0)      AS total_paid,
          COALESCE(SUM(d.remaining), 0) AS outstanding,
          COUNT(d.id)                   AS doc_count
        FROM contacts c
        LEFT JOIN documents d ON d.contact_id = c.id
          AND d.type = ?
          AND d.status NOT IN ('${DocumentStatus.draft}', '${DocumentStatus.cancelled}')
          AND d.currency_code = ?
        WHERE c.type = ?
        GROUP BY c.id
        ORDER BY outstanding DESC, c.name
      ''',
        [currencyCode, docType, currencyCode, contactType],
      );
    }

    return db.rawQuery(
      '''
      SELECT
        c.id AS contact_id,
        c.name,
        c.phone,
        d.currency_code,
        COALESCE(SUM(d.total), 0)     AS total_amount,
        COALESCE(SUM(d.paid), 0)      AS total_paid,
        COALESCE(SUM(d.remaining), 0) AS outstanding,
        COUNT(d.id)                   AS doc_count
      FROM contacts c
      LEFT JOIN documents d ON d.contact_id = c.id
        AND d.type = ?
        AND d.status NOT IN ('${DocumentStatus.draft}', '${DocumentStatus.cancelled}')
      WHERE c.type = ?
      GROUP BY c.id, d.currency_code
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
        COALESCE(SUM(CASE WHEN d.type = 'invoice'  THEN COALESCE(di.base_quantity, di.quantity) ELSE 0 END), 0) AS sales_qty,
        COALESCE(SUM(CASE WHEN d.type = 'invoice'  THEN di.total    ELSE 0 END), 0) AS sales_value,
        COALESCE(SUM(CASE WHEN d.type = 'purchase' THEN COALESCE(di.base_quantity, di.quantity) ELSE 0 END), 0) AS purchase_qty,
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
  /// Excludes payments belonging to cancelled documents.
  Future<List<Map<String, dynamic>>> getPaymentReport({
    required DateTime from,
    required DateTime to,
    String? currencyCode,
  }) async {
    final db = await database;
    final whereBuffer = StringBuffer(
      "d.status != '${DocumentStatus.cancelled}' AND dp.date >= ? AND dp.date <= ?",
    );
    final args = <Object?>[from.toIso8601String(), to.toIso8601String()];
    if (currencyCode != null && currencyCode.isNotEmpty) {
      whereBuffer.write(' AND d.currency_code = ?');
      args.add(currencyCode);
    }
    return db.rawQuery('''
      SELECT
        dp.id, dp.amount, dp.payment_method, dp.date, dp.notes,
        dp.document_id,
        d.document_number, d.type AS doc_type, d.recipient_name,
        d.currency_code
      FROM document_payments dp
      JOIN documents d ON d.id = dp.document_id
      WHERE $whereBuffer
      ORDER BY dp.date DESC
    ''', args);
  }

  Future<void> logAuditEvent(
    String action, {
    String? entityType,
    int? entityId,
    String? details,
    DatabaseExecutor? txn,
  }) async {
    final db = txn ?? await database;
    try {
      await AuditService.instance.logEvent(
        db,
        action,
        entityType: entityType,
        entityId: entityId,
        details: details,
      );
    } catch (e) {
      if (txn != null) {
        // Inside a business transaction: failure MUST roll back the transaction
        rethrow;
      }
      debugPrint('Audit log insert failed: $e');
      rethrow;
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
    AccessGuard.require(PermissionRegistry.taxProfilesManage);
    final db = await database;
    return db.transaction((txn) async {
      if (p.isDefault) {
        await txn.update('tax_profiles', {'is_default': 0});
      }
      return txn.insert('tax_profiles', p.toMap());
    });
  }

  Future<int> updateTaxProfile(TaxProfile p) async {
    AccessGuard.require(PermissionRegistry.taxProfilesManage);
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
    AccessGuard.require(PermissionRegistry.taxProfilesManage);
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
    AccessGuard.require(PermissionRegistry.paymentMethodsManage);
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
    AccessGuard.require(PermissionRegistry.paymentMethodsManage);
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
    AccessGuard.require(PermissionRegistry.paymentMethodsManage);
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
    AccessGuard.require(PermissionRegistry.paymentMethodsManage);
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
    AccessGuard.require(PermissionRegistry.paymentMethodsManage);
    final db = await database;
    final rows = await db.query(
      'payment_methods',
      columns: ['key', 'is_predefined'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return 0;
    final isPredefined = (rows.first['is_predefined'] as int?) == 1;
    if (isPredefined) {
      throw StateError('Cannot delete predefined payment method');
    }
    final key = rows.first['key'] as String;
    if (await isPaymentMethodUsedInDocuments(key)) {
      throw StateError(
        'Cannot delete payment method: in use by existing transactions',
      );
    }
    return db.delete(
      'payment_methods',
      where: 'id = ? AND is_predefined = 0',
      whereArgs: [id],
    );
  }

  /// Retrieves a payment method by its unique key.
  Future<PaymentMethod?> getPaymentMethodByKey(String key) async {
    final db = await database;
    final rows = await db.query(
      'payment_methods',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PaymentMethod.fromMap(rows.first);
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

  /// Data-only deletion of a single cached notification row by its server ID.
  Future<int> deleteCachedNotification(int serverId) async {
    final db = await database;
    return await db.delete(
      'cached_notifications',
      where: 'server_id = ?',
      whereArgs: [serverId],
    );
  }

  /// Data-only bulk deletion of cached notifications, optionally preserving critical alerts.
  Future<int> deleteAllCachedNotifications({
    bool preserveCritical = true,
  }) async {
    final db = await database;
    if (preserveCritical) {
      return await db.delete(
        'cached_notifications',
        where: 'category != ?',
        whereArgs: ['critical'],
      );
    }
    return await db.delete('cached_notifications');
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
    AccessGuard.require(PermissionRegistry.stocktakeManage);
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
        'created_by': AccessContext.currentUserId,
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
      await AuditService.instance.logEvent(
        txn,
        'stocktake_started',
        entityType: 'stocktake_session',
        entityId: sessionId,
        details:
            'session="$sessionNumber" items=${products.length}${categoryFilter != null ? " category=$categoryFilter" : ""}',
      );

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
    AccessGuard.require(PermissionRegistry.stocktakeManage);
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
    AccessGuard.require(PermissionRegistry.stocktakeFinalize);
    AccessGuard.require(PermissionRegistry.stockAdjust);
    final db = await database;
    return db.transaction((txn) async {
      await assertPeriodOpen(DateTime.now(), txn: txn);
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
        SELECT si.*, p.stock_quantity AS current_stock, p.average_cost, p.cost_status, p.purchase_price, p.name AS product_name
        FROM stocktake_items si
        INNER JOIN products p ON p.id = si.product_id
        WHERE si.session_id = ?
      ''',
        [sessionId],
      );

      int matchedCount = 0;
      int discrepantCount = 0;
      int adjustedCount = 0;
      int interimConflictCount = 0;
      final now = DateTime.now();

      for (final row in items) {
        final itemId = row['id'] as int;
        final productId = row['product_id'] as int;
        final counted = (row['counted_quantity'] as num?)?.toDouble();
        final currentStock = (row['current_stock'] as num?)?.toDouble() ?? 0.0;
        final baselineQuantity =
            (row['baseline_quantity'] as num?)?.toDouble() ?? currentStock;
        final interimMovement = currentStock - baselineQuantity;
        if (interimMovement.abs() > 0.0001) {
          interimConflictCount++;
        }
        double? effectiveCost = (row['average_cost'] as num?)?.toDouble();
        if (effectiveCost == null || effectiveCost <= 0) {
          effectiveCost = (row['purchase_price'] as num?)?.toDouble();
        }
        if (effectiveCost == null || effectiveCost <= 0) {
          effectiveCost = (row['unit_cost'] as num?)?.toDouble();
        }
        if (effectiveCost != null && effectiveCost <= 0) {
          effectiveCost = null;
        }
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

        final countDiscrepancy = counted - baselineQuantity;
        if (countDiscrepancy.abs() < 0.0001) {
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

          // Apply physical count discrepancy onto current live stock so intervening transactions are never discarded
          final newStock = math.max(0.0, currentStock + countDiscrepancy);
          final appliedDelta = newStock - currentStock;

          final totalCost = effectiveCost != null
              ? (appliedDelta.abs() * effectiveCost)
              : null;
          await StockLedger.record(
            txn,
            productId: productId,
            deltaQuantity: appliedDelta,
            newStockQuantity: newStock,
            type: StockMovement.typeAdjustment,
            unitCost: effectiveCost,
            totalCost: totalCost,
            costStatus: costStatus,
            provenance: 'stocktake',
            date: now,
            notes: interimMovement.abs() > 0.0001
                ? 'تسوية جرد المخزون: ${session.sessionNumber} (فارق: $countDiscrepancy, حركة بينية: $interimMovement)'
                : 'تسوية جرد المخزون: ${session.sessionNumber}',
            reason: appliedDelta > 0 ? 'count_gain' : 'count_loss',
          );

          // 3. Update stocktake item record
          await txn.update(
            'stocktake_items',
            {
              'reconciled_system_quantity': currentStock,
              'variance': countDiscrepancy,
              'unit_cost': effectiveCost,
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
      await logAuditEvent(
        'stocktake_finalized',
        entityType: 'stocktake_session',
        entityId: sessionId,
        details:
            'session="${session.sessionNumber}" matched=$matchedCount discrepant=$discrepantCount adjusted=$adjustedCount interimConflicts=$interimConflictCount',
        txn: txn,
      );

      return {
        'matched': matchedCount,
        'discrepant': discrepantCount,
        'adjusted': adjustedCount,
        'session_number': session.sessionNumber,
        'interim_conflicts': interimConflictCount,
      };
    });
  }

  Future<void> cancelStocktakeSession(int sessionId) async {
    AccessGuard.require(PermissionRegistry.stocktakeManage);
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

      await AuditService.instance.logEvent(
        txn,
        'stocktake_cancelled',
        entityType: 'stocktake_session',
        entityId: sessionId,
        details: 'session="${session.sessionNumber}"',
      );
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
