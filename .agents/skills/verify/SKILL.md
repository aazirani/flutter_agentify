---
name: verify
description: How to prove a change works by running the gate, read what each step means, and try behavior with the action CLI. Use when you finish any task, when tool/check.sh fails, or before you tell the person something is done.
---

# Verify

Don't load this for choosing which test to write; see `testing`.

## Rule

Run `tool/check.sh` before you say work is done. Work is done only when it ends with `All checks passed.` Report what it printed, and never report a check you did not run. The gate is the enforcement. `flutter analyze` does not report the custom lint rules; use `dart analyze` at the repo root or the gate.

## Why

Each rule in this repo has a check, and the checks only protect you if they actually run. A claim without output is a guess.

## How

`tool/check.sh` stops at the first failing step. In order:

1. **dependencies:** `pub get` for the app and each package (on-device included when present). Fails on a bad `pubspec.yaml` or a version conflict.
2. **generate code:** `dart run build_runner build` (drift, Riverpod). Fails when annotated code does not compile.
3. **schema dump is current:** the database schema equals `drift_schemas/`. Fails if you changed tables without raising `schemaVersion` and dumping (`storing-data`).
4. **format:** `dart format` check. Fix with `dart format <the files it names>`.
5. **analyze:** `dart analyze --fatal-infos`, which includes the custom lint rules (layer boundaries, `ui_calls_actions`, hardcoded colors and strings, and so on). Any info fails the gate.
6. **tests:** `flutter test`, then the core and lints packages with `dart test`, then the UI package with `flutter test` (and the on-device package when present). Includes the parity test.
7. **doctor:** `dart run flutter_agentify_core:doctor` (agent-files, skills, bundled-secrets, migrations, ratchet, doc-links). Run one check with `--only <name>`.
8. **action smoke check:** `set_language` to the default language (the first in `kSupportedLanguages`), such as `dart run tool/action.dart set_language '{"locale":"en"}'`, proves the registry starts and an action runs.

Reading a failure: find the `== step` heading above the first error; fix that step only, then rerun the whole gate. Don't "fix" a failing check by loosening it or adding `// ignore:`; the ratchet counts those and may only go down.

Behavior checks without the UI use the action CLI, which works on a scratch database under `.dart_tool/`, never the app's data:

```bash
dart run tool/action.dart --list
dart run tool/action.dart set_language '{"locale":"fa"}'
dart run tool/action.dart <action_name> '<json>' --approved
```

`--list` prints the action names (for example `create_item`, `list_items`, `set_theme_mode`, `view_screen`). Actions that need approval need `--approved`. For UI changes the gate is not enough: run the app and look at it, or say you did not.

If you could not run a step (no device, no network), say which one in the report.

## Anti-patterns

- Saying "tests pass" after running one file.
- Reporting from memory or from an earlier run.
- Skipping the gate because only a doc changed (the doctor checks skills and links).
- Hiding a failure by editing a baseline or a generated file.

## Verification

- The last lines of `tool/check.sh` output read `All checks passed.`; paste or quote them in your report.
- `test/tool/action_cli_test.dart` covers the CLI itself.

## Related skills
- `testing` — writing the tests the gate runs
- `actions` — the CLI and action reference
- `storing-data` — when the schema step fails
- `clean-architecture` — when a boundary lint fails
