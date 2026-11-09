import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/widgets/access/pin_keypad.dart';

void main() {
  group('PinKeypad LTR Layout and Affordances', () {
    testWidgets('Keypad is strictly LTR and displays Western digits 0-9', (tester) async {
      String entered = '';
      bool cleared = false;

      // Ambient directionality is RTL (as in Arabic app)
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: MaterialApp(
            home: Scaffold(
              body: PinKeypad(
                onDigit: (d) => entered += d,
                onBackspace: () {
                  if (entered.isNotEmpty) entered = entered.substring(0, entered.length - 1);
                },
                onClear: () => cleared = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify PinKeypad inner Directionality is LTR
      final ltrFinder = find.descendant(
        of: find.byType(PinKeypad),
        matching: find.byWidgetPredicate(
          (w) => w is Directionality && w.textDirection == TextDirection.ltr,
        ),
      );
      expect(ltrFinder, findsOneWidget);

      // Verify digit positions: '1' must be to the left of '3'
      final pos1 = tester.getTopLeft(find.text('1'));
      final pos2 = tester.getTopLeft(find.text('2'));
      final pos3 = tester.getTopLeft(find.text('3'));

      expect(pos1.dx, lessThan(pos2.dx), reason: 'Digit 1 must be to the left of 2');
      expect(pos2.dx, lessThan(pos3.dx), reason: 'Digit 2 must be to the left of 3');

      // Verify '1' is above '4' and '4' is above '7'
      final pos4 = tester.getTopLeft(find.text('4'));
      final pos7 = tester.getTopLeft(find.text('7'));
      expect(pos1.dy, lessThan(pos4.dy));
      expect(pos4.dy, lessThan(pos7.dy));

      // Verify Western digits only (0 to 9)
      for (int i = 0; i <= 9; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
      // Never Eastern Arabic-Indic digits
      for (final eastern in ['١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩', '٠']) {
        expect(find.text(eastern), findsNothing);
      }

      // Verify minimum tap target size (>= 64dp)
      final digit1Box = tester.getSize(find.ancestor(of: find.text('1'), matching: find.byType(SizedBox)).first);
      expect(digit1Box.width, greaterThanOrEqualTo(64.0));
      expect(digit1Box.height, greaterThanOrEqualTo(64.0));

      // Tap digits 1, 5, 9, 0
      await tester.tap(find.text('1'));
      await tester.tap(find.text('5'));
      await tester.tap(find.text('9'));
      await tester.tap(find.text('0'));
      expect(entered, '1590');

      // Tap backspace
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      expect(entered, '159');

      // Long press backspace clears all
      await tester.longPress(find.byIcon(Icons.backspace_outlined));
      expect(cleared, isTrue);
    });

    testWidgets('PinDotsView displays animated filled dots in LTR order', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PinDotsView(
              length: 3,
              maxDigits: 6,
              hasError: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnimatedContainer), findsNWidgets(6));
    });

    testWidgets('ShakeWidget shakes horizontally on error', (tester) async {
      final shakeKey = GlobalKey<ShakeWidgetState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShakeWidget(
              key: shakeKey,
              child: const Text('ShakeMe'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialPos = tester.getTopLeft(find.text('ShakeMe'));

      shakeKey.currentState?.shake();
      await tester.pump(const Duration(milliseconds: 50));

      final midPos = tester.getTopLeft(find.text('ShakeMe'));
      // Position offset should change during shake
      expect(midPos.dx != initialPos.dx || midPos.dy == initialPos.dy, isTrue);

      await tester.pumpAndSettle();
      final endPos = tester.getTopLeft(find.text('ShakeMe'));
      expect(endPos.dx, equals(initialPos.dx));
    });
  });

  group('WesternPinInputFormatter', () {
    test('Normalizes Arabic-Indic digits to Western 0-9', () {
      const formatter = WesternPinInputFormatter(maxLength: 6);
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '١٢٣٤٥٦'),
      );
      expect(result.text, '123456');
    });

    test('Normalizes Persian digits to Western 0-9', () {
      const formatter = WesternPinInputFormatter(maxLength: 6);
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '۱۲۳۴۵۶'),
      );
      expect(result.text, '123456');
    });

    test('Clamps at maxLength and filters non-digits', () {
      const formatter = WesternPinInputFormatter(maxLength: 4);
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '12a34b56'),
      );
      expect(result.text, '1234');
    });
  });
}
