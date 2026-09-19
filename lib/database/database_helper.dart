import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/business.dart';
import '../models/contact.dart';
import '../models/product.dart';
import '../models/document.dart';
import '../models/document_item.dart';
import '../models/document_payment.dart';
import '../models/document_status.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  DatabaseHelper._privateConstructor();

  static const int dbVersion = 5;

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
        FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeTables(Database db, int oldVersion, int newVersion) async {
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

    // Version 5: document_payments table + status migration
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

      // Migrate 'active' status to correct per-type status values
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

      final isDraft = doc.status == DocumentStatus.draft;

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

        // Deduct stock only for issued invoices, not drafts
        if (doc.type == 'invoice' && !isDraft && item.productId != null) {
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
      final existingRows = await txn.query(
        'documents',
        columns: ['type', 'status'],
        where: 'id = ?',
        whereArgs: [doc.id],
      );
      if (existingRows.isEmpty) {
        throw StateError('Document not found');
      }

      final oldType   = existingRows.first['type']   as String;
      final oldStatus = existingRows.first['status'] as String? ?? DocumentStatus.issued;

      // Revert stock for previously issued invoice items
      if (oldType == 'invoice' && oldStatus != DocumentStatus.draft && oldStatus != DocumentStatus.cancelled) {
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
        });

        // Apply stock only for issued invoices, not drafts
        if (doc.type == 'invoice' && !newIsDraft && item.productId != null) {
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

      // Revert stock only for issued (non-draft, non-cancelled) invoices.
      // Cancelled invoices already had stock reverted by cancelDocument.
      if (doc.type == 'invoice' &&
          doc.status != DocumentStatus.draft &&
          doc.status != DocumentStatus.cancelled) {
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

  Future<void> cancelDocument(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      final docRows = await txn.query('documents', where: 'id = ?', whereArgs: [id]);
      if (docRows.isEmpty) return;
      final doc = Document.fromMap(docRows.first);

      if (doc.status == DocumentStatus.cancelled) {
        throw StateError('Document is already cancelled');
      }

      // Revert stock for non-draft invoices (stock was deducted on issue)
      if (doc.type == 'invoice' && doc.status != DocumentStatus.draft) {
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

      await txn.update(
        'documents',
        {'status': DocumentStatus.cancelled},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
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

      if (doc.type != 'invoice') {
        throw StateError('Payment recording is only supported for invoices');
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

      final newPaid      = doc.paid + amount;
      final newRemaining = (doc.total - newPaid).clamp(0.0, double.infinity);
      final newStatus    = DocumentStatus.fromPayment(newPaid, doc.total);

      await txn.update('documents', {
        'paid':      newPaid,
        'remaining': newRemaining,
        'status':    newStatus,
      }, where: 'id = ?', whereArgs: [documentId]);
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

  Future<String> getNextDocumentNumber(DatabaseExecutor txn, String type) async {
    final prefix = switch (type) {
      'invoice'          => 'INV',
      'quotation'        => 'QUO',
      'payment_receipt'  => 'PAY',
      'expense_voucher'  => 'EXP',
      'custom'           => 'CUS',
      _                  => 'DOC',
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
        '(document_number LIKE ? OR notes LIKE ? OR contact_id IN (SELECT id FROM contacts WHERE name LIKE ?))';
    final args = ['%$query%', '%$query%', '%$query%'];
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

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
