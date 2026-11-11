---
name: state-management
description: How screens hold and refresh state with Riverpod 3 and code generation, and how they update after the assistant writes data. Use when adding a provider, reading data in a screen, or when a screen does not refresh after an action.
---

# State management

Don't load this for where files and imports belong; see `clean-architecture`.

## Rule

- Providers use Riverpod 3 with code generation: `@riverpod` or `@Riverpod(keepAlive: true)`, a `part '<file>.g.dart';` line, and a plain `Ref` parameter. Never write or name a generated ref type; `Ref` is the only one.
- Screens read repositories through members named `watch…` or `get…` and change data only with `registry.run(action, input)`.
- Data that actions change comes from a stream (`watch…`), so the screen follows the database. Data that is not in the database (settings) is refreshed by the change-event adapter.

Enforced by the lint rule `ui_calls_actions` for the read/write split. No automated check covers provider style; follow the files named below.

## Why

The assistant writes through the same actions as the buttons. If a screen refreshes only because its own button was pressed, an assistant write leaves it stale. A database stream and the change-event adapter refresh the screen whoever made the change.

## How

- **Database data:** `lib/presentation/providers/items_provider.dart` exposes `items(Ref ref)` as `ServiceLocator.getIt<ItemsRepository>().watchItems()`. The Drift stream emits after every write, so nothing else is needed. The home screen reads it with `ref.watch(itemsProvider)` and handles `loading`, `error` and `data`.
- **Non-database data:** theme, language and assistant settings are `keepAlive` providers (for example `lib/presentation/providers/theme_provider.dart`). `attachChangeEvents` in `lib/ai/change_event_adapter.dart` listens to `registry.changes` for resource `settings` and calls `container.invalidate(...)` on each of them. Add a new settings provider to that `invalidate` chain. It also refreshes the saved notes (`savedMemoriesProvider`) for resource `memories`.
- **A new resource that is not a stream:** give its action a `resources` entry, then filter on that resource name in the adapter and invalidate the provider.
- **Screen-only state:** a notifier such as `SelectedItemIds` in `lib/presentation/providers/items_provider.dart`. When the assistant must know it, mirror it into `AppContext`, as `_report` does.
- After editing a provider, run `dart run build_runner build`. Never edit `*.g.dart`.

## Anti-patterns

- `ref.invalidate(itemsProvider)` after a button's write: it hides a missing stream and the assistant's writes still go stale.
- Calling `repository.createItem(...)` from a screen (blocked by `ui_calls_actions`; use `registry.run`).
- Reading a `get…` once in `initState` for data that changes.
- Holding a copy of the list in a `State` field.
- Hand-written `Provider`/`StateNotifier` next to the generated style.

## Verification

- `test/presentation/providers/theme_provider_test.dart` and `test/presentation/providers/language_provider_test.dart` show how provider tests are built; `test/support/test_app.dart` is the app harness.
- Run an action through the registry in a test and assert the provider's new value.
- `tool/check.sh` runs the lint and tests; it ends with `All checks passed.`

## Related skills

- `clean-architecture` — which layer a provider and a repository belong to.
- `actions` — the writes that trigger the refresh.
- `app-context` — what the assistant is told about the current screen and selection.
- `performance` — keeping rebuilds narrow.
