---
name: testing
description: Which kind of test to write for which kind of change, and the helpers this repo gives you. Use when adding or changing an action, repository, screen, assistant behavior or database migration, or when a test fails.
---

# Testing

Don't load this for running the whole gate and reading its output; see `verify`.

## Rule

Every change comes with the smallest test that would have failed without it. Every action has `test/actions/<action_name>_test.dart`. Enforced by `test/ai/parity_test.dart`, which fails when an action has no test file.

## Why

The assistant and the UI call the same code, so a test at the action covers both. Tests must not need a network, a real model or the person's data.

## How

| Change | Test | Model to copy |
|---|---|---|
| An action | Call it through a registry over an in-memory database; assert on stored data and the receipt | `test/actions/create_item_test.dart`, helper `test/support/actions_harness.dart`: `ActionsHarness().call(name, json)` runs as the assistant, `failsWith(code)` matches a failure |
| A repository or DAO | Drift on `NativeDatabase.memory()` | `test/data/repositories/drift_items_repository_test.dart` |
| A screen | Widget test with the app's localization, theme and fake services | `test/presentation/home/home_screen_test.dart`, helper `test/support/test_app.dart` (`pumpTestApp`) |
| Assistant behavior across screens | Full app with a scripted model: `pumpFullApp`, `openAssistant`, `sendToAssistant` | `test/ai/assistant_flow_test.dart` |
| A database change | Migration test from the previous version | The `to_v<N>_test.dart` template in `storing-data` |
| A route's screen summary | Table test | `test/ai/screen_contexts_test.dart` |
| Translations | Key-count test | `test/i18n/translations_test.dart` |

Details:

- **Scripted model:** `ScriptedProvider` and `ScriptedStep.text(...)`, `ScriptedStep.toolCalls([...])` from `package:flutter_agentify_core/testing.dart` replace the model. Never call a real one.
- **Fakes:** `test/support/fakes.dart` has `FakeItemsRepository`; the in-memory settings and secret stores are in `lib/data/repositories/`.
- **Migrations:** `test/generated_migrations/` is generated; never edit it. A new schema version needs a `to_v<N>_test.dart` (`storing-data`).
- **SQLite from plain Dart:** database tests run on the machine's SQLite library. On Windows, `sqlite3.dll` must be on the `PATH` for them to run.
- **Packages** have their own tests (`packages/flutter_agentify_core/test/`); run them from the package folder with `dart test`. App tests run with `flutter test`.
- Run one file while working: `flutter test test/actions/set_language_test.dart`.

## Anti-patterns

- A widget test that checks an item was created by tapping, instead of testing the action and then the screen showing it.
- A test that reads a real key or calls a real server.
- A test that passes because it asserts nothing about the result (only "does not throw").
- Deleting or loosening a test to turn the gate green.
- Editing a generated migration schema to make a migration test pass.

## Verification

- `flutter test` for the app; `tool/check.sh` for all four test suites plus the parity test (see `verify`).
- A new action: `dart run tool/action.dart --write-reference` too, or the parity test reports a stale reference.

## Related skills
- `actions` — the shape of an action under test
- `storing-data` — migrations and their tests
- `model-providers` — scripted providers versus real ones
- `verify` — running everything
