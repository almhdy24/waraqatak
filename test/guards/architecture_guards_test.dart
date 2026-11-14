import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final libDir = Directory('lib');

  group('P2: Architecture Source Guards', () {
    // Guard (a): resolveItemPrice single entry point guard
    test(
      'Guard (a): No file under lib/ other than document_service.dart calls resolveItemPrice directly',
      () {
        final violatingFiles = <String>[];
        final allowlist = <String, String>{
          // 'lib/services/document_service.dart': 'Definition and internal delegation',
        };

        for (final file in libDir.listSync(recursive: true).whereType<File>()) {
          if (!file.path.endsWith('.dart')) continue;
          if (file.path
              .replaceAll('\\', '/')
              .endsWith('lib/services/document_service.dart')) {
            continue;
          }

          final content = file.readAsStringSync();
          if (content.contains('resolveItemPrice(')) {
            final normalized = file.path.replaceAll('\\', '/');
            if (!allowlist.containsKey(normalized)) {
              violatingFiles.add(
                '${file.path}: calls resolveItemPrice directly instead of resolveLinePrice',
              );
            }
          }
        }

        expect(
          violatingFiles,
          isEmpty,
          reason:
              'All line repricing must route through DocumentService.resolveLinePrice:\n${violatingFiles.join('\n')}',
        );
      },
    );

    // Guard (b): DocumentItemForm usage parameter completeness guard
    test(
      'Guard (b): Every DocumentItemForm in lib/screens passes unit/wholesale parameters or is explicitly allowlisted',
      () {
        final screensDir = Directory('lib/screens');
        final violatingCalls = <String>[];

        // Allowlist of screens where DocumentItemForm is intentionally used without custom units/wholesale
        final allowlist = <String, String>{
          'lib/screens/purchase_screen.dart':
              'Purchases operate strictly in base units and use purchase price (usePurchasePrice: true)',
        };

        for (final file
            in screensDir.listSync(recursive: true).whereType<File>()) {
          if (!file.path.endsWith('.dart')) continue;
          final normalized = file.path.replaceAll('\\', '/');
          final content = file.readAsStringSync();

          if (content.contains('DocumentItemForm(')) {
            if (allowlist.containsKey(normalized)) {
              continue;
            }

            // Must pass unit and wholesale parameters
            final requiredSubstrings = [
              'wholesalePricingEnabled',
              'pricingCategory',
              'customerPricingCategory',
              'saleUnit',
              'unitConversionFactor',
            ];

            for (final req in requiredSubstrings) {
              if (!content.contains(req)) {
                violatingCalls.add(
                  '$normalized: DocumentItemForm missing parameter "$req"',
                );
              }
            }
          }
        }

        expect(
          violatingCalls,
          isEmpty,
          reason:
              'Screens invoking DocumentItemForm must pass all unit and tier parameters:\n${violatingCalls.join('\n')}',
        );
      },
    );

    // Guard (c): Stock availability comparison against stock_quantity exists ONLY inside _assertSaleStockAvailable
    test(
      'Guard (c): No stock availability check (< stock or stock < ...) exists outside authoritative validator',
      () {
        final violatingLines = <String>[];

        // Allowlist for informational UI warnings and display reads that do NOT validate/gate transactions
        final allowlist = <String, String>{
          'lib/screens/invoice_screen.dart':
              'Informational non-blocking warning snackbar for low stock',
          'lib/services/pos_cart.dart':
              'In-memory cart validation against product.stockQuantity before dispatch',
          'lib/database/database_helper.dart':
              'Authoritative validator _assertSaleStockAvailable and purchase cancellation reversal checks',
        };

        for (final file in libDir.listSync(recursive: true).whereType<File>()) {
          if (!file.path.endsWith('.dart')) continue;
          final normalized = file.path.replaceAll('\\', '/');
          if (allowlist.containsKey(normalized)) continue;

          final lines = file.readAsLinesSync();
          for (int i = 0; i < lines.length; i++) {
            final line = lines[i];
            if ((line.contains('stock_quantity') ||
                    line.contains('stockQuantity')) &&
                (line.contains('<') ||
                    line.contains('>') ||
                    line.contains('<=') ||
                    line.contains('>='))) {
              // Check if this is an availability check
              if (line.contains('effectiveBase') ||
                  line.contains('effectiveQty') ||
                  line.contains('required')) {
                violatingLines.add('$normalized:${i + 1}: $line');
              }
            }
          }
        }

        expect(
          violatingLines,
          isEmpty,
          reason:
              'Stock availability checks must strictly reside in authoritative validator _assertSaleStockAvailable:\n${violatingLines.join('\n')}',
        );
      },
    );

    // Guard (d): No file under lib/screens/ or lib/widgets/ directly calls product mutation methods on DatabaseHelper
    test(
      'Guard (d): No file under lib/screens/ or lib/widgets/ calls DatabaseHelper.instance.insertProduct|updateProduct|deleteProduct|setProductActive',
      () {
        final violatingFiles = <String>[];
        final targetDirs = [Directory('lib/screens'), Directory('lib/widgets')];
        final forbiddenRegex = RegExp(
          r'DatabaseHelper\.instance\.(insertProduct|updateProduct|deleteProduct|setProductActive)\b',
        );

        for (final dir in targetDirs) {
          if (!dir.existsSync()) continue;
          for (final file in dir.listSync(recursive: true).whereType<File>()) {
            if (!file.path.endsWith('.dart')) continue;
            final content = file.readAsStringSync();
            if (forbiddenRegex.hasMatch(content)) {
              violatingFiles.add(file.path.replaceAll('\\', '/'));
            }
          }
        }

        expect(
          violatingFiles,
          isEmpty,
          reason:
              'Product mutations from screens/widgets must route through ProductService:\n${violatingFiles.join('\n')}',
        );
      },
    );
  });
}
