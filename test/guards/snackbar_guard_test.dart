import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final libDir = Directory('lib');

  group('SnackBar Guard Tests', () {
    test('No file under lib/ other than app_snackbar.dart contains showSnackBar or direct SnackBar instantiation', () {
      final violatingFiles = <String>[];
      final allowlist = <String, String>{
        // Only lib/widgets/app_snackbar.dart is allowed to show SnackBar directly.
      };

      for (final file in libDir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final normalized = file.path.replaceAll('\\', '/');
        if (normalized.endsWith('lib/widgets/app_snackbar.dart')) {
          continue;
        }

        final content = file.readAsStringSync();
        if (content.contains('showSnackBar(') || content.contains('SnackBar(')) {
          if (!allowlist.containsKey(normalized)) {
            violatingFiles.add(
              '${file.path}: contains unmediated SnackBar usage. Must use AppSnackBar.show(...) instead.',
            );
          }
        }
      }

      expect(
        violatingFiles,
        isEmpty,
        reason: 'All SnackBar presentations must route through AppSnackBar.show:\n${violatingFiles.join('\n')}',
      );
    });

    test('No SnackBar-related code specifies a Duration longer than 10 seconds', () {
      final violatingLines = <String>[];

      for (final file in libDir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.contains('Duration(seconds:') || line.contains('Duration(minutes:')) {
            // Check if near snackbar code
            final contextWindow = lines.sublist(
              i > 3 ? i - 3 : 0,
              i + 4 < lines.length ? i + 4 : lines.length,
            ).join(' ');

            if (contextWindow.contains('SnackBar') || contextWindow.contains('AppSnackBar')) {
              // Extract seconds or minutes
              final secondsMatch = RegExp(r'Duration\(seconds:\s*(\d+)\)').firstMatch(line);
              if (secondsMatch != null) {
                final seconds = int.parse(secondsMatch.group(1)!);
                if (seconds > 10) {
                  violatingLines.add('${file.path}:${i + 1}: Duration exceeds 10s: $line');
                }
              }
              if (line.contains('Duration(minutes:')) {
                violatingLines.add('${file.path}:${i + 1}: Minute-scale duration on SnackBar: $line');
              }
            }
          }
        }
      }

      expect(
        violatingLines,
        isEmpty,
        reason: 'No SnackBar duration may exceed 10 seconds:\n${violatingLines.join('\n')}',
      );
    });
  });
}
