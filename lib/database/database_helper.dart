import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/product.dart';
import '../models/document.dart';
import '../models/document_item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  DatabaseHelper._privateConstructor();

  static const int dbVersion = 4;

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

  Future<void> _createTables(Database db, int version) async {
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
        tax_rate REAL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        type TEXT DEFAULT 'customer'
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        code TEXT,
        sale_price REAL DEFAULT 0,
        purchase_price REAL DEFAULT 0,
        stock_quantity REAL DEFAULT 0,
        min_stock REAL DEFAULT 0,
        is_taxable INTEGER DEFAULT 1,
        notes TEXT
      )
    ''');

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
        status TEXT DEFAULT 'active',
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
  }

  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
    // Helper to check column existence
    Future<bool> columnExists(String table, String column) async {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      return columns.any((c) => c['name'] == column);
    }

    // Version 2: add payment_method and valid_until
    if (oldVersion < 2) {
      if (!await columnExists('documents', 'payment_method')) {
        await db.execute('ALTER TABLE documents ADD COLUMN payment_method TEXT');
      }
      if (!await columnExists('documents', 'valid_until')) {
        await db.execute('ALTER TABLE documents ADD COLUMN valid_until TEXT');
      }
    }

    // Version 3: add logo_path to businesses
    if (oldVersion < 3) {
      if (!await columnExists('businesses', 'logo_path')) {
        await db.execute('ALTER TABLE businesses ADD COLUMN logo_path TEXT');
      }
    }

    // Version 4: add currency_code to businesses and documents
    if (oldVersion < 4) {
      if (!await columnExists('businesses', 'currency_code')) {
        await db.execute("ALTER TABLE businesses ADD COLUMN currency_code TEXT DEFAULT 'SDG'");
      }
      if (!await columnExists('documents', 'currency_code')) {
        await db.execute("ALTER TABLE documents ADD COLUMN currency_code TEXT DEFAULT 'SDG'");
      }
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
    return db.insert('contacts', c.toMap());
  }

  Future<int> updateContact(Contact c) async {
    final db = await database;
    return db.update('contacts', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<int> deleteContact(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      await txn.update('documents', {'contact_id': null}, where: 'contact_id = ?', whereArgs: [id]);
      return txn.delete('contacts', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<Contact>> getAllContacts() async {
    final db = await database;
    final maps = await db.query('contacts', orderBy: 'name');
    return maps.map((e) => Contact.fromMap(e)).toList();
  }

  Future<List<Contact>> searchContacts(String query, {String? type}) async {
    final db = await database;
    String where = '(name LIKE ? OR phone LIKE ?)';
    final args = ['%$query%', '%$query%'];
    if (type != null && type.isNotEmpty) {
      where += ' AND type = ?';
      args.add(type);
    }
    final maps = await db.query('contacts', where: where, whereArgs: args, orderBy: 'name', limit: 8);
    return maps.map((e) => Contact.fromMap(e)).toList();
  }

  Future<Contact?> getContactById(int id) async {
    final db = await database;
    final maps = await db.query('contacts', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Contact.fromMap(maps.first);
  }

  // ========== Products ==========
  Future<int> insertProduct(Product p) async {
    final db = await database;
    return db.insert('products', p.toMap());
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

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final maps = await db.query('products', orderBy: 'name');
    return maps.map((e) => Product.fromMap(e)).toList();
  }

  Future<List<Product>> searchProducts(String query) async {
    final db = await database;
    final maps = await db.query('products',
        where: 'name LIKE ? OR code LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
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

  // ========== Documents ==========
  Future<int> insertDocumentWithItems(Document doc, List<DocumentItem> items, {Contact? contact}) async {
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

      for (final item in items) {
        await txn.insert('document_items', {
          'document_id': docId,
          'product_id': item.productId,
          'description': item.description,
          'quantity': item.quantity,
          'price': item.price,
          'total': item.total,
          'taxable': item.taxable ? 1 : 0,
        });

        if (doc.type == 'invoice' && item.productId != null) {
          await txn.rawUpdate(
            'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
            [item.quantity, item.productId],
          );
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

      final oldItems = await txn.query(
        'document_items',
        where: 'document_id = ?',
        whereArgs: [doc.id],
      );
      final existingDocument = await txn.query(
        'documents',
        columns: ['type'],
        where: 'id = ?',
        whereArgs: [doc.id],
      );
      if (existingDocument.isEmpty) {
        throw StateError('Document not found');
      }

      // Revert stock for old items
      if (existingDocument.first['type'] == 'invoice') {
        for (final old in oldItems) {
          final productId = old['product_id'] as int?;
          final qty = old['quantity'] as num? ?? 0;
          if (productId != null && qty > 0) {
            await txn.rawUpdate(
              'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
              [qty, productId],
            );
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

      for (final item in newItems) {
        await txn.insert('document_items', {
          'document_id': doc.id,
          'product_id': item.productId,
          'description': item.description,
          'quantity': item.quantity,
          'price': item.price,
          'total': item.total,
          'taxable': item.taxable ? 1 : 0,
        });

        if (doc.type == 'invoice' && item.productId != null) {
          await txn.rawUpdate(
            'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
            [item.quantity, item.productId],
          );
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

      if (doc.type == 'invoice') {
        final items = await txn.query('document_items', where: 'document_id = ?', whereArgs: [id]);
        for (final item in items) {
          final productId = item['product_id'] as int?;
          final qty = item['quantity'] as num? ?? 0;
          if (productId != null && qty > 0) {
            await txn.rawUpdate(
              'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
              [qty, productId],
            );
          }
        }
      }

      return txn.delete('documents', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<String> getNextDocumentNumber(DatabaseExecutor txn, String type) async {
    final prefix = switch (type) {
      'invoice' => 'INV',
      'quotation' => 'QUO',
      'payment_receipt' => 'PAY',
      'expense_voucher' => 'EXP',
      'custom' => 'CUS',
      _ => 'DOC',
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
    String where = '(document_number LIKE ? OR contact_id IN (SELECT id FROM contacts WHERE name LIKE ?))';
    final args = ['%$query%', '%$query%'];
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
    ''', [start.toIso8601String(), end.toIso8601String()]);
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
    final maps = await db.query('documents', where: 'contact_id = ?', whereArgs: [contactId], orderBy: 'date DESC');
    return maps.map((e) => Document.fromMap(e)).toList();
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
