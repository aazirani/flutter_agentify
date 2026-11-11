import 'package:flutter_test/flutter_test.dart';

import '../support/actions_harness.dart';

void main() {
  test('needs approval and never offers always-allow', () {
    final h = ActionsHarness();
    expect(
      h.registry.requiresApproval('delete_items', {
        'ids': ['a'],
      }),
      isTrue,
    );
    expect(h.actions.deleteItems.allowAlways, isFalse);
  });

  test('an assistant call without approval deletes nothing', () async {
    final h = ActionsHarness();
    final a = await h.items.createItem(title: 'Milk');
    await expectLater(
      h.call('delete_items', {
        'ids': [a.id],
      }),
      failsWith('approval_required'),
    );
    expect(await h.items.getItem(a.id), isNotNull);
  });

  test('an approved call deletes all and records one receipt', () async {
    final h = ActionsHarness();
    final a = await h.items.createItem(title: 'Milk');
    final b = await h.items.createItem(title: 'Bread');
    final c = await h.items.createItem(title: 'Tea');
    final result = await h.call('delete_items', {
      'ids': [a.id, b.id, b.id],
    }, approved: true);
    expect(await h.items.getItemCount(), 1);
    expect(await h.items.getItem(c.id), isNotNull);
    expect(result.receipts.single.summary, 'Deleted 2 items');
    expect(result.receipts.single.key, 'deleted_items');
    expect(result.receipts.single.verified, isTrue);
  });

  test('one unknown id fails and deletes nothing', () async {
    final h = ActionsHarness();
    final a = await h.items.createItem(title: 'Milk');
    await expectLater(
      h.call('delete_items', {
        'ids': [a.id, 'nope'],
      }, approved: true),
      failsWith('not_found'),
    );
    expect(await h.items.getItem(a.id), isNotNull);
  });

  test('an empty list is invalid', () async {
    final h = ActionsHarness();
    await expectLater(
      h.call('delete_items', {'ids': <String>[]}, approved: true),
      failsWith('invalid_input'),
    );
  });

  test('the approval card names the items', () async {
    final h = ActionsHarness();
    final a = await h.items.createItem(title: 'Milk');
    final b = await h.items.createItem(title: 'Bread');
    expect(
      await h.actions.deleteItems.approvalSummary([a.id, b.id]),
      'Milk, Bread',
    );
  });

  test('a ui call deletes without approval', () async {
    final h = ActionsHarness();
    final a = await h.items.createItem(title: 'Milk');
    await h.registry.run(h.actions.deleteItems, [a.id]);
    expect(await h.items.getItemCount(), 0);
  });
}
