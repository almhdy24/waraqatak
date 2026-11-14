import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no hardcoded strings, isArabic ternary, or raw e.toString in access code', () {
    final dirs = [
      'lib/services/access',
      'lib/screens/access',
      'lib/widgets/access',
    ];

    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    final isArabicRegex = RegExp(r'isArabic\s*\?');
    final rawToStringInUiRegex = RegExp(r'(showSnackBar|showDialog|Text\().*(e|error|err)\.toString\(\)');
    final rawToStringStandalone = RegExp(r'\b(e|error|err)\.toString\(\)');

    final violations = <String>[];

    for (final dirPath in dirs) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;

      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final lineNum = i + 1;

          // Check Arabic characters
          if (arabicRegex.hasMatch(line)) {
            violations.add('Arabic char in ${entity.path}:$lineNum -> ${line.trim()}');
          }

          // Check isArabic ?
          if (isArabicRegex.hasMatch(line)) {
            violations.add('isArabic ternary in ${entity.path}:$lineNum -> ${line.trim()}');
          }

          // Check UI displaying error.toString()
          if (rawToStringInUiRegex.hasMatch(line)) {
            violations.add('Raw error.toString() in UI call at ${entity.path}:$lineNum -> ${line.trim()}');
          }
        }
      }
    }

    expect(violations, isEmpty, reason: 'Found violations:\n${violations.join('\n')}');
  });
}
