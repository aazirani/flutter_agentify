---
name: adding-a-feature
description: The checklist for adding one feature to this app. Check the scope, then cover the screen, the action and its test, the regenerated action reference and the screen-context entry. Use when adding or changing a screen, route or capability.
---

# Adding a feature

Don't load this for starting a whole app from the template; see `build-an-app`.

## Rule

Check the scope first. Then cover four areas, all of them, in one change:

1. the screen;
2. the action and its test;
3. the regenerated action reference (and an `AGENTS.md` row only for a primary action);
4. the screen-context entry for every new route.

Enforced by `test/ai/parity_test.dart` (an action without a test file, a stale reference, a route without a screen entry, a screen entry matching no route, or an assistant-callable action without an `action_<name>` label in every language file fails it) and by the lint rules (`ui_calls_actions`, `presentation_layer_boundaries`, `domain_layer_boundaries`, `no_error_returns_in_actions`, `no_hardcoded_strings`, `no_hardcoded_colors`, `no_navigator_push`), which run in `dart analyze` and `tool/check.sh`. Whether the scope check was done is not checked by anything.

## Why

A feature that only has a screen cannot be used by the assistant. A feature with an action but no test, or a route with no context entry, leaves the assistant blind or unverified. The four areas keep the UI and the assistant equal.

## How

**Scope check.** Does it change data the app keeps? It needs an action. Does it add a screen? It needs a route and a context entry. Does it add a table or a column? Only new tables or nullable columns, raise `schemaVersion`, add a schema dump and a `to_v<N>_test.dart`. Is it bigger than asked? Cut it and say so.

**1. Screen.** Read through `watch…`/`get…`; change data only with `registry.run(action, input)`, catching `ActionFailure` as `lib/presentation/home/home_screen.dart` does. Strings from every file in `assets/lang/`, colors from the theme, navigation through GoRouter. Add the route in `lib/utils/routes/app_router.dart`.

**2. Action and test.** See `actions`. Put it in `lib/domain/actions/`, register it in `AppActions`, and write `test/actions/<action_name>_test.dart` by copying `test/actions/create_item_test.dart`. Add an `action_<action_name>` key to every file in `assets/lang/` with a short label ("Add an item"); the chat shows it on tool rows and approval cards.

**3. Reference.** `dart run tool/action.dart --write-reference`. Add a row to the Primary actions table in `AGENTS.md` only for a primary action (one the person would ask for by name), not for every helper.

**4. Screen context.** Add the route's entry to `buildScreenContexts` in `lib/ai/screen_contexts.dart`; see `app-context`. If the assistant should know about it, mention it in `assets/assistant/instructions.md`.

## Anti-patterns

- A screen that calls a repository's write methods directly.
- An action registered but untested, or a reference file edited by hand.
- A new route with no entry in `lib/ai/screen_contexts.dart`.
- A table change without a schema dump and migration test.
- Adding an `AGENTS.md` row for every action.
- Adding a feature nobody asked for.

## Verification

- `dart run tool/action.dart --write-reference`, then `flutter test test/ai/parity_test.dart`.
- `dart analyze --fatal-infos` from the repo root (not `flutter analyze`).
- `tool/check.sh` ends with `All checks passed.`

## Related skills

- `actions` — writing and registering the action.
- `app-context` — the screen-context entry.
- `approval-and-safety` — if the feature deletes or changes much at once.
- `build-an-app` — when the task is a whole app rather than one feature.
- `routing` — when the feature adds a route.
- `testing` — the tests for each area.
- `verify` — the last step: run the gate.
