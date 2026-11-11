import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_agentify/domain/entities/item.dart';
import 'package:flutter_agentify/domain/entities/language/supported_languages.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

ToolCall _call(String name, String json) =>
    ToolCall(id: 'c_$name', name: name, rawArguments: json);

void main() {
  testWidgets(
    'the assistant creates an item and the list shows it with a receipt chip',
    (tester) async {
      final items = FakeItemsRepository();
      await pumpFullApp(
        tester,
        locale: english,
        items: items,
        provider: ScriptedProvider([
          ScriptedStep.toolCalls([_call('create_item', '{"title":"Milk"}')]),
          ScriptedStep.text('Added milk.'),
        ]),
      );
      await openAssistant(tester);
      await sendToAssistant(tester, 'Add milk');
      expect((await items.getItems()).single.title, 'Milk');
      expect(find.text('Milk'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Created item "Milk"'), findsOneWidget);
      expect(find.text('Added milk.'), findsOneWidget);
    },
  );

  // Follows the language list, so adding or removing a language needs no
  // change here.
  for (final language in kSupportedLanguages) {
    testWidgets('in ${language.englishName}, the receipt chip is translated', (
      tester,
    ) async {
      await pumpFullApp(
        tester,
        locale: Locale(language.locale),
        provider: ScriptedProvider([
          ScriptedStep.toolCalls([_call('create_item', '{"title":"Milk"}')]),
          ScriptedStep.text('Ok.'),
        ]),
      );
      await openAssistant(tester);
      await tester.enterText(find.byType(TextField).last, 'Add milk');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      final strings = jsonDecode(
        File('assets/lang/${language.locale}.json').readAsStringSync(),
      ) as Map<String, Object?>;
      final expected = (strings['receipt_created_item'] as String).replaceAll(
        '{title}',
        'Milk',
      );
      expect(find.widgetWithText(Chip, expected), findsOneWidget);
    });
  }

  testWidgets('delete waits for approval; approving removes the item', (
    tester,
  ) async {
    final items = FakeItemsRepository([
      Item(id: 'a', title: 'Milk', createdAt: DateTime(2026)),
    ]);
    await pumpFullApp(
      tester,
      locale: english,
      items: items,
      provider: ScriptedProvider([
        ScriptedStep.toolCalls([_call('delete_item', '{"id":"a"}')]),
        ScriptedStep.text('Deleted.'),
      ]),
    );
    await openAssistant(tester);
    await sendToAssistant(tester, 'Delete milk');
    expect(find.text('Approve this action?'), findsOneWidget);
    expect(await items.getItemCount(), 1);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(await items.getItemCount(), 0);
    expect(find.widgetWithText(Chip, 'Deleted item "Milk"'), findsOneWidget);
  });

  testWidgets('the assistant changes a description, then clears it', (
    tester,
  ) async {
    final items = FakeItemsRepository([
      Item(
        id: 'a',
        title: 'Milk',
        description: 'Oat',
        createdAt: DateTime(2026),
      ),
    ]);
    await pumpFullApp(
      tester,
      locale: english,
      items: items,
      provider: ScriptedProvider([
        ScriptedStep.toolCalls([
          _call('update_item', '{"id":"a","description":"Whole"}'),
        ]),
        ScriptedStep.text('Changed.'),
        ScriptedStep.toolCalls([
          _call('update_item', '{"id":"a","description":""}'),
        ]),
        ScriptedStep.text('Cleared.'),
      ]),
    );
    await openAssistant(tester);
    await sendToAssistant(tester, 'Describe milk as whole');
    expect((await items.getItem('a'))?.description, 'Whole');
    expect(
      find.widgetWithText(Chip, 'Changed the description of "Milk"'),
      findsOneWidget,
    );
    await sendToAssistant(tester, 'Remove its description');
    expect((await items.getItem('a'))?.description, isNull);
    expect(
      find.widgetWithText(Chip, 'Removed the description of "Milk"'),
      findsOneWidget,
    );
  });

  testWidgets('rejecting keeps the item', (tester) async {
    final items = FakeItemsRepository([
      Item(id: 'a', title: 'Milk', createdAt: DateTime(2026)),
    ]);
    await pumpFullApp(
      tester,
      locale: english,
      items: items,
      provider: ScriptedProvider([
        ScriptedStep.toolCalls([_call('delete_item', '{"id":"a"}')]),
        ScriptedStep.text('I left it.'),
      ]),
    );
    await openAssistant(tester);
    await sendToAssistant(tester, 'Delete milk');
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    expect(await items.getItemCount(), 1);
    expect(find.text('I left it.'), findsOneWidget);
  });

  testWidgets(
    'the request carries the home screen block with the visible items',
    (tester) async {
      final provider = ScriptedProvider([
        ScriptedStep.text('You have one item.'),
      ]);
      final items = FakeItemsRepository([
        Item(id: 'a', title: 'Milk', createdAt: DateTime(2026)),
      ]);
      await pumpFullApp(
        tester,
        locale: english,
        items: items,
        provider: provider,
      );
      await openAssistant(tester);
      await sendToAssistant(tester, 'What do I have?');
      final user = provider.requests.last.messages.first as UserMessage;
      expect(user.text, 'What do I have?');
      expect(user.context, contains('"screen":"home"'));
      expect(user.context, contains('"title":"Milk"'));
      expect(user.context, contains('"total":1'));
    },
  );
}
