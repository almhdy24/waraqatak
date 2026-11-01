import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Single Stock Writer Guard Tests (D4 & INV-10..13)', () {
    test('StockLedger.record is defined and serves as authoritative stock movement writer', () {
      final stockLedgerFile = File('lib/services/accounting/stock_ledger.dart');
      expect(stockLedgerFile.existsSync(), isTrue);

      final content = stockLedgerFile.readAsStringSync();
      expect(content.contains('class StockLedger'), isTrue);
      expect(content.contains('static Future<int> record('), isTrue);
    });

    test('DatabaseHelper._insertStockMovement delegates strictly to StockLedger.record', () {
      final dbHelperFile = File('lib/database/database_helper.dart');
      expect(dbHelperFile.existsSync(), isTrue);

      final content = dbHelperFile.readAsStringSync();
      final startIndex = content.indexOf('Future<void> _insertStockMovement(');
      expect(startIndex, isNot(-1));

      final endIndex = content.indexOf('Future<List<StockMovement>> getStockMovements(', startIndex);
      expect(endIndex, isNot(-1));

      final methodBody = content.substring(startIndex, endIndex);
      expect(
        methodBody.contains('StockLedger.record('),
        isTrue,
        reason: 'DatabaseHelper._insertStockMovement must delegate directly to StockLedger.record',
      );
    });

    test('InventoryCostingService.onStockAdjusted routes strictly to StockLedger.record', () {
      final serviceFile = File('lib/services/inventory_costing_service.dart');
      expect(serviceFile.existsSync(), isTrue);

      final content = serviceFile.readAsStringSync();
      final startIndex = content.indexOf('static Future<void> onStockAdjusted(');
      expect(startIndex, isNot(-1));

      final endIndex = content.indexOf('static Future<void> reconcileProductCost(', startIndex);
      expect(endIndex, isNot(-1));

      final methodBody = content.substring(startIndex, endIndex);
      expect(
        methodBody.contains('StockLedger.record('),
        isTrue,
        reason: 'InventoryCostingService.onStockAdjusted must delegate to StockLedger.record',
      );
    });

    test('DatabaseRepairService Option A routes strictly to StockLedger.record', () {
      final serviceFile = File('lib/services/database_repair_service.dart');
      expect(serviceFile.existsSync(), isTrue);

      final content = serviceFile.readAsStringSync();
      final startIndex = content.indexOf('if (preview.option == PurchaseRepairOption.optionA)');
      expect(startIndex, isNot(-1));

      final endIndex = content.indexOf('} else {', startIndex);
      expect(endIndex, isNot(-1));

      final optionABody = content.substring(startIndex, endIndex);
      expect(
        optionABody.contains('StockLedger.record('),
        isTrue,
        reason: 'DatabaseRepairService Option A must route to StockLedger.record',
      );
    });

    test('Source scan: No unauthorized direct inserts into stock_movements in lib/', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final insertPattern = RegExp(r'''(\.insert\(\s*['"]stock_movements['"]|INTO\s+stock_movements)''', caseSensitive: false);
      final allowedFiles = <String>{
        'lib/services/accounting/stock_ledger.dart', // The single authoritative writer
        'lib/services/backup_service.dart', // Raw restore of database tables
        'lib/database/database_helper.dart', // Legacy migration routines (< v24)
      };

      final violatingLocations = <String>[];

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        final normalizedPath = entity.path.replaceAll(r'\', '/');
        if (allowedFiles.contains(normalizedPath)) continue;

        final lines = entity.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (insertPattern.hasMatch(line)) {
            violatingLocations.add('$normalizedPath:${i + 1}: $line');
          }
        }
      }

      expect(
        violatingLocations,
        isEmpty,
        reason: 'Direct inserts into stock_movements outside StockLedger are prohibited: $violatingLocations',
      );
    });
  });
}
