import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../support/actions_harness.dart';

void main() {
  test('returns items newest first with the total', () async {
    final h = ActionsHarness();
    for (final title in ['a', 'b', 'c']) {
      await h.items.createItem(title: title);
    }
    final result = jsonDecode((await h.call('list_items', {})).content) as Map;
    expect((result['items'] as List).map((i) => (i as Map)['title']), [
      'c',
      'b',
      'a',
    ]);
    expect(result['total'], 3);
    expect(h.registry.find('list_items')?.readOnly, isTrue);
  });

  test('limit caps the list but total counts everything', () async {
    final h = ActionsHarness();
    for (var i = 0; i < 5; i++) {
      await h.items.createItem(title: 'x$i');
    }
    final result =
        jsonDecode((await h.call('list_items', {'limit': 2})).content) as Map;
    expect(result['items'], hasLength(2));
    expect(result['total'], 5);
  });

  test('limit 0 or 201 is invalid_input', () async {
    final h = ActionsHarness();
    await expectLater(
      h.call('list_items', {'limit': 0}),
      failsWith('invalid_input'),
    );
    await expectLater(
      h.call('list_items', {'limit': 201}),
      failsWith('invalid_input'),
    );
  });

  test(
    'fifty items with long text still give valid JSON with the total',
    () async {
      final h = ActionsHarness();
      for (var i = 0; i < 50; i++) {
        await h.items.createItem(title: 't' * 200, description: 'd' * 2000);
      }
      final json = jsonDecode(
        (await h.call('list_items', {})).content,
      ) as Map<String, Object?>;
      expect(json.keys.first, 'total');
      expect(json['total'], 50);
      expect(json['items'], hasLength(50));
    },
  );
}
