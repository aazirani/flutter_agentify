# Approval

Actions that change data can wait for the person's approval before the assistant runs them. An action needs approval when its `needsApproval(input)` returns true.

Two more members shape the request:

- `Future<String?> approvalSummary(input)`: one line the person reads on the card, such as the title of the item a delete removes. Null (the default) shows only the arguments.
- `bool get allowAlways`: true by default. False for anything destructive: the card offers no "Always allow", `Approve(always: true)` is not stored, and an always-allow stored earlier is ignored, so every call asks.

`ApprovalRequired` carries both as `summary` and `allowAlways`; `registry.approvalInfo(name, jsonInput)` computes them and never throws (an unknown action, invalid input or a failing summary gives `allowAlways: false` and no summary).

## Who is asked

| Caller | Behavior |
|---|---|
| `Caller.assistant` | The run pauses with `ApprovalRequired` until the person answers. |
| `Caller.ui` | Never paused: the person already pressed the button. Only `registry.run` takes it; `registry.call` (JSON input) refuses it. Keep the screen's own confirm dialog where it has one. |
| `Caller.cli` | Fails with `approval_required` unless the call passes `--approved`. |

## Smallest example

```dart
session.send(threadId, 'Delete the old drafts').listen((event) {
  if (event is ApprovalRequired) {
    // Show event.action, event.summary and event.args, then answer:
    session.resolveApproval(event.callId, const Approve());
  }
});
```

## Answers

- `Approve()` runs the call. `Approve(always: true)` also stops asking for that action, through `ApprovalPrefs` (in memory by default; an app can persist it), unless the action's `allowAlways` is false. `ApprovalPrefs.clear()` forgets every always-allow, so each action asks again.
- `Reject()` does not run the call. The model gets `{"error":"declined","message":"The user declined this action."}` and can stop or change its plan.
- `Edit(args)` runs the call with other arguments. They are checked against the action's schema first: when they are invalid or the action cannot build its input from them, `resolveApproval` returns a message (naming the field when the schema rejects it) and the approval stays pending.

## Rules

- Tool calls in one step run in order, so a later call waits until an earlier approval is answered.
- Stopping the run while an approval is pending ends it with `Cancelled`. The call gets a `cancelled` result, so the stored conversation stays valid.
- `resolveApproval` does nothing and returns null for a call id that is not waiting (answered already, or the run was stopped), so a late button tap is harmless.
