# Upgrade

Your project holds a copy of the framework: the packages, the skills and a few files around them. `dart tool/upgrade.dart` replaces that copy with the newest one and leaves your own code alone. The framework has no versions: the newest is whatever is on its `main` branch.

## Before you start

The upgrade needs a clean git tree, so you can review the result and undo it. Commit or stash first:

```bash
git status --short
```

This must print nothing.

## Run it

```bash
dart tool/upgrade.dart
```

This gets the newest `main` from GitHub. Other choices:

```bash
dart tool/upgrade.dart --ref 1a2b3c4
dart tool/upgrade.dart --from ../flutter_agentify
dart tool/upgrade.dart --help
```

- `--ref` takes a commit, branch or tag of the framework instead of the newest `main`, to pin or step back to one that worked.
- `--from` takes the framework from a folder on your machine, with no network.
- `--starter example` or `empty` picks which starter's framework files to install. The default is `empty` when `.agents/example/` exists, else `example`. Pass `--starter empty` after you drop the item example; see [Choose a starting point](choose-a-starting-point.md#drop-the-example-later).

If the command fails, nothing in the project has changed, unless it printed an undo command; then run that first. Read the message, fix the cause, such as the network or a wrong folder, and run it again.

## What it replaces

Only the paths the framework owns. The list is in the `edit-boundaries` skill: [`.agents/skills/edit-boundaries/SKILL.md`](../../.agents/skills/edit-boundaries/SKILL.md). In short: the packages under `packages/`, the skills the framework ships, `.agents/example/`, `learnings.defaults.md` and `tool/upgrade.dart`.

A project with the model inside the app also gets the new `packages/flutter_agentify_on_device/`, and its copies of the engine's web helpers, `web/cache_api.js` and `web/opfs_helper.js`, are replaced from that package. A project without it does not get the package.

Everything else is yours and stays as it is: `lib/`, `test/`, `assets/`, `pubspec.yaml`, `AGENTS.md`, `tool/check.sh`, `tool/action.dart`, the platform folders, and any skill or package you added.

**Edits you made under `packages/` are overwritten.** They show in `git diff` as lines the upgrade removed:

```bash
git diff --stat packages/
```

If you need a change in a package, build it in `lib/` on top of the package instead, or propose it to the framework.

## Read what it prints

The output has four parts:

1. `Upgraded Flutter Agentify from …`
2. The `### Upgrading` notes of each changelog entry dated on or after your project's last framework change (the newest commit that touched `packages/flutter_agentify_core`), or `No manual steps.` The notes list changes you make by hand in your own files, such as a renamed function your code calls. A note from that same day can show again; skip it if you already made it.
3. Skills your project has that the framework no longer ships. Delete each one, or keep it if you wrote it.
4. The commands to run next.

Make the changes the notes list, then run the commands it prints:

```bash
flutter pub get
dart run build_runner build
dart run tool/action.dart --write-reference
tool/check.sh
```

The gate ends with `All checks passed.` once the manual steps are done.

## Review and commit

```bash
git diff --stat
git add -A && git commit -m "Upgrade Flutter Agentify"
```

To undo the upgrade instead, before you commit, run this in the project folder:

```bash
git checkout -- . && git clean -fd .
```

The project was clean before the upgrade, so this removes only what it changed. It touches only the project folder, even when that folder sits inside a larger repository.

A coding agent follows the same steps with the `upgrade-the-framework` skill.
