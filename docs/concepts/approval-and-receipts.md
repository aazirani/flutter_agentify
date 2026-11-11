# Approval and receipts

Some actions ask the person before the assistant runs them. Every action that changes data leaves a receipt that says what changed.

## Why

A model can misread a request. Approval stops a wrong call before it runs. A receipt shows what really happened, whatever the model says in its reply.

## Which actions ask

An action asks when its `needsApproval(input)` returns true. Who is asked depends on the caller:

- **The assistant.** The run pauses and the chat shows an approval card. The card has Approve, Reject and, when the action allows it, Always allow. A rejection reaches the model as a `declined` error.
- **The UI.** It never pauses. The person already pressed the button. The registry skips the approval check for `Caller.ui`.
- **The command line.** The call fails unless it passes `--approved`.

This is the delete action, from [`lib/domain/actions/items_actions.dart`](../../lib/domain/actions/items_actions.dart):

```dart
  @override
  bool needsApproval(String input) => true;

  // A delete cannot be undone, so every one asks.
  @override
  bool get allowAlways => false;

  @override
  Future<String?> approvalSummary(String input) async =>
      (await items.getItem(input))?.title;
```

`approvalSummary` is the line the card shows, here the item's title. `delete_items` works the same way and shows up to five titles.

## Always allow

The card can offer "Always allow". After that, the action stops asking. An action that sets `allowAlways` to false never offers it, so every call asks. The settings screen has a button, "Ask again before every action", that forgets every "Always allow". It runs `reset_approvals`, which the assistant cannot call. From a terminal:

```bash
dart run tool/action.dart reset_approvals '{}'
```

## Receipts

An action records a receipt with `context.receipt(...)`: the resource, the ids and a one-line summary. `verified` says whether the action read the change back. The chat shows receipts under the assistant's reply. A `key` with `args` shows the receipt in the app's language: `key: 'created_item', args: {'title': ...}` makes the chat show `receipt_created_item` from `assets/lang/`, with `{title}` filled in, and the English summary when a language has no such key. A receipt whose `verified` is false shows "Not confirmed: the app could not read this change back." A failed call still carries the receipts of what it wrote before it failed. The command line prints receipts:

```bash
dart run tool/action.dart create_item '{"title":"Milk"}'
dart run tool/action.dart delete_item '{"id":"<id from the line above>"}'
dart run tool/action.dart delete_item '{"id":"<id from the line above>"}' --approved
```

The first delete fails with `approval_required`. The second prints `receipt: Deleted item "Milk"`.

## Reference

[Approval](../../packages/flutter_agentify_core/doc/approval.md): the answers, the rules for each caller and what the model gets back.
