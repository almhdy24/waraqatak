import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Document Edit Movement Source Guards', () {
    test('Only _applyDocumentEditStockDeltas writes stock movements when editing issued documents', () {
      final dbHelperFile = File('lib/database/database_helper.dart');
      expect(dbHelperFile.existsSync(), isTrue);

      final content = dbHelperFile.readAsStringSync();

      // 1. Verify _applyDocumentEditStockDeltas definition exists
      expect(
        content.contains('Future<void> _applyDocumentEditStockDeltas('),
        isTrue,
        reason: 'Authoritative single delta routine _applyDocumentEditStockDeltas must exist in DatabaseHelper',
      );

      // 2. Extract updateDocumentWithItems implementation
      final startIndex = content.indexOf('Future<void> updateDocumentWithItems(');
      expect(startIndex, isNot(-1));
      final endIndex = content.indexOf('Future<int> deleteDocument(', startIndex);
      expect(endIndex, isNot(-1));

      final updateMethodBody = content.substring(startIndex, endIndex);

      // 3. Verify _applyDocumentEditStockDeltas is invoked in updateDocumentWithItems
      expect(
        updateMethodBody.contains('_applyDocumentEditStockDeltas('),
        isTrue,
        reason: 'updateDocumentWithItems must invoke _applyDocumentEditStockDeltas when editing issued documents',
      );

      // 4. In updateDocumentWithItems, ensure all direct _insertStockMovement calls
      // are strictly guarded by first-time issuance: !oldWasIssued && newIsIssued
      final lines = updateMethodBody.split('\n');
      bool insideFirstTimeIssuanceGuard = false;
      int braceDepth = 0;
      int guardBraceDepth = 0;

      final allowlistedCalls = <int, String>{};
      final violatingLines = <String>[];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];

        if (line.contains('if (!oldWasIssued && newIsIssued)')) {
          insideFirstTimeIssuanceGuard = true;
          guardBraceDepth = braceDepth;
        }

        braceDepth += line.split('{').length - 1;
        braceDepth -= line.split('}').length - 1;

        if (insideFirstTimeIssuanceGuard && braceDepth <= guardBraceDepth) {
          insideFirstTimeIssuanceGuard = false;
        }

        if (line.contains('_insertStockMovement(')) {
          if (insideFirstTimeIssuanceGuard) {
            allowlistedCalls[i + 1] = 'First-time issuance of draft to issued status';
          } else {
            violatingLines.add('Line ${i + 1}: $line (must not write stock movements outside delta routine for edits)');
          }
        }
      }

      expect(
        violatingLines,
        isEmpty,
        reason: 'Direct stock movements inside updateDocumentWithItems are only permitted for first-time draft issuance.\n'
            'All edits of issued documents must delegate solely to _applyDocumentEditStockDeltas.\n'
            'Violations:\n${violatingLines.join('\n')}',
      );
      expect(allowlistedCalls.isNotEmpty, isTrue);
    });

    test('No screen or service outside database_helper.dart directly writes stock movements on edits', () {
      final libDir = Directory('lib');
      final violatingFiles = <String>[];
      final allowlist = <String, String>{
        'lib/database/database_helper.dart': 'Central authoritative database manager',
        'lib/services/accounting/stock_ledger.dart': 'Authoritative single stock writer for double-entry backbone',
        'lib/services/backup_service.dart': 'Backup restoration inserts raw tables including stock_movements',
        'lib/services/inventory_costing_service.dart': 'Initial opening stock movement on product creation',
        'lib/services/database_repair_service.dart': 'Guided safe repair tool with backup and confirmation for historical data reconciliation',
      };

      for (final file in libDir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final normalized = file.path.replaceAll('\\', '/');
        if (allowlist.containsKey(normalized)) continue;

        final text = file.readAsStringSync();
        if (text.contains('stock_movements') &&
            (text.contains('INSERT INTO stock_movements') ||
             text.contains('insert(\'stock_movements\'') ||
             text.contains('insert("stock_movements"'))) {
          violatingFiles.add('$normalized: directly writes to stock_movements');
        }
      }

      expect(violatingFiles, isEmpty, reason: 'Stock movements must only be written by DatabaseHelper or allowlisted services');
    });
  });
}
