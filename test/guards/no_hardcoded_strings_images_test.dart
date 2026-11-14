import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Group G6: No Hardcoded Strings in Product Images Files Guard', () {
    final imageRelatedFiles = [
      'lib/services/image_storage_service.dart',
      'lib/widgets/product_image_picker.dart',
      'lib/widgets/product_image_thumbnail.dart',
      'lib/widgets/full_screen_image_viewer.dart',
      'lib/services/product_service.dart',
      'lib/utils/quick_sale_settings.dart',
      'lib/widgets/pos_product_tile.dart',
    ];

    test('no file contains isArabic ternary branching', () {
      final violations = <String>[];
      for (final path in imageRelatedFiles) {
        final file = File(path);
        if (!file.existsSync()) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.contains('isArabic ?') || line.contains('isArabic?')) {
            violations.add('$path:${i + 1}: $line');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'Forbidden isArabic ? ... : ... found:\n${violations.join('\n')}',
      );
    });

    test('no file interpolates raw \$e or e.toString() into user-facing presentation', () {
      final violations = <String>[];
      for (final path in imageRelatedFiles) {
        final file = File(path);
        if (!file.existsSync()) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.contains(r'AppSnackBar.showError(context, "$e"') ||
              line.contains(r"AppSnackBar.showError(context, '$e'") ||
              line.contains('AppSnackBar.showError(context, e.toString()') ||
              line.contains(r'Text("$e"') ||
              line.contains(r"Text('$e'") ||
              line.contains('Text(e.toString()')) {
            violations.add('$path:${i + 1}: $line');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'Forbidden error string presentation found:\n${violations.join('\n')}',
      );
    });

    test('no image widgets contain hardcoded non-symbol Text literals', () {
      final violations = <String>[];
      final allowedLiterals = {
        '',
        ' ',
        ':',
        '-',
        '+',
        '×',
        '·',
        '.',
        ',',
        '0',
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
      };

      // Match Text('literal') or Text("literal")
      final textRegex = RegExp(r"""Text\(\s*['"]([^'"$]+)['"]\s*[,)]""");

      for (final path in imageRelatedFiles) {
        final file = File(path);
        if (!file.existsSync()) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          // Skip comments
          if (line.trim().startsWith('//')) continue;

          for (final match in textRegex.allMatches(line)) {
            final literal = match.group(1)?.trim() ?? '';
            if (!allowedLiterals.contains(literal)) {
              violations.add('$path:${i + 1}: Text("$literal")');
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Hardcoded Text literals found in product image widgets:\n${violations.join('\n')}',
      );
    });
  });
}
