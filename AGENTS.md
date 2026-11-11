# Flutter Agentify

A Flutter app template where an in-app assistant and the UI share the same actions: whatever a person can do with a button, the assistant can do by calling the same code, and every change shows a receipt. The app is in `lib/`; its packages are in `packages/` (`flutter_agentify_core`, `flutter_agentify_ui`, `flutter_agentify_lints`, and `flutter_agentify_on_device` when the model runs inside the app).

<!-- @template:begin -->
## This template is not set up yet

Before anything else, name the project and choose a starting point (`example` keeps the item list, `empty` starts clean and keeps the example as reference in `.agents/example/`):

    dart tool/setup.dart --name <snake_case_name> --org <reverse.domain> --starter empty

Add `--model both` or `--model on-device` only when asked for a model that runs inside the app; the default, `server`, uses a model server.

Then run the commands it prints under `Next:` (the commit, `flutter pub get`, `dart run build_runner build`, `tool/check.sh`; never `flutter run` unless asked) and load the `build-an-app` skill. If the task is to change Flutter Agentify itself, skip this section.
<!-- @template:end -->

## Rules

- **Layers.** `lib/domain/` (entities, repository interfaces, actions) imports neither `data/`, `presentation/` nor Flutter. `lib/presentation/` imports nothing from `data/`. `lib/data/` implements the domain interfaces. `lib/ai/` holds the adapters between the app and the assistant.
- **Changes go through actions.** Screens change data only with `registry.run(action, input)` and read through repository members named `watch…` or `get…`.
- **Actions** live in `lib/domain/actions/`, throw `ActionFailure` on failure (never return an error value) and never call a model.
- **UI:** every visible string comes from `assets/lang/*.json`, every color from the theme, every navigation from GoRouter.
- **Database changes** only add tables or nullable or defaulted columns, raise `schemaVersion`, and come with a schema dump and a `to_v<N>_test.dart`.
- **No keys** in source, assets, tests or anything sent to the model.
- **Never edit** generated files (`*.g.dart`, `*.drift.dart`, `test/generated_migrations/`) or `packages/`, unless the task is about the framework itself.

## Before you say it is done

Run `tool/check.sh`. Work is done only when it ends with `All checks passed.` Report what it printed, and never report a check you did not run. The custom rules show only in `dart analyze` run from the repo root and in the gate; `flutter analyze` does not report them.

To opt one line out of a rule, put `// ignore: flutter_agentify_lints/<rule>` on the line above, with a reason. The doctor counts every `// ignore:`, `!` and `dynamic`, and those counts may only go down.

## Adding a feature

Check the scope first, then cover four areas:

1. the screen, reading through `watch…`/`get…` and changing data with `registry.run`;
2. the action in `lib/domain/actions/`, registered in `AppActions`, with its test in `test/actions/<action_name>_test.dart`;
3. the regenerated action reference: `dart run tool/action.dart --write-reference` (add a row below only for a primary action);
4. an entry for every new route in `lib/ai/screen_contexts.dart`.

`test/ai/parity_test.dart` fails when an action has no test, the reference is stale, or a route has no screen entry. The `adding-a-feature` skill has the details.

## App context

Each message to the assistant carries a `<current-screen>` block: `{"navigation": {"route", "location", "params", "selectedIds"}, "screen": {...}}`. The `screen` part comes from the table in `lib/ai/screen_contexts.dart`, keyed by route pattern: a short summary of what the screen shows (counts, the first rows, always with ids), never a key.

## Primary actions

<!-- @example:begin -->
| Action | What it does |
|---|---|
| `list_items` | Lists the newest items and the total. |
| `get_item` | Returns one item with its full title and description. |
| `create_item` | Adds an item with a title and optional description. |
| `update_item` | Changes an item's title or description. |
| `delete_item` | Deletes an item; the person approves first. |
| `delete_items` | Deletes several items; approval first. |
| `set_theme_mode` | Switches between light, dark and the system theme. |
| `set_language` | Changes the app's language. |
<!-- @example:end -->
<!-- @empty: | Action | What it does | -->
<!-- @empty: |---|---| -->
<!-- @empty: | `set_theme_mode` | Switches between light, dark and the system theme. | -->
<!-- @empty: | `set_language` | Changes the app's language. | -->

All actions, with their inputs and failure codes: `.agents/skills/actions/references/action-reference.md` (generated).

## Try things without the UI

```bash
dart run tool/action.dart --list
dart run tool/action.dart set_language '{"locale":"fa"}'
dart run tool/action.dart <action_name> '<json>' --approved
dart run flutter_agentify_core:docs --query "needs approval"
```

The action CLI uses a scratch database under `.dart_tool/`, never the app's data.

## Skills

Skills live in `.agents/skills/<name>/SKILL.md`; load the one that fits the task.

- **Building features:** `build-an-app`, `adding-a-feature`, `actions`, `app-context`, `approval-and-safety`, `delegate-to-agent`
- **Architecture:** `clean-architecture`, `state-management`, `storing-data`, `routing`, `reliable-mutations`
- **UI:** `ui-design`, `i18n-and-rtl`, `accessibility`
- **AI layer:** `model-providers`, `secrets`, `backend-proxy`, `customizing-the-assistant`
- **Platform:** `permissions-and-platform`, `background-work`
- **Quality:** `testing`, `performance`, `verify`
- **Agent behavior:** `edit-boundaries`, `agent-workflow`, `read-the-docs`, `capture-learnings`, `upgrade-the-framework`

## Memory

At the start of a session, read `learnings.defaults.md` and, if it exists, `learnings.md`. When the person corrects you or states a preference, append one line to `learnings.md` (it is not committed).
