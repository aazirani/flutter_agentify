import 'dart:convert';

import 'package:flutter_agentify/domain/actions/items_actions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/actions_harness.dart';

void main() {
  test('updates the title and leaves the description', () async {
    final h = ActionsHarness();
    final item = await h.items.createItem(title: 'Milk', description: 'Oat');
    final result = await h.call('update_item', {
      'id': item.id,
      'title': ' Bread ',
    });
    expect((jsonDecode(result.content) as Map)['title'], 'Bread');
    final stored = await h.items.getItem(item.id);
    expect(stored?.title, 'Bread');
    expect(stored?.description, 'Oat');
    expect(result.receipts.single.summary, 'Renamed item to "Bread"');
    expect(result.receipts.single.key, 'renamed_item');
    expect(result.receipts.single.verified, isTrue);
  });

  test('changing the description says so in the receipt', () async {
    final h = ActionsHarness();
    final item = await h.items.createItem(title: 'Milk');
    final result = await h.call('update_item', {
      'id': item.id,
      'description': 'Oat',
    });
    expect((await h.items.getItem(item.id))?.description, 'Oat');
    expect(result.receipts.single.key, 'changed_item_description');
  });

  test('changing both says Updated', () async {
    final h = ActionsHarness();
    final item = await h.items.createItem(title: 'Milk');
    final result = await h.call('update_item', {
      'id': item.id,
      'title': 'Bread',
      'description': 'Rye',
    });
    expect(result.receipts.single.summary, 'Updated item "Bread"');
  });

  test('lengths count code points, not UTF-16 units', () async {
    final h = ActionsHarness();
    final item = await h.items.createItem(title: 'Milk');
    await h.registry.run(
      h.actions.updateItem,
      UpdateItemInput(id: item.id, title: '😀' * 200),
    );
    await expectLater(
      h.registry.run(
        h.actions.updateItem,
        UpdateItemInput(id: item.id, title: '😀' * 201),
      ),
      failsWith('invalid_input'),
    );
  });

  test('an empty description clears it', () async {
    final h = ActionsHarness();
    final item = await h.items.createItem(title: 'Milk', description: 'Oat');
    final result = await h.call('update_item', {
      'id': item.id,
      'description': '',
    });
    expect((await h.items.getItem(item.id))?.description, isNull);
    expect(result.receipts.single.key, 'cleared_item_description');
  });

  test('no title and no description is invalid_input', () async {
    final h = ActionsHarness();
    final item = await h.items.createItem(title: 'Milk');
    await expectLater(
      h.call('update_item', {'id': item.id}),
      failsWith('invalid_input'),
    );
  });

  test('a blank title is invalid_input and changes nothing', () async {
    final h = ActionsHarness();
    final item = await h.items.createItem(title: 'Milk');
    await expectLater(
      h.call('update_item', {'id': item.id, 'title': '  '}),
      failsWith('invalid_input'),
    );
    expect((await h.items.getItem(item.id))?.title, 'Milk');
  });

  test('a typed call from the UI is validated too', () async {
    final h = ActionsHarness();
    final item = await h.items.createItem(title: 'Milk');
    await expectLater(
      h.registry.run(
        h.actions.updateItem,
        UpdateItemInput(id: item.id, title: ' '),
      ),
      failsWith('invalid_input'),
    );
    await expectLater(
      h.registry.run(h.actions.updateItem, UpdateItemInput(id: item.id)),
      failsWith('invalid_input'),
    );
    expect((await h.items.getItem(item.id))?.title, 'Milk');
  });

  test('an unknown id fails with not_found', () async {
    final h = ActionsHarness();
    await expectLater(
      h.call('update_item', {'id': 'nope', 'title': 'x'}),
      failsWith('not_found'),
    );
  });
}
