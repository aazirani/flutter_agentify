import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../support/actions_harness.dart';

void main() {
  test('returns the whole item without cutting the description', () async {
    final h = ActionsHarness();
    final description = 'd' * 2000;
    final item = await h.items.createItem(
      title: 't' * 200,
      description: description,
    );
    final result =
        jsonDecode((await h.call('get_item', {'id': item.id})).content) as Map;
    expect(result['id'], item.id);
    expect(result['title'], 't' * 200);
    expect(result['description'], description);
    expect(result['createdAt'], isNotNull);
  });

  test('an unknown id is not_found', () async {
    final h = ActionsHarness();
    await expectLater(
      h.call('get_item', {'id': 'nope'}),
      failsWith('not_found'),
    );
  });

  test('is read-only and needs no approval', () {
    final h = ActionsHarness();
    expect(h.registry.find('get_item')?.readOnly, isTrue);
    expect(h.registry.requiresApproval('get_item', {'id': 'a'}), isFalse);
  });
}
