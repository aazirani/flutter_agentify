---
name: upgrade-the-framework
description: How to bring the newest Flutter Agentify into a project with the upgrade command, make the manual steps it prints and report the result. Use when the person asks to upgrade or update the framework, or when a fix you need is in a newer framework.
---

# Upgrade the framework

Don't load this for adding a package to the app or changing app code; see `edit-boundaries`.

## Rule

Upgrade only with `dart tool/upgrade.dart`. Start from a clean git tree. Read what it prints, make each listed change in the project's own files, run the four commands it prints, and report what the gate printed. Never edit `packages/` or a framework skill to "fix" an upgrade.

## Why

The upgrade replaces the framework's own files: the packages in `packages/`, the skills the framework ships (except the generated action reference), `learnings.defaults.md` and `tool/upgrade.dart`. A project made with the `empty` starter keeps its reference in the .agents/example/ folder, and every upgrade refreshes it with no flag. A hand edit in those paths is lost on the next upgrade. Changes the command cannot make for you are in the dated `### Upgrading` notes in `CHANGELOG.md`.

## How

1. Check the tree is clean:
   ```bash
   git status --short
   ```
   If it prints anything, ask the person to commit or stash first. The command refuses a dirty tree.
2. Run the upgrade:
   ```bash
   dart tool/upgrade.dart
   ```
   Flags:
   - `--ref <commit>` takes that commit, branch or tag instead of `main`; use it only when the person asks for one.
   - `--from <folder>` reads the framework from a local folder, with no network. The default is the newest `main` on GitHub; there are no versions.
   - `--starter empty` is for a project made with the `example` starter whose item code the person has deleted. It installs the .agents/example/ folder and the skills in their empty form, so the doctor passes again. Without the flag, upgrade picks `empty` when that folder exists, else `example`.
   - `--help` prints all flags.
3. Read the output. It prints `Upgraded Flutter Agentify from …`, then the `### Upgrading` notes dated on or after the project's last framework change or `No manual steps.`, then the skills the framework no longer ships.
4. Make each listed change in the project's own files (`lib/`, `test/`, `pubspec.yaml`, `assets/`). For a skill listed as not shipped, ask the person whether to keep or delete it.
5. Run the four commands under `Next:`:
   ```bash
   flutter pub get
   dart run build_runner build
   dart run tool/action.dart --write-reference
   tool/check.sh
   ```
6. If the gate fails, fix the project's own code, not `packages/`. If the cause is a bug in the framework, tell the person; don't patch it.
7. Report where the framework came from, the manual steps you made, and the last lines of `tool/check.sh`.

If the command fails, nothing in the project has changed, unless it printed an undo command; run that first. Read the message, fix the cause (network, folder) and run it again.

## Anti-patterns

- Upgrading with uncommitted changes.
- Editing `packages/` or a framework skill so the old code keeps working.
- Skipping the printed notes because the command said it finished.
- Deleting a skill the command listed without asking.
- Reporting "upgraded" without the gate output.

## Verification

- `dart tool/upgrade.dart` prints `Upgraded Flutter Agentify from …`
- `tool/check.sh` ends with `All checks passed.`
- `git status --short` shows only the upgrade and your manual steps.

## Related skills

- `edit-boundaries` — which paths the upgrade owns.
- `verify` — running the gate and reading its output.
- `actions` — the action reference the upgrade asks you to regenerate.
- `agent-workflow` — reporting what changed.
