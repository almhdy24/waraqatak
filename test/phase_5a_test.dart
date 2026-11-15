import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/utils/name_initials.dart';
import 'package:warqatek/widgets/app_status_colors.dart';

void main() {
  group('initialOf', () {
    test('empty / null / whitespace', () {
      expect(initialOf(''), '?');
      expect(initialOf(null), '?');
      expect(initialOf('   '), '?');
    });
    test('arabic and latin', () {
      expect(initialOf(' أحمد'), 'أ');
      expect(initialOf('ali'), 'A');
    });
    test('emoji does not throw', () {
      expect(() => initialOf('😀 x'), returnsNormally);
    });
  });

  group('AppStatusColors', () {
    Widget host(Brightness b, void Function(BuildContext) probe) => MaterialApp(
      key: UniqueKey(),
      theme: ThemeData(brightness: b, colorSchemeSeed: Colors.teal),
      home: Builder(
        builder: (c) {
          probe(c);
          return const SizedBox();
        },
      ),
    );

    testWidgets('success differs between light and dark', (t) async {
      Color? light, dark;
      await t.pumpWidget(
        host(
          Brightness.light,
          (c) => light = AppStatusColors.fg(c, AppStatus.success),
        ),
      );
      await t.pumpWidget(
        host(
          Brightness.dark,
          (c) => dark = AppStatusColors.fg(c, AppStatus.success),
        ),
      );
      expect(light, isNot(dark));
    });

    testWidgets('adapt lifts dark colors only in dark mode', (t) async {
      Color? inLight, inDark;
      const base = Color(0xFF1A237E);
      await t.pumpWidget(
        host(Brightness.light, (c) => inLight = AppStatusColors.adapt(c, base)),
      );
      await t.pumpWidget(
        host(Brightness.dark, (c) => inDark = AppStatusColors.adapt(c, base)),
      );
      expect(inLight, base);
      expect(HSLColor.fromColor(inDark!).lightness, greaterThanOrEqualTo(0.68));
    });

    testWidgets('badge renders its label', (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppStatusBadge(label: 'OK', status: AppStatus.success),
          ),
        ),
      );
      expect(find.text('OK'), findsOneWidget);
    });
  });
}
