---
name: build-an-app
description: How to turn this template into a new app. Decide six things first, build one thin slice through every layer, then widen and report what was left out. Use when the task is to build a whole app on this template.
---

# Build an app

Don't load this for adding one feature to an app that already works; see `adding-a-feature`.

## Rule

<!-- @template:begin -->
First, check whether the template is set up. This repo still holds the setup script, so run it before anything else. Use `--starter empty` unless the person wants the item list kept:

```bash
dart tool/setup.dart --name <snake_case_name> --org <reverse.domain> --starter empty
```

Then run the commands it prints under `Next:`, in order. In a git repository the first one commits what setup changed, so the gate and a later upgrade see a clean tree:

```bash
git add -A && git commit -m "Set up <snake_case_name>"
flutter pub get
dart run build_runner build
tool/check.sh
```

Do not start `flutter run` unless the person asks: it keeps running and may ask which device to use. Skip this step if the task is to change Flutter Agentify itself.
<!-- @template:end -->

Before writing code, settle six things with the person (ask only what the request does not already answer, then state your choices back in a few lines):

1. **Purpose:** what the app is for, in one sentence.
2. **Data:** the things it keeps (entities) and their fields.
3. **Screens:** each screen and the route it lives at.
4. **Actions:** what a person can do to the data; each becomes one action.
5. **Model setup:** which assistant model the person will use (local server or hosted), whether the assistant needs a key, and whether the model should run inside the app instead (`dart tool/setup.dart --model both` or `on-device`, chosen at setup; it raises the platform floors and downloads about 2.6 GB on the device).
6. **Platforms:** which of mobile, web and desktop must work. Web stores no key.

Then build one thin slice through every layer, and only then widen. End by reporting what you left out.

No automated check enforces the six decisions. The gate (`tool/check.sh`) enforces everything the slice produces: layers, lint rules, tests, the doctor and the parity test.

## Why

The template holds a worked example (an item list plus settings). A thin slice proves the whole chain (table, repository, action, screen, screen-context entry, test) before you copy it five times. Mistakes in the shape are cheap to fix once and costly to fix across ten screens.

## How

<!-- @example:begin -->
The slice is the example, replaced with your first entity:
<!-- @example:end -->
<!-- @empty: The example item list is kept as reference in .agents/example/. Follow its files for each layer, but write the new files under lib/ and test/. The slice for your first entity:  -->

1. **Domain:** entity in `lib/domain/entities/`, interface in `lib/domain/repositories/`, actions in `lib/domain/actions/` following `lib/domain/actions/items_actions.dart`, registered in `lib/domain/actions/app_actions.dart`.
2. **Data:** a drift table and a repository in `lib/data/repositories/`. A table change raises `schemaVersion` and needs a schema dump and a migration test; see `adding-a-feature`.
3. **Presentation:** one screen that reads through `watch…`/`get…` and changes data with `registry.run`, like `lib/presentation/home/home_screen.dart`. Strings go in every file in `assets/lang/`.
4. **Route:** add it in `lib/utils/routes/app_router.dart`.
5. **Assistant:** a screen-context entry in `lib/ai/screen_contexts.dart`, and the purpose and tool list in `assets/assistant/instructions.md`.
6. **Test:** `test/actions/<action_name>_test.dart` for each action.

Run `dart run tool/action.dart --write-reference` and `tool/check.sh`. Only when the slice passes, add the other entities and screens, one at a time, each through the same path.

<!-- @example:begin -->
Replace the example items last, once the slice works, so you always have a green reference to compare with.
<!-- @example:end -->
Update `AGENTS.md` (the primary actions table, the intro) and `README.md` to describe the new app.

The final message states what is built, what you left out (screens, platforms, edge cases, translations), and what `tool/check.sh` printed.

## Anti-patterns

- Starting with ten screens and wiring actions later.
- Building every entity's data layer before one screen works.
- Deleting the example before the new slice passes (when the example is still in the project).
- Reporting "done" without naming the omissions.
- Skipping the model-setup question: the assistant is useless until a model is configured in Settings.

## Verification

- `tool/check.sh` ends with `All checks passed.`
- `test/ai/parity_test.dart` passes: every action has a test, the reference is current, every route has a screen entry.
- `dart run tool/action.dart --list` shows the new actions.
- Your report lists the omissions.

## Related skills

- `adding-a-feature` — each screen or action after the first slice.
- `actions` — writing each action.
- `app-context` — the screen-context table.
- `approval-and-safety` — which of your actions need approval.
- `model-providers` — settling the model setup.
- `permissions-and-platform` — settling the platforms.
- `agent-workflow` — reporting what was left out.
