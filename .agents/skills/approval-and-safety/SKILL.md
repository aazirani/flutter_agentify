---
name: approval-and-safety
description: Which actions ask the person first, how the UI, the assistant and the CLI differ, which actions the assistant must never see, and what the assistant hears after a rejection. Use when writing an action that deletes, changes much at once, or touches secrets.
---

# Approval and safety

Don't load this for how to write an action in general; see `actions`.

## Rule

- `needsApproval` returns true for deletes, bulk changes and anything irreversible (`DeleteItem` and `DeleteItems` in `lib/domain/actions/items_actions.dart`).
- Anything destructive also sets `bool get allowAlways => false`, so the card offers no "Always allow" and every call asks again.
- Give such an action an `approvalSummary(input)`: one line the person reads on the card, such as the title of the item a delete removes (`DeleteItem.approvalSummary`; `DeleteItems` lists the first five titles).
- `update_item` clearing a description is allowed without approval: it is one field of one item, and the receipt and the returned item show the change.
- The UI is never paused by approval, so a screen keeps its own confirm dialog.
- The action CLI needs `--approved` for such actions.
- An action touching secrets or the model setup is UI-only: `bool get agentTool => false` (`SetApiKey`, `SetAssistantProvider` and `ResetApprovals` in `lib/domain/actions/settings_actions.dart`).

Enforced by the registry's approval gate, tested in `test/actions/delete_item_test.dart` (a call without approval fails with `approval_required` and changes nothing). The `agentTool` flag has no test of its own, and no check decides which actions deserve approval.

## Why

The registry lets `Caller.ui` through `run` (the person pressed the button; `call` with JSON input refuses it) but refuses `Caller.assistant` and `Caller.cli` unless approved. For the assistant, the run pauses and the app shows an approval card. A hidden action cannot be called by a confused or misled model, so keys never pass through the chat.

## How

- Make `needsApproval(input)` depend on the input when only some calls are risky; return true when unsure.
- Don't add a "are you sure?" step in the chat. The system prompt in `assets/assistant/instructions.md` tells the assistant to call `delete_item` right away and let the card ask.
<!-- @example:begin -->
- Keep the confirm dialog in the screen (`_confirmDelete` in `lib/presentation/home/home_screen.dart`). It is the UI's own safeguard.
<!-- @example:end -->
<!-- @empty: - Keep the confirm dialog in the screen (see `_confirmDelete` in .agents/example/lib/presentation/home/home_screen.dart). It is the UI's own safeguard. -->
- Test it like `test/actions/delete_item_test.dart`: `requiresApproval`, refused without approval, works with `approved: true`, works for the UI, the summary and `allowAlways`.
- With the CLI: `dart run tool/action.dart <action_name> '<json>' --approved`.

**After a rejection.** The model gets `{"error":"declined","message":"The user declined this action."}`, and the core rules tell it to stop or change its plan, not repeat the call. Nothing runs and no receipt is written. Your instructions should say what to tell the person ("leave the item and say so"). Approving with "always" is stored in `ApprovalPrefs`; the app persists it in `lib/data/repositories/prefs_approval_prefs.dart`. Settings has "Ask again before every action", which runs the UI-only `reset_approvals` and clears them all.

## Anti-patterns

- A delete or bulk action without `needsApproval`, or with `allowAlways` left true.
- Removing the UI's confirm dialog because "the registry asks".
- Giving the assistant an action that takes or returns a key.
- Asking for approval in the chat text instead of calling the action.
- Retrying a declined call.

## Verification

- `flutter test test/actions/<action_name>_test.dart`, and the same shape for each new risky action.
- The parity test requires that test file to exist.
- `tool/check.sh` ends with `All checks passed.`
- Further reading: `dart run flutter_agentify_core:docs --query "needs approval"`.

## Related skills

- `actions` — the flags and the rest of the action contract.
- `app-context` — what the model is shown, which must hold no secrets.
- `adding-a-feature` — where approval fits in the checklist.
- `secrets` — why keys never reach the model.
- `edit-boundaries` — what a coding agent may change without asking.
