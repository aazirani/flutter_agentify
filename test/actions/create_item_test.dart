import 'dart:convert';

import 'package:flutter_agentify/domain/actions/items_actions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/actions_harness.dart';

void main() {
  test('creates the item and records a verified receipt', () async {
    final h = ActionsHarness();
    final result = await h.call('create_item', {
      'title': 'Milk',
      'description': 'Oat',
    });
    final item = jsonDecode(result.content) as Map;
    expect(item['title'], 'Milk');
    expect((await h.items.getItem(item['id'] as String))?.description, 'Oat');
    final receipt = result.receipts.single;
    expect(receipt.summary, 'Created item "Milk"');
    expect(receipt.resource, 'items');
    expect(receipt.ids, [item['id']]);
    expect(receipt.verified, isTrue);
  });

  test('trims the title', () async {
    final h = ActionsHarness();
    await h.call('create_item', {'title': '  Milk '});
    expect((await h.items.getItems()).single.title, 'Milk');
  });

  test('a title of only spaces is invalid_input and writes nothing', () async {
    final h = ActionsHarness();
    await expectLater(
      h.call('create_item', {'title': '   '}),
      failsWith('invalid_input'),
    );
    expect(await h.items.getItemCount(), 0);
  });

  test('a 201-character title is invalid_input and writes nothing', () async {
    final h = ActionsHarness();
    await expectLater(
      h.call('create_item', {'title': 'a' * 201}),
      failsWith('invalid_input'),
    );
    expect(await h.items.getItemCount(), 0);
  });

  test('a typed call from the UI is validated too', () async {
    final h = ActionsHarness();
    await expectLater(
      h.registry.run(h.actions.createItem, const CreateItemInput(title: '  ')),
      failsWith('invalid_input'),
    );
    await expectLater(
      h.registry.run(h.actions.createItem, CreateItemInput(title: 'a' * 201)),
      failsWith('invalid_input'),
    );
    expect(await h.items.getItemCount(), 0);
    await h.registry.run(
      h.actions.createItem,
      const CreateItemInput(title: ' Milk ', description: ' '),
    );
    final item = (await h.items.getItems()).single;
    expect(item.title, 'Milk');
    expect(item.description, isNull);
  });

  test('an empty description is stored as null', () async {
    final h = ActionsHarness();
    await h.call('create_item', {'title': 'Milk', 'description': '  '});
    expect((await h.items.getItems()).single.description, isNull);
  });
}
