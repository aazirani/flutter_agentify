---
name: clean-architecture
description: Which code goes in domain/, data/, presentation/ and ai/, which way imports may point, and where a new file belongs. Use when adding a file, adding a repository, or when an import is rejected by the layer rules.
---

# Clean architecture

Don't load this for how screens refresh or hold state; see `state-management`.

## Rule

Imports point inward, toward `lib/domain/`:

- `lib/domain/` imports neither `data/`, `presentation/` nor Flutter (`package:flutter/…`, `dart:ui`). It is plain Dart.
- `lib/presentation/` imports nothing from `data/`. It reaches data through a repository interface from `lib/domain/repositories/` and changes data through an action.
- `lib/data/` implements the domain interfaces.
- `lib/ai/` holds the adapters between the app and the assistant.

Enforced by the lint rules `domain_layer_boundaries` and `presentation_layer_boundaries`. They show only in `dart analyze` run from the repo root (and in `tool/check.sh`), not in `flutter analyze`.

## Why

Plain-Dart `domain/` is why the same actions run in the app, in tests and in the action CLI (`tool/action.dart`). If `domain/` knew about Drift or widgets, the CLI and the assistant could not use it.

## How

Where a new file goes:

| You are adding | Put it in |
|---|---|
| An entity (a plain value class) | `lib/domain/entities/`, like `lib/domain/entities/item.dart` |
| A repository interface | `lib/domain/repositories/`, like `lib/domain/repositories/items_repository.dart` |
| An action | `lib/domain/actions/`, registered in `lib/domain/actions/app_actions.dart` |
| A Drift table or DAO | `lib/data/local/database/tables/` or `.../daos/` |
| A repository implementation | `lib/data/repositories/`, like `lib/data/repositories/drift_items_repository.dart` |
| A screen or widget | `lib/presentation/<feature>/` |
| A Riverpod provider | `lib/presentation/providers/` |
| Theme tokens, shared state widgets | `lib/core/` |
| Screen summaries, router and change-event adapters | `lib/ai/` |

Steps for new data:

1. Write the interface in `lib/domain/repositories/`. Name reads `watch…` or `get…`.
2. Implement it in `lib/data/repositories/`. Map table rows to entities there, as `_toItem` does in `DriftItemsRepository`.
3. Register the implementation against the interface in `lib/data/di/data_layer_injection.dart`.
4. Read it in a provider with `ServiceLocator.getIt<ItemsRepository>()`, typed as the interface (see `lib/presentation/providers/items_provider.dart`).

## Anti-patterns

- A screen importing `lib/data/…` or a Drift class. Add an interface member instead.
- A domain file importing `package:flutter/material.dart` for one `Color`. Keep the value as plain data and convert in `presentation/`.
- Putting model calls or widgets in an action.
- Using `// ignore: flutter_agentify_lints/domain_layer_boundaries` to get past an import. The doctor's ratchet counts ignores and they may only go down.
- Exposing a Drift row type from a repository interface. Return entities.

## Verification

- `dart analyze --fatal-infos` from the repo root reports a boundary violation as `domain_layer_boundaries` or `presentation_layer_boundaries`.
- `tool/check.sh` runs it with the tests and ends with `All checks passed.`

## Related skills

- `state-management` — providers and refresh after writes.
- `storing-data` — the tables and migrations behind a data-layer repository.
- `actions` — writing the action that changes the data.
- `adding-a-feature` — the whole path from screen to screen-context entry.
- `testing` — which layer each kind of test covers.
