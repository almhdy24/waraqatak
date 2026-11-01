import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/utils/version_matcher.dart';

void main() {
  group('VersionMatcher Dart Vectors (Batch 3)', () {
    test('Matches all shared JSON vectors identically to PHP', () {
      final file = File('test/fixtures/version_targeting_vectors.json');
      expect(file.existsSync(), isTrue);

      final vectors = jsonDecode(file.readAsStringSync()) as List;
      for (final v in vectors) {
        final desc = v['description'] as String;
        final appVersion = v['app_version'] as String?;
        final appBuild = v['app_build'] as int?;
        final min = v['min_version'] as String?;
        final max = v['max_version'] as String?;
        final expected = v['expected_match'] as bool;

        final actual = VersionMatcher.matches(
          appVersion: appVersion,
          appBuild: appBuild,
          minVersion: min,
          maxVersion: max,
        );

        expect(actual, equals(expected), reason: 'Vector "$desc" failed');
      }
    });

    test('isRangeValid correctly validates min and max bounds', () {
      expect(VersionMatcher.isRangeValid(minVersion: '1.1.0', maxVersion: '1.2.0'), isTrue);
      expect(VersionMatcher.isRangeValid(minVersion: '1.1.5', maxVersion: '1.1.5'), isTrue);
      expect(VersionMatcher.isRangeValid(minVersion: '1.1.5+10', maxVersion: '1.1.5+20'), isTrue);
      expect(VersionMatcher.isRangeValid(minVersion: '1.2.0', maxVersion: '1.1.0'), isFalse);
      expect(VersionMatcher.isRangeValid(minVersion: '1.1.5+20', maxVersion: '1.1.5+10'), isFalse);
      expect(VersionMatcher.isRangeValid(minVersion: null, maxVersion: '1.2.0'), isTrue);
      expect(VersionMatcher.isRangeValid(minVersion: '1.1.0', maxVersion: null), isTrue);
    });

    test('Orders 1.1.5-alpha+15 < 1.1.5-beta+16 correctly', () {
      final v15 = ParsedVersion.tryParse('1.1.5-alpha+15')!;
      final v16 = ParsedVersion.tryParse('1.1.5-beta+16')!;
      expect(v15.compareTo(v16, compareBuild: true), lessThan(0));
      expect(v16.compareTo(v15, compareBuild: true), greaterThan(0));

      expect(
        VersionMatcher.matches(appVersion: '1.1.5-alpha+15', minVersion: '1.1.5+16'),
        isFalse,
      );
      expect(
        VersionMatcher.matches(appVersion: '1.1.5-beta+16', minVersion: '1.1.5+16'),
        isTrue,
      );
    });

    test('Orders 1.1.5-beta+16 < 1.1.5-beta+17 correctly', () {
      final v16 = ParsedVersion.tryParse('1.1.5-beta+16')!;
      final v17 = ParsedVersion.tryParse('1.1.5-beta+17')!;
      expect(v16.compareTo(v17, compareBuild: true), lessThan(0));
      expect(v17.compareTo(v16, compareBuild: true), greaterThan(0));

      expect(
        VersionMatcher.matches(appVersion: '1.1.5-beta+16', minVersion: '1.1.5+17'),
        isFalse,
      );
      expect(
        VersionMatcher.matches(appVersion: '1.1.5-beta+17', minVersion: '1.1.5+17'),
        isTrue,
      );
    });

    test('Orders 1.1.5-beta+17 < 1.1.5-beta+18 correctly', () {
      final v17 = ParsedVersion.tryParse('1.1.5-beta+17')!;
      final v18 = ParsedVersion.tryParse('1.1.5-beta+18')!;
      expect(v17.compareTo(v18, compareBuild: true), lessThan(0));
      expect(v18.compareTo(v17, compareBuild: true), greaterThan(0));

      expect(
        VersionMatcher.matches(appVersion: '1.1.5-beta+17', minVersion: '1.1.5+18'),
        isFalse,
      );
      expect(
        VersionMatcher.matches(appVersion: '1.1.5-beta+18', minVersion: '1.1.5+18'),
        isTrue,
      );
    });
  });
}
