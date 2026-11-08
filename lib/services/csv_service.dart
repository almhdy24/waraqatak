import 'dart:convert';
import 'dart:typed_data';

import '../core/catalog_events.dart';
import '../database/database_helper.dart';
import '../database/reference_pricing_dao.dart';
import '../features/reference_currency/reference_currency_feature.dart';
import '../features/wholesale/wholesale_feature.dart';
import '../models/product.dart';
import '../models/product_unit.dart';
import '../models/reference_pricing_types.dart';
import '../utils/reference_pricing_math.dart';

enum CsvDuplicateStrategy { skip, update }

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
  final String? priceCurrency;
  final double? referenceSalePrice;
  final double? referenceWholesalePrice;
  final double? referencePurchasePrice;

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
    this.priceCurrency,
    this.referenceSalePrice,
    this.referenceWholesalePrice,
    this.referencePurchasePrice,
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
  final int skippedReferenceFields;

  const CsvImportResult({
    required this.totalRows,
    required this.importedCount,
    required this.updatedCount,
    required this.skippedCount,
    required this.errors,
    this.skippedReferenceFields = 0,
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
    'PriceCurrency',
    'ReferenceSalePrice',
    'ReferenceWholesalePrice',
    'ReferencePurchasePrice',
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
      buffer.writeln(
        [
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
          '',
          '',
          '',
          '',
        ].join(','),
      );
      return Uint8List.fromList(utf8.encode(buffer.toString()));
    }

    final db = await DatabaseHelper.instance.database;
    final products = await db.query('products', orderBy: 'name ASC');
    final allUnits = await DatabaseHelper.instance.getAllProductUnits();

    String formatRefPrice(double? v) =>
        v != null ? double.parse(v.toStringAsFixed(4)).toString() : '';

    for (final row in products) {
      final pid = row['id'] as int;
      final units = allUnits[pid] ?? const <ProductUnit>[];
      final exportRef = ReferenceCurrencyFeature.isAvailable;
      final exportWs = WholesaleFeature.isAvailable;

      final unitsStr = units
          .map((u) {
            final buf = StringBuffer('${u.unitName}:${u.conversionFactor}');
            if (u.salePrice != null) buf.write(':${u.salePrice}');
            if (exportWs && u.wholesalePrice != null) {
              if (u.salePrice == null) buf.write(':');
              buf.write(':${u.wholesalePrice}');
            }
            return buf.toString();
          })
          .join(';');

      final priceCurr = exportRef
          ? (row['price_currency'] as String? ?? '')
          : '';
      final refSale = exportRef
          ? (row['reference_sale_price'] as num?)?.toDouble()
          : null;
      final refWs = exportRef
          ? (row['reference_wholesale_price'] as num?)?.toDouble()
          : null;
      final refPur = exportRef
          ? (row['reference_purchase_price'] as num?)?.toDouble()
          : null;

      buffer.writeln(
        [
          sanitizeCell(row['name'] as String? ?? ''),
          sanitizeCell(row['barcode'] as String? ?? ''),
          sanitizeCell(row['code'] as String? ?? ''),
          sanitizeCell(row['category'] as String? ?? ''),
          sanitizeCell(row['type'] as String? ?? 'product'),
          sanitizeCell(row['unit'] as String? ?? ''),
          ((row['sale_price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
          ((row['purchase_price'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(
            2,
          ),
          exportWs && (row['wholesale_price'] as num?) != null
              ? ((row['wholesale_price'] as num).toDouble()).toStringAsFixed(2)
              : '',
          exportWs && (row['wholesale_min_quantity'] as num?) != null
              ? ((row['wholesale_min_quantity'] as num).toDouble())
                    .toStringAsFixed(2)
              : '',
          sanitizeCell(unitsStr),
          ((row['min_stock'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
          ((row['stock_quantity'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(
            2,
          ),
          (row['is_active'] as int? ?? 1).toString(),
          sanitizeCell(priceCurr),
          formatRefPrice(refSale),
          formatRefPrice(refWs),
          formatRefPrice(refPur),
        ].join(','),
      );
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
        }
      } else {
        if (char == '"') {
          insideQuotes = true;
          i++;
        } else if (char == ',') {
          currentRow.add(currentField.toString());
          currentField.clear();
          i++;
        } else if (char == '\r') {
          if (i + 1 < text.length && text[i + 1] == '\n') {
            i++;
          }
          currentRow.add(currentField.toString());
          currentField.clear();
          rows.add(currentRow);
          currentRow = <String>[];
          i++;
        } else if (char == '\n') {
          currentRow.add(currentField.toString());
          currentField.clear();
          rows.add(currentRow);
          currentRow = <String>[];
          i++;
        } else {
          currentField.write(char);
          i++;
        }
      }
    }

    if (currentField.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentField.toString());
      rows.add(currentRow);
    }

    return rows;
  }

  /// Removes single quote prepended to prevent formula injection.
  static String unescapeFormulaPrefix(String cell) {
    if (cell.startsWith("'") && cell.length > 1) {
      final second = cell[1];
      if (second == '=' ||
          second == '+' ||
          second == '-' ||
          second == '@' ||
          second == '\t' ||
          second == '\r') {
        return cell.substring(1);
      }
    }
    return cell;
  }

  /// Decodes CSV bytes: UTF-8 first (strict); if that fails, Windows-1256
  /// (the encoding Arabic Excel uses for "CSV (Comma delimited)").
  static String decodeCsvBytes(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return _decodeWindows1256(bytes);
    }
  }

  static String _decodeWindows1256(List<int> bytes) {
    final b = StringBuffer();
    for (final v in bytes) {
      if (v < 0x80) {
        b.writeCharCode(v);
      } else if (v >= 0xC1 && v <= 0xD6) {
        b.writeCharCode(0x0621 + (v - 0xC1));
      } else if (v >= 0xD8 && v <= 0xDB) {
        b.writeCharCode(0x0637 + (v - 0xD8));
      } else {
        switch (v) {
          case 0xA0:
            b.write(' ');
          case 0xA1:
            b.write('\u060C');
          case 0xBA:
            b.write('\u061B');
          case 0xBF:
            b.write('\u061F');
          case 0xDC:
            b.write('\u0640');
          case 0xDD:
            b.write('\u0641');
          case 0xDE:
            b.write('\u0642');
          case 0xDF:
            b.write('\u0643');
          case 0xE1:
            b.write('\u0644');
          case 0xE3:
            b.write('\u0645');
          case 0xE4:
            b.write('\u0646');
          case 0xE5:
            b.write('\u0647');
          case 0xE6:
            b.write('\u0648');
          case 0xEC:
            b.write('\u0649');
          case 0xED:
            b.write('\u064A');
          case 0xF0:
            b.write('\u064B');
          case 0xF1:
            b.write('\u064C');
          case 0xF2:
            b.write('\u064D');
          case 0xF3:
            b.write('\u064E');
          case 0xF5:
            b.write('\u064F');
          case 0xF6:
            b.write('\u0650');
          case 0xF8:
            b.write('\u0651');
          case 0xFA:
            b.write('\u0652');
          case 0xD7:
            b.write('\u00D7');
          default:
            b.write('?');
        }
      }
    }
    return b.toString();
  }

  /// Parses CSV and generates an actionable preview before any database changes.
  Future<CsvImportPreview> previewImport(Uint8List bytes) async {
    final rawText = decodeCsvBytes(bytes);
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

    // Reference pricing optional column headers
    final priceCurrIdx = headerRow.indexOf('pricecurrency');
    final refSaleIdx = headerRow.indexOf('referencesaleprice');
    final refWsIdx = headerRow.indexOf('referencewholesaleprice');
    final refPurIdx = headerRow.indexOf('referencepurchaseprice');

    if (nameIdx == -1 || salePriceIdx == -1) {
      return CsvImportPreview(
        rows: [
          const CsvParsedRow(
            rowNumber: 1,
            name: '',
            salePrice: 0,
            isValid: false,
            errorMessage:
                'الملف لا يحتوي على الأعمدة المطلوبة (Name, SalePrice)',
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

    final rates = await ReferencePricingDao.getRates(db);
    final ratesMap = {for (final r in rates) r.code: r};
    final business = await DatabaseHelper.instance.getFirstBusiness();
    final baseCurrencyCode = business?.currencyCode.trim();

    final parsedRows = <CsvParsedRow>[];
    int validNew = 0;
    int existing = 0;
    int error = 0;

    for (int r = 1; r < rawRows.length; r++) {
      final row = rawRows[r];
      if (row.isEmpty || (row.length == 1 && row[0].trim().isEmpty)) {
        continue; // Skip blank line
      }

      final rawName = nameIdx < row.length
          ? unescapeFormulaPrefix(row[nameIdx].trim())
          : '';
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
      final rawWholesale =
          wholesalePriceIdx != -1 && wholesalePriceIdx < row.length
          ? row[wholesalePriceIdx].trim()
          : '';
      final rawWholesaleMin =
          wholesaleMinQtyIdx != -1 && wholesaleMinQtyIdx < row.length
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

      final rawPriceCurr = priceCurrIdx != -1 && priceCurrIdx < row.length
          ? unescapeFormulaPrefix(row[priceCurrIdx].trim()).toUpperCase()
          : '';
      final rawRefSale = refSaleIdx != -1 && refSaleIdx < row.length
          ? unescapeFormulaPrefix(row[refSaleIdx].trim())
          : '';
      final rawRefWs = refWsIdx != -1 && refWsIdx < row.length
          ? unescapeFormulaPrefix(row[refWsIdx].trim())
          : '';
      final rawRefPur = refPurIdx != -1 && refPurIdx < row.length
          ? unescapeFormulaPrefix(row[refPurIdx].trim())
          : '';

      if (rawName.isEmpty) {
        error++;
        parsedRows.add(
          CsvParsedRow(
            rowNumber: r + 1,
            name: '',
            salePrice: 0,
            isValid: false,
            errorMessage: 'اسم المنتج مطلوب',
          ),
        );
        continue;
      }

      final salePrice = double.tryParse(rawSale);
      if (salePrice == null || salePrice < 0) {
        error++;
        parsedRows.add(
          CsvParsedRow(
            rowNumber: r + 1,
            name: rawName,
            salePrice: 0,
            isValid: false,
            errorMessage: 'سعر البيع غير صحيح',
          ),
        );
        continue;
      }

      final purchasePrice = double.tryParse(rawPurch) ?? 0.0;
      if (purchasePrice < 0) {
        error++;
        parsedRows.add(
          CsvParsedRow(
            rowNumber: r + 1,
            name: rawName,
            salePrice: salePrice,
            isValid: false,
            errorMessage: 'سعر الشراء لا يمكن أن يكون سالباً',
          ),
        );
        continue;
      }

      double? wholesalePrice;
      if (WholesaleFeature.isAvailable && rawWholesale.isNotEmpty) {
        wholesalePrice = double.tryParse(rawWholesale);
        if (wholesalePrice == null || wholesalePrice < 0) {
          error++;
          parsedRows.add(
            CsvParsedRow(
              rowNumber: r + 1,
              name: rawName,
              salePrice: salePrice,
              isValid: false,
              errorMessage: 'سعر الجملة لا يمكن أن يكون سالباً',
            ),
          );
          continue;
        }
      }

      double? wholesaleMinQty;
      if (WholesaleFeature.isAvailable && rawWholesaleMin.isNotEmpty) {
        wholesaleMinQty = double.tryParse(rawWholesaleMin);
        if (wholesaleMinQty == null || wholesaleMinQty < 0) {
          error++;
          parsedRows.add(
            CsvParsedRow(
              rowNumber: r + 1,
              name: rawName,
              salePrice: salePrice,
              isValid: false,
              errorMessage: 'الحد الأدنى للجملة لا يمكن أن يكون سالباً',
            ),
          );
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
          parsedUnits.add(
            ProductUnit(
              productId: 0,
              unitName: uName,
              conversionFactor: factor,
              salePrice: uSalePrice,
              wholesalePrice: WholesaleFeature.isAvailable
                  ? uWholesalePrice
                  : null,
            ),
          );
        }
        if (unitError) {
          error++;
          parsedRows.add(
            CsvParsedRow(
              rowNumber: r + 1,
              name: rawName,
              salePrice: salePrice,
              isValid: false,
              errorMessage: 'وحدات البيع أو معامل التحويل غير صالح',
            ),
          );
          continue;
        }
      }

      final minStock = double.tryParse(rawMin) ?? 0.0;
      final isActive = rawActive == '1' || rawActive.toLowerCase() == 'true';
      final type = rawType == Product.typeService
          ? Product.typeService
          : Product.typeProduct;

      // Duplicate match detection
      Map<String, dynamic>? match;
      if (rawBarcode != null &&
          rawBarcode.isNotEmpty &&
          existingByBarcode.containsKey(rawBarcode)) {
        match = existingByBarcode[rawBarcode];
      } else if (rawCode != null &&
          rawCode.isNotEmpty &&
          existingByCode.containsKey(rawCode)) {
        match = existingByCode[rawCode];
      } else if (existingByName.containsKey(rawName.toLowerCase())) {
        match = existingByName[rawName.toLowerCase()];
      }

      // Validate reference pricing columns
      String? parsedPriceCurrency;
      double? parsedRefSale;
      double? parsedRefWs;
      double? parsedRefPur;
      String? refError;

      if (ReferenceCurrencyFeature.isAvailable && rawPriceCurr.isNotEmpty) {
        parsedPriceCurrency = rawPriceCurr;

        if (baseCurrencyCode == null) {
          refError = 'عملة التسعير غير معرّفة أو بلا سعر صرف';
        } else if (parsedPriceCurrency == baseCurrencyCode) {
          refError = 'عملة التسعير لا يمكن أن تكون العملة الأساسية';
        } else if (!ratesMap.containsKey(parsedPriceCurrency) ||
            !ReferencePricingMath.isValidRate(
              ratesMap[parsedPriceCurrency]!.rate,
            )) {
          refError = 'عملة التسعير غير معرّفة أو بلا سعر صرف';
        } else if (!ratesMap[parsedPriceCurrency]!.isActive) {
          final matchedCurrentCurrency = match != null
              ? match['price_currency'] as String?
              : null;
          if (matchedCurrentCurrency != parsedPriceCurrency) {
            refError = 'عملة التسعير مؤرشفة';
          }
        }

        if (refError == null) {
          if (rawRefSale.isEmpty) {
            refError = 'السعر المرجعي للبيع مطلوب';
          } else {
            parsedRefSale = ReferencePricingMath.parseReferencePrice(
              rawRefSale,
              allowCommaDecimal: false,
            );
            if (parsedRefSale == null) {
              refError = 'السعر المرجعي للبيع مطلوب';
            }
          }
        }

        if (refError == null && rawRefWs.isNotEmpty) {
          parsedRefWs = ReferencePricingMath.parseReferencePrice(
            rawRefWs,
            allowCommaDecimal: false,
          );
          if (parsedRefWs == null) {
            refError = 'السعر المرجعي غير صحيح';
          }
        }

        if (refError == null && rawRefPur.isNotEmpty) {
          parsedRefPur = ReferencePricingMath.parseReferencePrice(
            rawRefPur,
            allowCommaDecimal: false,
          );
          if (parsedRefPur == null) {
            refError = 'السعر المرجعي غير صحيح';
          }
        }
      } else {
        if (rawRefSale.isNotEmpty ||
            rawRefWs.isNotEmpty ||
            rawRefPur.isNotEmpty) {
          refError = 'أعمدة السعر المرجعي تتطلب عملة تسعير';
        }
      }

      if (refError != null) {
        error++;
        parsedRows.add(
          CsvParsedRow(
            rowNumber: r + 1,
            name: rawName,
            salePrice: salePrice,
            isValid: false,
            errorMessage: refError,
          ),
        );
        continue;
      }

      if (match != null) {
        existing++;
        parsedRows.add(
          CsvParsedRow(
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
            priceCurrency: parsedPriceCurrency,
            referenceSalePrice: parsedRefSale,
            referenceWholesalePrice: parsedRefWs,
            referencePurchasePrice: parsedRefPur,
          ),
        );
      } else {
        validNew++;
        parsedRows.add(
          CsvParsedRow(
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
            priceCurrency: parsedPriceCurrency,
            referenceSalePrice: parsedRefSale,
            referenceWholesalePrice: parsedRefWs,
            referencePurchasePrice: parsedRefPur,
          ),
        );
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
      int skippedReferenceFields = 0;
      final errors = <String>[];
      final now = DateTime.now().toIso8601String();

      for (final r in validRows) {
        if (r.isExisting) {
          if (strategy == CsvDuplicateStrategy.skip) {
            skipped++;
            continue;
          } else {
            // Read current product from database inside txn
            final existingProdRows = await txn.query(
              'products',
              columns: [
                'id',
                'price_currency',
                'reference_wholesale_price',
                'reference_purchase_price',
              ],
              where: 'id = ?',
              whereArgs: [r.existingProductId],
              limit: 1,
            );
            final existingProd = existingProdRows.isNotEmpty
                ? existingProdRows.first
                : null;
            final currentCurrency = existingProd?['price_currency'] as String?;
            final curRefWs = existingProd?['reference_wholesale_price'];
            final curRefPur = existingProd?['reference_purchase_price'];

            final updateValues = <String, dynamic>{
              'name': r.name,
              'type': r.type,
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
            if (r.wholesaleMinQty != null) {
              updateValues['wholesale_min_quantity'] = r.wholesaleMinQty;
            }

            if (r.priceCurrency != null) {
              try {
                await ReferencePricingDao.assertAssignable(
                  txn,
                  r.priceCurrency!,
                  currentCurrency: currentCurrency,
                );
                final d = await ReferencePricingDao.computeDerivedPrices(
                  txn,
                  currencyCode: r.priceCurrency!,
                  referenceSale: r.referenceSalePrice,
                  referenceWholesale: r.referenceWholesalePrice,
                  referencePurchase: r.referencePurchasePrice,
                );

                updateValues['price_currency'] = r.priceCurrency;
                updateValues['reference_sale_price'] = r.referenceSalePrice;
                updateValues['reference_wholesale_price'] =
                    r.referenceWholesalePrice;
                updateValues['reference_purchase_price'] =
                    r.referencePurchasePrice;
                updateValues['sale_price'] = d.sale;
                if (d.wholesale != null) {
                  updateValues['wholesale_price'] = d.wholesale;
                } else if (r.wholesalePrice != null) {
                  updateValues['wholesale_price'] = r.wholesalePrice;
                }
                if (d.purchase != null) {
                  updateValues['purchase_price'] = d.purchase;
                } else {
                  updateValues['purchase_price'] = r.purchasePrice;
                }
              } on ReferencePricingException catch (e) {
                errors.add('صف ${r.rowNumber}: ${e.message}');
                skipped++;
                continue;
              }
            } else {
              if (currentCurrency != null) {
                // Existing product has reference pricing, row lacks PriceCurrency
                skippedReferenceFields++; // Sale skipped every time
                if (curRefPur != null) {
                  skippedReferenceFields++;
                } else {
                  updateValues['purchase_price'] = r.purchasePrice;
                }
                if (curRefWs != null) {
                  if (r.wholesalePrice != null) {
                    skippedReferenceFields++;
                  }
                } else if (r.wholesalePrice != null) {
                  updateValues['wholesale_price'] = r.wholesalePrice;
                }
              } else {
                // Standard legacy product
                updateValues['sale_price'] = r.salePrice;
                updateValues['purchase_price'] = r.purchasePrice;
                if (r.wholesalePrice != null) {
                  updateValues['wholesale_price'] = r.wholesalePrice;
                }
              }
            }

            await txn.update(
              'products',
              updateValues,
              where: 'id = ?',
              whereArgs: [r.existingProductId],
            );

            if (r.priceCurrency != null &&
                currentCurrency != r.priceCurrency &&
                r.existingProductId != null) {
              await ReferencePricingDao.clearUnitReferences(
                txn,
                r.existingProductId!,
              );
            }

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
          // New product record
          final insertValues = <String, dynamic>{
            'name': r.name,
            'barcode': r.barcode,
            'code': r.code,
            'category': r.category,
            'type': r.type,
            'unit': r.unit,
            'wholesale_min_quantity': r.wholesaleMinQty,
            'stock_quantity': 0.0,
            'min_stock': r.minStock,
            'is_taxable': 1,
            'is_active': r.isActive ? 1 : 0,
            'cost_status': Product.costStatusUnknown,
            'created_at': now,
            'updated_at': now,
          };

          if (r.priceCurrency != null) {
            try {
              await ReferencePricingDao.assertAssignable(
                txn,
                r.priceCurrency!,
                currentCurrency: null,
              );
              final d = await ReferencePricingDao.computeDerivedPrices(
                txn,
                currencyCode: r.priceCurrency!,
                referenceSale: r.referenceSalePrice,
                referenceWholesale: r.referenceWholesalePrice,
                referencePurchase: r.referencePurchasePrice,
              );

              insertValues['price_currency'] = r.priceCurrency;
              insertValues['reference_sale_price'] = r.referenceSalePrice;
              insertValues['reference_wholesale_price'] =
                  r.referenceWholesalePrice;
              insertValues['reference_purchase_price'] =
                  r.referencePurchasePrice;
              insertValues['sale_price'] = d.sale;
              insertValues['purchase_price'] = d.purchase ?? r.purchasePrice;
              insertValues['wholesale_price'] = d.wholesale ?? r.wholesalePrice;
            } on ReferencePricingException catch (e) {
              errors.add('صف ${r.rowNumber}: ${e.message}');
              skipped++;
              continue;
            }
          } else {
            insertValues['sale_price'] = r.salePrice;
            insertValues['purchase_price'] = r.purchasePrice;
            insertValues['wholesale_price'] = r.wholesalePrice;
          }

          final newPid = await txn.insert('products', insertValues);

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
            'imported=$imported updated=$updated skipped=$skipped skippedReferenceFields=$skippedReferenceFields strategy=${strategy.name}',
        'timestamp': now,
      });

      if (imported + updated > 0) {
        CatalogEvents.notifyPricesChanged();
      }

      return CsvImportResult(
        totalRows: rows.length,
        importedCount: imported,
        updatedCount: updated,
        skippedCount: skipped,
        errors: errors,
        skippedReferenceFields: skippedReferenceFields,
      );
    });
  }
}
