import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final libDir = Directory('lib');

  group('Analytics Architectural Source Guards', () {
    // Guard 1: Single import point
    test(
      'Guard 1: Only lib/services/analytics/analytics_service.dart imports package:almhdy_analytics',
      () {
        final violatingFiles = <String>[];
        const allowedPath = 'lib/services/analytics/analytics_service.dart';

        for (final file in libDir.listSync(recursive: true).whereType<File>()) {
          if (!file.path.endsWith('.dart')) continue;
          final normalized = file.path.replaceAll('\\', '/');
          if (normalized.endsWith(allowedPath)) continue;

          final content = file.readAsStringSync();
          if (content.contains('package:almhdy_analytics/')) {
            violatingFiles.add(
              '$normalized imports package:almhdy_analytics directly',
            );
          }
        }

        expect(
          violatingFiles,
          isEmpty,
          reason:
              'Only AnalyticsService may import package:almhdy_analytics:\n${violatingFiles.join('\n')}',
        );
      },
    );

    // Guard 2: No database-layer calls
    test(
      'Guard 2: No analytics calls under lib/database/ or inside DatabaseHelper',
      () {
        final violatingFiles = <String>[];
        final dbDir = Directory('lib/database');

        if (dbDir.existsSync()) {
          for (final file
              in dbDir.listSync(recursive: true).whereType<File>()) {
            if (!file.path.endsWith('.dart')) continue;
            final normalized = file.path.replaceAll('\\', '/');
            final content = file.readAsStringSync();
            if (content.contains('AnalyticsService') ||
                content.contains('AnalyticsEvent')) {
              violatingFiles.add('$normalized contains analytics references');
            }
          }
        }

        final dbHelperFile = File('lib/database/database_helper.dart');
        if (dbHelperFile.existsSync()) {
          final content = dbHelperFile.readAsStringSync();
          if (content.contains('AnalyticsService') ||
              content.contains('AnalyticsEvent')) {
            violatingFiles.add('database_helper.dart calls analytics directly');
          }
        }

        expect(
          violatingFiles,
          isEmpty,
          reason:
              'Analytics code must never be called from DatabaseHelper or database layer:\n${violatingFiles.join('\n')}',
        );
      },
    );

    // Guard 3: Every event in code exists in the allowlist
    test(
      'Guard 3: Every event used in code exists in AnalyticsEvent allowlist',
      () {
        final allowedEventNames = <String>{
          'appOpened',
          'screenViewed',
          'documentCreated',
          'documentCancelled',
          'paymentRecorded',
          'productSaved',
          'contactSaved',
          'stocktakeFinalized',
          'reportOpened',
          'pdfShared',
          'csvExported',
          'csvImported',
          'backupCreated',
          'backupRestored',
          'paywallViewed',
          'activationStarted',
          'activationResult',
          'multiUserEnabled',
          'migrationResult',
          'errorCaught',
        };

        final violatingCalls = <String>[];
        final eventRegex = RegExp(r'AnalyticsEvent\.([a-zA-Z0-9_]+)');

        for (final file in libDir.listSync(recursive: true).whereType<File>()) {
          if (!file.path.endsWith('.dart')) continue;
          final normalized = file.path.replaceAll('\\', '/');
          if (normalized.endsWith(
            'lib/services/analytics/analytics_service.dart',
          )) {
            continue;
          }

          final content = file.readAsStringSync();
          for (final match in eventRegex.allMatches(content)) {
            final eventName = match.group(1);
            if (eventName != null && !allowedEventNames.contains(eventName)) {
              violatingCalls.add(
                '$normalized references unknown event: AnalyticsEvent.$eventName',
              );
            }
          }
        }

        expect(
          violatingCalls,
          isEmpty,
          reason:
              'All event emissions must use allowlisted AnalyticsEvent members:\n${violatingCalls.join('\n')}',
        );
      },
    );

    // Guard 4: No forbidden property keys appear in any track call
    test(
      'Guard 4: No forbidden property keys appear in any analytics track call',
      () {
        final forbiddenKeyRegex = RegExp(
          r'''['"](amount|price|cost|total|quantity|qty|product_name|barcode|category|customer_name|supplier_name|name|phone|mobile|doc_number|invoice_number|path|file|message|stack|stack_trace|license|license_key|key|user|username|password|user_id|actor)['"]\s*:''',
          caseSensitive: false,
        );

        final violatingFiles = <String>[];

        for (final file in libDir.listSync(recursive: true).whereType<File>()) {
          if (!file.path.endsWith('.dart')) continue;
          final normalized = file.path.replaceAll('\\', '/');
          if (normalized.endsWith(
            'lib/services/analytics/analytics_service.dart',
          )) {
            continue; // Definitions/checks in service itself
          }

          final content = file.readAsStringSync();
          if (content.contains('AnalyticsService.instance.track(')) {
            final trackCalls = content.split(
              'AnalyticsService.instance.track(',
            );
            for (int i = 1; i < trackCalls.length; i++) {
              final callBlock = trackCalls[i].split(');').first;
              final match = forbiddenKeyRegex.firstMatch(callBlock);
              if (match != null) {
                violatingFiles.add(
                  '$normalized contains forbidden key "${match.group(1)}" in track call',
                );
              }
            }
          }
        }

        expect(
          violatingFiles,
          isEmpty,
          reason:
              'Forbidden property keys detected in analytics calls:\n${violatingFiles.join('\n')}',
        );
      },
    );

    // Guard 5: Track calls are fire-and-forget and not awaited
    test('Guard 5: Analytics track calls are not awaited', () {
      final violatingCalls = <String>[];
      final awaitRegex = RegExp(r'await\s+AnalyticsService\.instance\.track\(');

      for (final file in libDir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final normalized = file.path.replaceAll('\\', '/');
        final content = file.readAsStringSync();

        if (awaitRegex.hasMatch(content)) {
          violatingCalls.add(
            '$normalized awaits AnalyticsService.instance.track',
          );
        }
      }

      expect(
        violatingCalls,
        isEmpty,
        reason:
            'Analytics calls must be fire-and-forget and never awaited:\n${violatingCalls.join('\n')}',
      );
    });
  });
}
