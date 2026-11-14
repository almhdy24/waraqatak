import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> arabic;

  setUpAll(() {
    final src = File(
      'lib/localization/app_localizations.dart',
    ).readAsStringSync();
    final re = RegExp(
      r'''_t\(\s*(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")''',
    );
    arabic = [
      for (final m in re.allMatches(src)) (m.group(1) ?? m.group(2) ?? ''),
    ];
  });

  test('finds the translations', () {
    expect(arabic.length, greaterThan(1000));
  });

  test('password is always called كلمة المرور', () {
    expect(arabic.where((s) => s.contains('كلمة سر')), isEmpty);
  });

  test('no stiff confirmation phrasing', () {
    expect(
      arabic.where((s) => s.contains('هل أنت متأكد') || s.contains('بالتأكيد')),
      isEmpty,
    );
  });

  test('tanween is written after the alif', () {
    expect(arabic.where((s) => s.contains('\u064B\u0627')), isEmpty);
  });

  test('digits are ASCII', () {
    final digits = RegExp('[\u0660-\u0669\u06F0-\u06F9]');
    expect(arabic.where(digits.hasMatch), isEmpty);
  });

  test('uses the ellipsis character, not three dots', () {
    expect(arabic.where((s) => s.contains('...')), isEmpty);
  });

  test('no stray Latin words in Arabic texts', () {
    const allowed = {
      'PDF',
      'CSV',
      'SKU',
      'Google',
      'Drive',
      'Play',
      'Cloud',
      'Tajawal',
      'SIL',
      'Open',
      'Font',
      'License',
      'XXXX',
      'Pro',
      'PIN',
      'EUR',
      'PNG',
      'JPG',
    };
    final bad = <String>[];
    for (final s in arabic) {
      final cleaned = s.replaceAll(
        RegExp(r'\$\{[^}]*\}|\$\{.*$|\$\w+|\\n|\\u[0-9a-fA-F]{4}'),
        '',
      );
      for (final m in RegExp(r'[A-Za-z]{2,}').allMatches(cleaned)) {
        if (!allowed.contains(m.group(0))) bad.add('${m.group(0)} in: $s');
      }
    }
    expect(bad, isEmpty);
  });
}
