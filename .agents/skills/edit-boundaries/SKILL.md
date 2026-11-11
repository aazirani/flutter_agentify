---
name: edit-boundaries
description: What an agent may change freely, what needs the gate, what needs a question first and what is off-limits in Flutter Agentify. Use when a task touches dependencies, platform folders, CI, secrets, generated files or anything under packages/.
---

# Edit boundaries

Don't load this for the order of work or the final report; see `agent-workflow`.

## Rule

Sort every change into one of four groups before you make it.

1. **Free: the app's data, through actions.** Creating, changing or deleting items and settings goes through `registry.run(action, input)` or `dart run tool/action.dart <name> '<json>'`. No gate is needed for a data change; actions that need approval ask the person.
2. **Gate: source code.** Edits in `lib/`, `test/`, `assets/lang/` and `tool/` (except `tool/upgrade.dart`) are fine, and the work counts as done only after `tool/check.sh` ends with `All checks passed.`
3. **Ask first.** New or upgraded dependencies in `pubspec.yaml`, platform configuration (`android/`, `ios/`, `macos/`, `web/`, `windows/`, `linux/`: permissions, entitlements, bundle ids, signing), CI files, and `analysis_options.yaml`. State what you want to change and why, then wait.
4. **Off-limits.** Keys, tokens and `.env` files; generated files (`*.g.dart`, `*.drift.dart`, `test/generated_migrations/`); anything the upgrade owns (see below) unless the task is about the framework itself; raising a baseline in `tool/baselines/ratchet.json`.

Framework-owned paths change only with `dart tool/upgrade.dart` (see `upgrade-the-framework`):

- `packages/flutter_agentify_core`, `packages/flutter_agentify_ui`, `packages/flutter_agentify_lints`
<!-- @on-device:begin -->
- `packages/flutter_agentify_on_device`
<!-- @on-device:end -->
- the skill folders the framework ships in `.agents/skills/` (not the generated `actions/references/action-reference.md`)
- `learnings.defaults.md` and `tool/upgrade.dart`
- the example folder in .agents/example/, when the project has one

## Why

Data changes are what the app is for, and actions already check, record and gate them. Source changes can break layers, tests and the assistant's view of the app, so the gate decides. Dependencies, platform files and CI affect every build and every person who clones the repo, so a person should choose them. Secrets leak by being written once. Generated files are overwritten on the next build, so an edit to one is lost or fights the generator.

## How

- Need to change a generated file? Change its source (the drift table, the annotated provider) and run `dart run build_runner build`.
- Need a lint rule off for one line? Put `// ignore: flutter_agentify_lints/<rule>` on the line above, with a reason. Every `// ignore:`, `!` and `dynamic` is counted; the allowed totals are in `tool/baselines/ratchet.json`, and they may only go down. Fix the cause first; write the code differently before you reach for an ignore.
- `analysis_options.yaml` lists the enabled lint rules. Turning one off there is a change to the project's rules, so ask first.
- Need a new package capability? Ask whether the task is about the framework. If it is, work in `packages/` and run the package tests too; if it is not, build the feature in `lib/` on top of what exists.
- Keys never go into source, assets, tests, fixtures or prompts. Use the secure storage path described in `secrets`.
- Before deleting data on the person's behalf, use the action with its approval step; do not delete database files.

## Anti-patterns

- Editing `*.drift.dart` by hand to make an error go away.
- Running `dart run flutter_agentify_core:doctor --update-baselines` to make a failing ratchet pass. That only records a worse number.
- Adding a package because it saves ten lines.
- Adding an Android permission or iOS usage string without asking.
- Copying a key into a test "just for now".
- Editing a framework skill to change how the agent behaves, unless the task is to change Flutter Agentify itself; ask the person instead.
- Editing `packages/` code to dodge a lint rule in `lib/`.

## Verification

- `dart run flutter_agentify_core:doctor --only ratchet` fails when the counts of `// ignore:`, `!` and `dynamic` rise above `tool/baselines/ratchet.json`.
- `dart run flutter_agentify_core:doctor --only bundled-secrets` fails on key-shaped text in bundled assets and package source.
- `tool/check.sh` runs all of it, plus analysis with the custom lint rules. `analysis_options.yaml` is not read by the doctor, and no automated check stops you editing a platform folder, CI file or `packages/`; those boundaries rest on this rule.

## Related skills

- `agent-workflow` — when to ask, and how to report the change.
- `secrets` — where keys live and how they stay out of the repo.
- `upgrade-the-framework` — changing framework-owned paths the right way.
- `verify` — running the gate and reading its output.
- `actions` — changing app data the right way.
