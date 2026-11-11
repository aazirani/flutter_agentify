import 'package:flutter_test/flutter_test.dart';

import '../support/actions_harness.dart';

void main() {
  test('needsApproval is true', () async {
    final h = ActionsHarness();
    expect(h.registry.requiresApproval('delete_item', {'id': 'a'}), isTrue);
  });

  test(
    'an assistant call without approval is refused and the item stays',
    () async {
      final h = ActionsHarness();
      final item = await h.items.createItem(title: 'Milk');
      await expectLater(
        h.call('delete_item', {'id': item.id}),
        failsWith('approval_required'),
      );
      expect(await h.items.getItem(item.id), isNotNull);
    },
  );

  test('an approved call deletes and records a receipt', () async {
    final h = ActionsHarness();
    final item = await h.items.createItem(title: 'Milk');
    final result = await h.call('delete_item', {'id': item.id}, approved: true);
    expect(await h.items.getItem(item.id), isNull);
    expect(result.receipts.single.summary, 'Deleted item "Milk"');
    expect(result.receipts.single.verified, isTrue);
    expect(result.content, contains(item.id));
  });

  test('a ui call deletes without approval', () async {
    final h = ActionsHarness();
    final item = await h.items.createItem(title: 'Milk');
    await h.registry.run(h.actions.deleteItem, item.id);
    expect(await h.items.getItem(item.id), isNull);
  });

  test(
    'the approval card names the item and never offers always-allow',
    () async {
      final harness = ActionsHarness();
      final item = await harness.items.createItem(title: 'Milk');
      expect(await harness.actions.deleteItem.approvalSummary(item.id), 'Milk');
      expect(await harness.actions.deleteItem.approvalSummary('nope'), isNull);
      expect(harness.actions.deleteItem.allowAlways, isFalse);
    },
  );

  test('an unknown id fails with not_found', () async {
    final h = ActionsHarness();
    await expectLater(
      h.call('delete_item', {'id': 'nope'}, approved: true),
      failsWith('not_found'),
    );
  });
}
