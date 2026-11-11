---
name: actions
description: How to write, register and test an action, the one definition of a capability that the UI, the assistant and the action CLI all call. Use when adding or changing anything that reads or writes app data.
---

# Actions

Don't load this for wiring a whole feature end to end; see `adding-a-feature`.

## Rule

Every capability is one `AgentAction` in `lib/domain/actions/`, registered through `AppActions` in `lib/domain/actions/app_actions.dart`. Screens call it with `registry.run(action, input)`, the assistant calls it by name, and `tool/action.dart` runs it from the command line. Nothing writes data any other way.

## Why

One definition means the assistant can do whatever the UI can, and the person sees the same result either way. The registry checks every definition at startup, gates approval, times calls out, redacts key-shaped text and emits change events so screens refresh.

## How

Copy the shape of `CreateItem` in `lib/domain/actions/items_actions.dart`:

- **Name:** `snake_case`, verb first (`create_item`, `set_theme_mode`). The registry rejects names that are not `snake_case` at startup; verb first is a convention for you to keep.
- **Description:** one complete line saying what it does. The model chooses tools by it.
- **Input:** an `S.object(...)` schema. Every field has a description (the builder requires one). `build` only maps the checked JSON to the input type. Trim and validate inside `run`, before anything is written, by throwing `ActionFailure('invalid_input', ...)` with the field path in `details`, like `_title` and `_description` do: the UI's `registry.run` passes typed input and skips the JSON schema, so checks in `build` never see its calls.
- **Surface:** keep the set small and orthogonal. One patch action per resource (`update_item` takes optional fields) instead of one action per field.
- **Failures:** throw `ActionFailure(code, message)`, list your codes in `failureCodes`, never return an error value (the `no_error_returns_in_actions` lint flags it). `not_found` is the usual one. The registry copies receipts recorded before the throw onto the failure (`ActionFailure.receipts`), so a partial write still shows in the chat.
- **Writes:** validate everything first, then write, then re-read and record `context.receipt(..., verified: true)`, with a `key` and `args` so the chat shows it in the app's language (see `i18n-and-rtl`). Return the stored record so the model gets its id.
- **Flags:** `readOnly` for actions that change nothing; otherwise list the data in `resources` (the registry refuses a writing action without them). `needsApproval` for deletes, bulk or irreversible changes. `agentTool => false` for anything the assistant must not call, such as `set_api_key` in `lib/domain/actions/settings_actions.dart`.
- **No model calls** inside an action. Judgment work belongs to the assistant in the chat.
- **Register** the new action in `AppActions` (field, constructor, `all`).
- **Regenerate the reference:** `dart run tool/action.dart --write-reference` rewrites `.agents/skills/actions/references/action-reference.md`.

Try it without the UI:

```bash
dart run tool/action.dart --list
dart run tool/action.dart set_language '{"locale":"fa"}'
dart run tool/action.dart <action_name> '<json>' --approved
```

The CLI uses a scratch database under `.dart_tool/`, never the app's data, and runs as caller `cli`, so actions that need approval need `--approved`.

## Anti-patterns

- A screen calling `repository.createItem(...)` directly: the assistant cannot do it, nothing is recorded, nothing refreshes through change events.
- `return {'error': 'not found'}` from `run`: the model reads it as success.
- Validating after the first write, so a failure leaves half a change behind.
- One action per field (`set_item_title`, `set_item_description`).
- Putting a key, or anything secret, in an action's output or receipt.

## Verification

- Each action needs `test/actions/<action_name>_test.dart`; `test/actions/create_item_test.dart` is the model to copy. Use `ActionsHarness` from `test/support/actions_harness.dart` (registry over an in-memory database): `h.call(name, json, approved: ...)` runs as the assistant, `h.registry.run(h.actions.x, input)` as the UI (`call` refuses `Caller.ui`), `failsWith(code)` matches a failure. Assert on the stored data and `result.receipts`.
- The registry's startup checks reject bad names, descriptions, missing resources and field descriptions.
- The parity test reports an action without a test file (or one that never mentions the action's name), a stale action reference, and an assistant-callable action without an `action_<name>` label in every `assets/lang/` file.
- `dart run tool/action.dart <name> '<json>'` shows the real output and receipts.
- `tool/check.sh` runs all of this and ends with `All checks passed.`

## Related skills

- `adding-a-feature` — wiring an action into a screen, a test and the screen table.
- `approval-and-safety` — when an action needs approval or must stay UI-only.
- `app-context` — the ids and summaries the model sees when it calls your action.
- `delegate-to-agent` — when the work needs judgment rather than a fixed rule.
- `testing` — which other tests a change needs.
- `verify` — running the gate before saying an action is done.
