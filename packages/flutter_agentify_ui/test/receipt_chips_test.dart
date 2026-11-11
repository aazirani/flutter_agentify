import 'package:flutter/material.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_ui/flutter_agentify_ui.dart';
import 'package:flutter_agentify_ui/src/widgets/receipt_chips.dart';
import 'package:flutter_test/flutter_test.dart';

const _receipt = Receipt(
  resource: 'items',
  ids: ['a'],
  summary: 'Created item "Milk"',
  verified: true,
  key: 'created_item',
  args: {'title': 'Milk'},
);

Future<void> _pump(WidgetTester tester, AssistantStrings strings) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReceiptChips(receipts: const [_receipt], strings: strings),
        ),
      ),
    );

void main() {
  testWidgets('a receipt shows its translation when the app has one', (
    tester,
  ) async {
    await _pump(
      tester,
      AssistantStrings(
        receiptLabels: (r) => r.key == 'created_item'
            ? 'مورد «${r.args['title']}» ساخته شد'
            : null,
      ),
    );
    expect(find.text('مورد «Milk» ساخته شد'), findsOneWidget);
    final text = tester.widget<Text>(find.text('مورد «Milk» ساخته شد'));
    expect(text.textDirection, TextDirection.rtl);
  });

  testWidgets('without a translation, the English summary', (tester) async {
    await _pump(tester, const AssistantStrings());
    expect(find.text('Created item "Milk"'), findsOneWidget);
  });
}
