import 'dart:convert';

import 'package:flutter_agentify/ai/screen_contexts.dart';
import 'package:flutter_agentify/presentation/providers/items_provider.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

void main() {
  test('home reports the total, at most 10 items and the selection', () async {
    final items = FakeItemsRepository();
    for (var i = 0; i < 25; i++) {
      await items.createItem(title: 'Item $i');
    }
    final container = setUpTestServices(items: items);
    final screens = buildScreenContexts(container);
    final first = (await items.getItems()).first;
    container.read(selectedItemIdsProvider.notifier).toggle(first.id);
    final view = screens['/']?.view;
    final result = await view?.call(
      NavigationState(route: '/', location: '/', selectedIds: [first.id]),
    ) as Map<String, Object?>;
    expect(result['screen'], 'home');
    expect(result['total'], 25);
    expect(result['items'], hasLength(10));
    expect((result['items'] as List).first, {
      'id': first.id,
      'title': first.title,
    });
    expect(result['selectedIds'], [first.id]);
  });

  test('rows carry a cut description and the block stays small', () async {
    final items = FakeItemsRepository();
    for (var i = 0; i < 12; i++) {
      await items.createItem(title: 'T' * 100, description: 'D' * 500);
    }
    await items.createItem(title: 'No description');
    final container = setUpTestServices(items: items);
    final view = buildScreenContexts(container)['/']?.view;
    final result = await view?.call(
      const NavigationState(route: '/', location: '/'),
    ) as Map<String, Object?>;
    final rows = (result['items'] as List).cast<Map<String, Object?>>();
    expect(rows.first.containsKey('description'), isFalse);
    expect(rows[1]['description'], '${'D' * 40}…');
    expect(rows[1]['title'], '${'T' * 40}…');
    expect(result['note'], contains('get_item'));
    expect(jsonEncode(result).length, lessThan(1800));
  });
}
