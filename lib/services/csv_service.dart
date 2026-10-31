import 'dart:convert';
import 'dart:typed_data';

import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/product_unit.dart';

enum CsvDuplicateStrategy {
  skip,
  update,
}

class CsvParsedRow {
  final int rowNumber;
  final String name;
  final String? barcode;
  final String? code;
  final String? category;
  final String type;
  final String? unit;
  final double salePrice;
  final double purchasePrice;
  final double? wholesalePrice;
  final double? wholesaleMinQty;
  final List<ProductUnit>? salesUnits;
  final double minStock;
  final bool isActive;
  final bool isValid;
  final String? errorMessage;
  final bool isExisting;
  final int? existingProductId;

  const CsvParsedRow({
    required this.rowNumber,
    required this.name,
    this.barcode,
    this.code,
    this.category,
    this.type = Product.typeProduct,
    this.unit,
    required this.salePrice,
    this.purchasePrice = 0.0,
    this.wholesalePrice,
    this.wholesaleMinQty,
    this.salesUnits,
    this.minStock = 0.0,
    this.isActive = true,
    required this.isValid,
    this.errorMessage,
    this.isExisting = false,
    this.existingProductId,
  });
}

class CsvImportPreview {
  final List<CsvParsedRow> rows;
  final int validNewCount;
  final int existingCount;
  final int errorCount;
  final bool canImport;

  const CsvImportPreview({
    required this.rows,
    required this.validNewCount,
    required this.existingCount,
    required this.errorCount,
    required this.canImport,
  });
}

class CsvImportResult {
  final int totalRows;
  final int importedCount;
  final int updatedCount;
  final int skippedCount;
  final List<String> errors;

  const CsvImportResult({
    required this.totalRows,
    required this.importedCount,
    required this.updatedCount,
    required this.skippedCount,
    required this.errors,
  });
}

class CsvService {
  CsvService._();
  static final CsvService instance = CsvService._();

  static const List<String> csvHeaders = [
    'Name',
    'Barcode',
    'Code',
    'Category',
    'Type',
    'Unit',
    'SalePrice',
    'PurchasePrice',
    'WholesalePrice',
    'WholesaleMinQty',
    'SalesUnits',
    'MinStock',
    'CurrentStock_ReadOnly',
    'IsActive',
  ];

  /// Escapes a single cell for CSV RFC 4180 with spreadsheet formula injection protection.
  static String sanitizeCell(String? value) {
    if (value == null) return '';
    var text = value;

    // Formula injection prevention: if cell starts with =, +, -, @, \t, \r, prepend single quote '
    if (text.isNotEmpty) {
      final firstChar = text[0];
      if (firstChar == '=' ||
          firstChar == '+' ||
          firstChar == '-' ||
          firstChar == '@' ||
          firstChar == '\t' ||
          firstChar == '\r') {
        text = "'$text";
      }
    }

    // RFC 4180 quoting
    if (text.contains(',') ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r')) {
      text = '"${text.replaceAll('"', '""')}"';
    }

    return text;
  }

  /// Exports product catalog to UTF-8 CSV bytes with BOM (\uFEFF) for Arabic Excel compatibility.
  Future<Uint8List> exportProducts({bool templateOnly = false}) async {
    final buffer = StringBuffer();
    // UTF-8 BOM
    buffer.write('\uFEFF');

    // Header row
    buffer.writeln(csvHeaders.join(','));

    if (templateOnly) {
      // Sample row for user guidance
      buffer.writeln([
        sanitizeCell('مثال: سكر كنانة 10 كجم'),
        sanitizeCell('6281001234567'),
        sanitizeCell('SKU-101'),
        sanitizeCell('مواد غذائية'),
        sanitizeCell('product'),
        sanitizeCell('كيس'),
        '45000',
        '38000',
        '42000',
        '10',
        sanitizeCell('كرتونة:10:410000:390000'),
        '5',
        '0', // Informational only
        '1',
      ].join(','));
      return Uint8List.fromList(utf8.encode(buffer.toString()));
    }

    final db = await DatabaseHelper.instance.database;
    final products = await db.query('products', orderBy: 'name ASC');
    final allUnits = await DatabaseHelper.instance.getAllProductUnits();

    for (final row in products) {
      final pid = row['id'] as int;
      final units = allUnits[pid] ?? const <ProductUnit>[];
      final unitsStr = units.map((u) {
        final buf = StringBuffer('${u.unitName}:${u.conversionFactor}');
        if (u.salePrice != null) buf.write(':${u.salePrice}');
        if (u.wholesalePrice != null) {
          if (u.salePrice == null) buf.write(':');
          buf.write(':${u.wholesalePrice}');
        }
        return buf.toString();
      }).join(';');

      buffer.writeln([
        sanitizeCell(row['name'] as String? ?? ''),
        sanitizeCell(row['barcode'] as String? ?? ''),
        sanitizeCell(row['code'] as String? ?? ''),
        sanitizeCell(row['category'] as String? ?? ''),
        sanitizeCell(row['type'] as String? ?? 'product'),
        sanitizeCell(row['unit'] as String? ?? ''),
        ((row['sale_price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
        ((row['purchase_price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
        (row['wholesale_price'] as num?) != null
            ? ((row['wholesale_price'] as num).toDouble()).toStringAsFixed(2)
            : '',
        (row['wholesale_min_quantity'] as num?) != null
            ? ((row['wholesale_min_quantity'] as num).toDouble()).toStringAsFixed(2)
            : '',
        sanitizeCell(unitsStr),
        ((row['min_stock'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
        ((row['stock_quantity'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
        (row['is_active'] as int? ?? 1).toString(),
      ].join(','));
    }

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  /// Robust RFC 4180 CSV parser supporting multiline and quoted fields.
  static List<List<String>> parseCsv(String input) {
    final rows = <List<String>>[];
    var currentRow = <String>[];
    final currentField = StringBuffer();
    bool insideQuotes = false;
    int i = 0;

    // Strip BOM if present
    String text = input;
    if (text.startsWith('\uFEFF')) {
      text = text.substring(1);
    }

    while (i < text.length) {
      final char = text[i];

      if (insideQuotes) {
        if (char == '"') {
          // Check for escaped quote ""
          if (i + 1 < text.length && text[i + 1] == '"') {
            currentField.write('"');
            i += 2;
            continue;
          } else {
            insideQuotes = false;
            i++;
            continue;
          }
        } else {
          currentField.write(char);
          i++;
          continue;
        }
      } else {
        if (char == '"') {
          insideQuotes = true;
          i++;
          continue;
        } else if (char == ',') {
          currentRow.add(currentField.toString());
          currentField.clear();
          i++;
          continue;
        } else if (char == '\r') {
          if (i + 1 < text.length && text[i + 1] == '\n') {
            i++;
          }
          currentRow.add(currentField.toString());
          currentField.clear();
          rows.add(currentRow);
          currentRow = <String>[];
          i++;
          continue;
        } else if (char == '\n') {
          currentRow.add(currentField.toString());
          currentField.clear();
          rows.add(currentRow);
          currentRow = <String>[];
          i++;
          continue;
        } else {
          currentField.write(char);
          i++;
          continue;
        }
      }
    }

    if (currentField.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentField.toString());
      rows.add(currentRow);
    }

    return rows;
  }

  /// Strips spreadsheet formula protection prefix if present
  static String unescapeFormulaPrefix(String text) {
    if (text.startsWith("'") && text.length > 1) {
      final nextChar = text[1];
      if (nextChar == '=' ||
          nextChar == '+' ||
          nextChar == '-' ||
          nextChar == '@' ||
          nextChar == '\t' ||
          nextChar == '\r') {
        return text.substring(1);
      }
    }
    return text;
  }

  /// Parses CSV and generates an actionable preview before any database changes.
  Future<CsvImportPreview> previewImport(Uint8List bytes) async {
    final rawText = utf8.decode(bytes, allowMalformed: true);
    final rawRows = parseCsv(rawText);

    if (rawRows.isEmpty) {
      return const CsvImportPreview(
        rows: [],
        validNewCount: 0,
        existingCount: 0,
        errorCount: 1,
        canImport: false,
      );
    }

    // 1. Validate headers
    final headerRow = rawRows.first.map((h) => h.trim().toLowerCase()).toList();
    final nameIdx = headerRow.indexOf('name');
    final barcodeIdx = headerRow.indexOf('barcode');
    final codeIdx = headerRow.indexOf('code');
    final catIdx = headerRow.indexOf('category');
    final typeIdx = headerRow.indexOf('type');
    final unitIdx = headerRow.indexOf('unit');
    final salePriceIdx = headerRow.indexOf('saleprice');
    final purchPriceIdx = headerRow.indexOf('purchaseprice');
    final wholesalePriceIdx = headerRow.indexOf('wholesaleprice');
    final wholesaleMinQtyIdx = headerRow.indexOf('wholesaleminqty');
    final salesUnitsIdx = headerRow.indexOf('salesunits');
    final minStockIdx = headerRow.indexOf('minstock');
    final isActiveIdx = headerRow.indexOf('isactive');

    if (nameIdx == -1 || salePriceIdx == -1) {
      return CsvImportPreview(
        rows: [
          const CsvParsedRow(
            rowNumber: 1,
            name: '',
            salePrice: 0,
            isValid: false,
            errorMessage: 'الملف لا يحتوي على الأعمدة المطلوبة (Name, SalePrice)',
          ),
        ],
        validNewCount: 0,
        existingCount: 0,
        errorCount: 1,
        canImport: false,
      );
    }

    // Fetch existing products from database to detect duplicates
    final db = await DatabaseHelper.instance.database;
    final existingDbProducts = await db.query('products');
    final existingByName = <String, Map<String, dynamic>>{};
    final existingByBarcode = <String, Map<String, dynamic>>{};
    final existingByCode = <String, Map<String, dynamic>>{};

    for (final p in existingDbProducts) {
      final name = (p['name'] as String).trim().toLowerCase();
      existingByName[name] = p;
      final barcode = (p['barcode'] as String?)?.trim();
      if (barcode != null && barcode.isNotEmpty) {
        existingByBarcode[barcode] = p;
      }
      final code = (p['code'] as String?)?.trim();
      if (code != null && code.isNotEmpty) {
        existingByCode[code] = p;
      }
    }

    final parsedRows = <CsvParsedRow>[];
    int validNew = 0;
    int existing = 0;
    int error = 0;

    for (int r = 1; r < rawRows.length; r++) {
      final row = rawRows[r];
      if (row.isEmpty || (row.length == 1 && row[0].trim().isEmpty)) {
        continue; // Skip blank line
      }

      final rawName = nameIdx < row.length ? unescapeFormulaPrefix(row[nameIdx].trim()) : '';
      final rawBarcode = barcodeIdx != -1 && barcodeIdx < row.length
          ? unescapeFormulaPrefix(row[barcodeIdx].trim())
          : null;
      final rawCode = codeIdx != -1 && codeIdx < row.length
          ? unescapeFormulaPrefix(row[codeIdx].trim())
          : null;
      final rawCategory = catIdx != -1 && catIdx < row.length
          ? unescapeFormulaPrefix(row[catIdx].trim())
          : null;
      final rawType = typeIdx != -1 && typeIdx < row.length
          ? row[typeIdx].trim().toLowerCase()
          : Product.typeProduct;
      final rawUnit = unitIdx != -1 && unitIdx < row.length
          ? unescapeFormulaPrefix(row[unitIdx].trim())
          : null;
      final rawSale = salePriceIdx < row.length ? row[salePriceIdx].trim() : '';
      final rawPurch = purchPriceIdx != -1 && purchPriceIdx < row.length
          ? row[purchPriceIdx].trim()
          : '0';
      final rawWholesale = wholesalePriceIdx != -1 && wholesalePriceIdx < row.length
          ? row[wholesalePriceIdx].trim()
          : '';
      final rawWholesaleMin = wholesaleMinQtyIdx != -1 && wholesaleMinQtyIdx < row.length
          ? row[wholesaleMinQtyIdx].trim()
          : '';
      final rawSalesUnits = salesUnitsIdx != -1 && salesUnitsIdx < row.length
          ? unescapeFormulaPrefix(row[salesUnitsIdx].trim())
          : '';
      final rawMin = minStockIdx != -1 && minStockIdx < row.length
          ? row[minStockIdx].trim()
          : '0';
      final rawActive = isActiveIdx != -1 && isActiveIdx < row.length
          ? row[isActiveIdx].trim()
          : '1';

      if (rawName.isEmpty) {
        error++;
        parsedRows.add(CsvParsedRow(
          rowNumber: r + 1,
          name: '',
          salePrice: 0,
          isValid: false,
          errorMessage: 'اسم المنتج مطلوب',
        ));
        continue;
      }

      final salePrice = double.tryParse(rawSale);
      if (salePrice == null || salePrice < 0) {
        error++;
        parsedRows.add(CsvParsedRow(
          rowNumber: r + 1,
          name: rawName,
          salePrice: 0,
          isValid: false,
          errorMessage: 'سعر البيع غير صحيح',
        ));
        continue;
      }

      final purchasePrice = double.tryParse(rawPurch) ?? 0.0;
      if (purchasePrice < 0) {
        error++;
        parsedRows.add(CsvParsedRow(
          rowNumber: r + 1,
          name: rawName,
          salePrice: salePrice,
          isValid: false,
          errorMessage: 'سعر الشراء لا يمكن أن يكون سالباً',
        ));
        continue;
      }

      double? wholesalePrice;
      if (rawWholesale.isNotEmpty) {
        wholesalePrice = double.tryParse(rawWholesale);
        if (wholesalePrice == null || wholesalePrice < 0) {
          error++;
          parsedRows.add(CsvParsedRow(
            rowNumber: r + 1,
            name: rawName,
            salePrice: salePrice,
            isValid: false,
            errorMessage: 'سعر الجملة لا يمكن أن يكون سالباً',
          ));
          continue;
        }
      }

      double? wholesaleMinQty;
      if (rawWholesaleMin.isNotEmpty) {
        wholesaleMinQty = double.tryParse(rawWholesaleMin);
        if (wholesaleMinQty == null || wholesaleMinQty < 0) {
          error++;
          parsedRows.add(CsvParsedRow(
            rowNumber: r + 1,
            name: rawName,
            salePrice: salePrice,
            isValid: false,
            errorMessage: 'الحد الأدنى للجملة لا يمكن أن يكون سالباً',
          ));
          continue;
        }
      }

      List<ProductUnit>? parsedUnits;
      if (rawSalesUnits.isNotEmpty) {
        parsedUnits = [];
        bool unitError = false;
        final tokens = rawSalesUnits.split(';');
        for (final token in tokens) {
          final t = token.trim();
          if (t.isEmpty) continue;
          final parts = t.split(':');
          if (parts.length < 2) {
            unitError = true;
            break;
          }
          final uName = parts[0].trim();
          final factor = double.tryParse(parts[1].trim());
          if (uName.isEmpty || factor == null || factor <= 0) {
            unitError = true;
            break;
          }
          final uSalePrice = parts.length > 2 && parts[2].trim().isNotEmpty
              ? double.tryParse(parts[2].trim())
              : null;
          final uWholesalePrice = parts.length > 3 && parts[3].trim().isNotEmpty
              ? double.tryParse(parts[3].trim())
              : null;
          parsedUnits.add(ProductUnit(
            productId: 0,
            unitName: uName,
            conversionFactor: factor,
            salePrice: uSalePrice,
            wholesalePrice: uWholesalePrice,
          ));
        }
        if (unitError) {
          error++;
          parsedRows.add(CsvParsedRow(
            rowNumber: r + 1,
            name: rawName,
            salePrice: salePrice,
            isValid: false,
            errorMessage: 'وحدات البيع أو معامل التحويل غير صالح',
          ));
          continue;
        }
      }

      final minStock = double.tryParse(rawMin) ?? 0.0;
      final isActive = rawActive == '1' || rawActive.toLowerCase() == 'true';
      final type = rawType == Product.typeService ? Product.typeService : Product.typeProduct;

      // Duplicate match detection
      Map<String, dynamic>? match;
      if (rawBarcode != null && rawBarcode.isNotEmpty && existingByBarcode.containsKey(rawBarcode)) {
        match = existingByBarcode[rawBarcode];
      } else if (rawCode != null && rawCode.isNotEmpty && existingByCode.containsKey(rawCode)) {
        match = existingByCode[rawCode];
      } else if (existingByName.containsKey(rawName.toLowerCase())) {
        match = existingByName[rawName.toLowerCase()];
      }

      if (match != null) {
        existing++;
        parsedRows.add(CsvParsedRow(
          rowNumber: r + 1,
          name: rawName,
          barcode: rawBarcode?.isEmpty == true ? null : rawBarcode,
          code: rawCode?.isEmpty == true ? null : rawCode,
          category: rawCategory?.isEmpty == true ? null : rawCategory,
          type: type,
          unit: rawUnit?.isEmpty == true ? null : rawUnit,
          salePrice: salePrice,
          purchasePrice: purchasePrice,
          wholesalePrice: wholesalePrice,
          wholesaleMinQty: wholesaleMinQty,
          salesUnits: parsedUnits,
          minStock: minStock,
          isActive: isActive,
          isValid: true,
          isExisting: true,
          existingProductId: match['id'] as int?,
        ));
      } else {
        validNew++;
        parsedRows.add(CsvParsedRow(
          rowNumber: r + 1,
          name: rawName,
          barcode: rawBarcode?.isEmpty == true ? null : rawBarcode,
          code: rawCode?.isEmpty == true ? null : rawCode,
          category: rawCategory?.isEmpty == true ? null : rawCategory,
          type: type,
          unit: rawUnit?.isEmpty == true ? null : rawUnit,
          salePrice: salePrice,
          purchasePrice: purchasePrice,
          wholesalePrice: wholesalePrice,
          wholesaleMinQty: wholesaleMinQty,
          salesUnits: parsedUnits,
          minStock: minStock,
          isActive: isActive,
          isValid: true,
          isExisting: false,
        ));
      }
    }

    return CsvImportPreview(
      rows: parsedRows,
      validNewCount: validNew,
      existingCount: existing,
      errorCount: error,
      canImport: validNew > 0 || existing > 0,
    );
  }

  /// Applies the CSV import safely inside a SQLite transaction.
  /// CRITICAL SAFEGUARD: Stock quantities are NEVER modified by CSV catalog import!
  Future<CsvImportResult> applyImport({
    required List<CsvParsedRow> rows,
    required CsvDuplicateStrategy strategy,
  }) async {
    final validRows = rows.where((r) => r.isValid).toList();
    if (validRows.isEmpty) {
      throw ArgumentError('No valid rows to import');
    }

    final db = await DatabaseHelper.instance.database;
    return db.transaction((txn) async {
      int imported = 0;
      int updated = 0;
      int skipped = 0;
      final errors = <String>[];
      final now = DateTime.now().toIso8601String();

      for (final r in validRows) {
        if (r.isExisting) {
          if (strategy == CsvDuplicateStrategy.skip) {
            skipped++;
            continue;
          } else {
            // Update existing catalog fields ONLY.
            // NEVER alter stock_quantity or average_cost!
            final updateValues = <String, dynamic>{
              'name': r.name,
              'type': r.type,
              'sale_price': r.salePrice,
              'purchase_price': r.purchasePrice,
              'min_stock': r.minStock,
              'is_active': r.isActive ? 1 : 0,
              'updated_at': now,
            };
            if (r.barcode != null && r.barcode!.isNotEmpty) {
              updateValues['barcode'] = r.barcode;
            }
            if (r.code != null && r.code!.isNotEmpty) {
              updateValues['code'] = r.code;
            }
            if (r.category != null && r.category!.isNotEmpty) {
              updateValues['category'] = r.category;
            }
            if (r.unit != null && r.unit!.isNotEmpty) {
              updateValues['unit'] = r.unit;
            }
            if (r.wholesalePrice != null) {
              updateValues['wholesale_price'] = r.wholesalePrice;
            }
            if (r.wholesaleMinQty != null) {
              updateValues['wholesale_min_quantity'] = r.wholesaleMinQty;
            }

            await txn.update(
              'products',
              updateValues,
              where: 'id = ?',
              whereArgs: [r.existingProductId],
            );

            // Safe unit addition: only insert units that don't already exist for this product
            if (r.salesUnits != null &&
                r.salesUnits!.isNotEmpty &&
                r.existingProductId != null) {
              final existingUnits = await txn.query(
                'product_units',
                where: 'product_id = ?',
                whereArgs: [r.existingProductId],
              );
              final existingNames = existingUnits
                  .map((u) => (u['unit_name'] as String).trim().toLowerCase())
                  .toSet();
              for (final u in r.salesUnits!) {
                if (!existingNames.contains(u.unitName.trim().toLowerCase())) {
                  await txn.insert('product_units', {
                    'product_id': r.existingProductId,
                    'unit_name': u.unitName.trim(),
                    'conversion_factor': u.conversionFactor,
                    'sale_price': u.salePrice,
                    'wholesale_price': u.wholesalePrice,
                    'is_default_sale': u.isDefaultSale ? 1 : 0,
                  });
                }
              }
            }

            updated++;
          }
        } else {
          // Insert new product record. Initial stock is 0.
          // Stock additions must go through opening stock, adjustments, or purchases.
          final newPid = await txn.insert('products', {
            'name': r.name,
            'barcode': r.barcode,
            'code': r.code,
            'category': r.category,
            'type': r.type,
            'unit': r.unit,
            'sale_price': r.salePrice,
            'purchase_price': r.purchasePrice,
            'wholesale_price': r.wholesalePrice,
            'wholesale_min_quantity': r.wholesaleMinQty,
            'stock_quantity': 0.0,
            'min_stock': r.minStock,
            'is_taxable': 1,
            'is_active': r.isActive ? 1 : 0,
            'cost_status': Product.costStatusUnknown,
            'created_at': now,
            'updated_at': now,
          });

          if (r.salesUnits != null && r.salesUnits!.isNotEmpty) {
            for (final u in r.salesUnits!) {
              await txn.insert('product_units', {
                'product_id': newPid,
                'unit_name': u.unitName.trim(),
                'conversion_factor': u.conversionFactor,
                'sale_price': u.salePrice,
                'wholesale_price': u.wholesalePrice,
                'is_default_sale': u.isDefaultSale ? 1 : 0,
              });
            }
          }

          imported++;
        }
      }

      // Record audit log event
      await txn.insert('audit_log', {
        'action': 'csv_import',
        'entity_type': 'products_csv',
        'entity_id': imported + updated,
        'details':
            'imported=$imported updated=$updated skipped=$skipped strategy=${strategy.name}',
        'timestamp': now,
      });

      return CsvImportResult(
        totalRows: rows.length,
        importedCount: imported,
        updatedCount: updated,
        skippedCount: skipped,
        errors: errors,
      );
    });
  }
}
