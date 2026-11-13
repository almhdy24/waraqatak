import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:warqatek/widgets/amount_field.dart';

void main() {
  Widget host(
    TextEditingController controller, {
    bool showMultipliers = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: AmountField(
            controller: controller,
            showMultipliers: showMultipliers,
            decoration: const InputDecoration(labelText: 'Price'),
          ),
        ),
      ),
    );
  }

  testWidgets('groups typed digits', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(host(controller));

    await tester.enterText(find.byType(TextFormField), '1500');
    expect(controller.text, '1,500');
  });

  testWidgets('accepts Arabic digits', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(host(controller));

    await tester.enterText(find.byType(TextFormField), '٥٠٠٠');
    expect(controller.text, '5,000');
  });

  testWidgets('chips appear and multiply', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(host(controller, showMultipliers: true));

    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    expect(find.text('×10'), findsNothing);

    await tester.enterText(find.byType(TextFormField), '5');
    await tester.pumpAndSettle();
    expect(find.text('×10'), findsOneWidget);
    expect(find.text('×100'), findsOneWidget);
    expect(find.text('×1,000'), findsOneWidget);
    expect(find.text('×10,000'), findsOneWidget);
    expect(find.text('×1,000,000'), findsOneWidget);

    await tester.tap(find.text('×1,000'));
    await tester.pump();
    expect(controller.text, '5,000');

    await tester.tap(find.text('×10'));
    await tester.pump();
    expect(controller.text, '50,000');
  });

  testWidgets('no chips for zero', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(host(controller, showMultipliers: true));

    await tester.tap(find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField), '0');
    await tester.pump();
    expect(find.text('×10'), findsNothing);
  });

  testWidgets('no chips when showMultipliers false', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(host(controller, showMultipliers: false));

    await tester.tap(find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField), '5');
    await tester.pump();
    expect(find.text('×10'), findsNothing);
  });

  testWidgets('forwards onTap', (tester) async {
    final c = TextEditingController();
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AmountField(controller: c, onTap: () => taps++),
        ),
      ),
    );
    await tester.tap(find.byType(TextFormField));
    expect(taps, 1);
  });
}
