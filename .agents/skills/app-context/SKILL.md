---
name: app-context
description: How the assistant knows what is on screen, through the screen-context table keyed by route, bounded summaries, selection reporting, and navigation only through the navigate action. Use when adding a route, changing what a screen shows, or making the assistant aware of a selection.
---

# App context

Don't load this for the actions themselves or for what the assistant may do without asking; see `actions` and `approval-and-safety`.

## Rule

- Every route has one entry in `buildScreenContexts` in `lib/ai/screen_contexts.dart`, keyed by its route pattern (`/`, `/settings`).
- An entry returns a short summary of what the screen shows: counts plus the first rows, ids always, never a key or secret.
- A screen with a selection reports it through `AppContext.setSelection`.
- The assistant moves between screens only with the `navigate` action.

Enforced by `test/ai/parity_test.dart` (a route without an entry, or an entry matching no route, fails it). Summary size and content are not checked.

## Why

Every message carries a `<current-screen>` block: `{"navigation": {"route", "location", "params", "selectedIds"}, "screen": {...}}`. The `screen` part comes from your entry. Small models have little context, so a summary has to be short; ids let the model act on rows with `update_item` instead of guessing.

## How

Add the entry next to the others. `ScreenContext` takes a function from the navigation state to a map, sync or async:

<!-- @example:begin -->
- `/` in `lib/ai/screen_contexts.dart` reads `getItems(limit: _visibleRows)` (10) and `getItemCount()`, and returns `total`, a list of `{id, title, description}` (cut short), a `note` and `selectedIds`. The total shows what the list leaves out.
<!-- @example:end -->
- `/settings` reads providers, not the database, and reports the model preset and whether it is configured, never the key.
- A screen with nothing to report uses `const ScreenContext.nothing()`.

**Selection.** The home screen's provider in `lib/presentation/providers/items_provider.dart` calls `getIt<AppContext>().setSelection(...)` on every change. Do the same wherever a person can pick rows, so "delete these" works.

**Navigation.** `lib/ai/go_router_adapter.dart` keeps the route, location and params in step with GoRouter and connects the `navigate` action to `router.go`. The assistant never calls `context.go` or `setNavigation`; `navigate` fails with `unknown_route` for a location that matches no table key. List the screens in `assets/assistant/instructions.md`.

A view that takes longer than `AppContext.viewTimeout` (2 s) is cut off, so read local data only.

## Anti-patterns

- Dumping a whole table into the summary.
- Rows without ids.
- Putting an API key, token or setting's secret value in a summary.
- A route added to `lib/utils/routes/app_router.dart` with no table entry.
- Calling `setNavigation` from a screen.
- Letting the assistant reach a screen by any path other than `navigate`.

## Verification

- `test/ai/parity_test.dart` for route coverage; `test/ai/screen_contexts_test.dart` for the entries; `test/ai/go_router_adapter_test.dart` for the adapter.
- Run the app, open the screen and ask the assistant what it sees.
- `tool/check.sh` ends with `All checks passed.`

## Related skills

- `adding-a-feature` — the whole checklist this entry is part of.
- `actions` — the actions a model uses with the ids you report.
- `approval-and-safety` — keeping secrets out of what the model sees.
- `routing` — adding the route the entry belongs to.
- `performance` — keeping screen summaries small.
