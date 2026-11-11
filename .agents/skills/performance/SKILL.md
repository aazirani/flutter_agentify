---
name: performance
description: Keeping screens smooth and assistant messages small with narrow rebuilds, bounded lists, heavy work off the UI thread, short screen summaries. Use when a screen stutters, a list grows, a task is slow, or a screen summary gets large.
---

# Performance

Don't load this for work that must continue after the screen closes; see `background-work`.

## Rule

Rebuild as little as possible, never load an unbounded list into a message or a widget tree you do not need, keep heavy computation off the UI thread, and keep the screen summary short. No automated check exists for these; follow them in review.

## Why

Flutter redraws on every state change, so one wide `watch` redraws a whole screen. The assistant's screen block is sent with every message, so a large one costs money and fills the model's context window.

## How

- **Narrow rebuilds:** watch the smallest provider you need and put the `watch` as low in the tree as possible. In `lib/presentation/home/home_screen.dart` the selection (`selectedItemIdsProvider`) and the items (`itemsProvider`) are separate providers, so selecting a row does not reload the data. Use `ref.watch(provider.select(...))` when only one field matters. Mark widgets `const`.
- **Long lists:** use `ListView.builder` (as the item list does) so only visible rows are built. The home list watches every item through `watchItems()`; if a list can grow large, read a page with `getItems({int limit})` (`lib/domain/repositories/items_repository.dart`) and add a paging parameter in the repository rather than loading everything.
- **Heavy work:** parsing, sorting or filtering large data should run in an isolate (`compute` or `Isolate.run`), not in `build`. The database runs off the UI thread through drift already; do not wrap it again.
- **Screen summaries:** `lib/ai/screen_contexts.dart` caps rows (`_visibleRows`, 10) and always includes the total, so the model knows more exists and can call a list action to see them. Follow that: a count, the first rows, ids always, no full lists, no long text bodies.
- **Streams:** cancel or let providers dispose subscriptions; do not start work in `build`.
- **Measure first:** use Flutter DevTools in profile mode (`flutter run --profile`) on a real device; debug mode is slower and misleading.

## Anti-patterns

- `ref.watch` of a provider at the top of a screen when only a small widget needs it.
- `Column(children: [for (...) ...])` over a long list inside a scroll view.
- Sorting thousands of rows in `build`.
- A screen summary that returns every row, or whole item descriptions.
- Optimizing without profiling.

## Verification

- No automated check. Profile on a device, or run the widget test for the screen and watch rebuild counts with DevTools.
- `test/ai/screen_contexts_test.dart` checks the summaries' content.
- `tool/check.sh` for everything else (see `verify`).

## Related skills
- `state-management` — how providers are split
- `app-context` — what a summary should hold
- `background-work` — work that outlives the screen
- `storing-data` — paging and queries
