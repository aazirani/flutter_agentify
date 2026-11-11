# Getting started

This page takes you from nothing to a first chat with the assistant in your own app.

## Requirements

- Flutter 3.47.0 or newer, with Dart 3.13.0 or newer. `pubspec.yaml` states both:

  ```yaml
  environment:
    sdk: ^3.13.0
    flutter: ">=3.47.0"
  ```

- The toolchain for at least one platform: Xcode for macOS and iOS, Android Studio for Android, Chrome for web, Visual Studio for Windows. `flutter doctor` says what is missing.
- Git, and bash for `tool/check.sh` (on Windows, Git Bash or WSL).
- A model the app can reach. A local server such as [Ollama](https://ollama.com) needs no key. See [Connect a model](guides/connect-a-model.md).

Check your versions:

```bash
flutter --version
```

## Create a project

Get a copy of the template, then name it and choose a starting point:

```bash
git clone --depth 1 https://github.com/aazirani/flutter_agentify.git notes_app
cd notes_app
dart tool/setup.dart --name notes_app --org com.acme --starter empty
git add -A && git commit -m "Set up notes_app"
flutter pub get && dart run build_runner build && flutter run
```

On GitHub you can press "Use this template" instead of cloning. The same thing as a command, with the [GitHub CLI](https://cli.github.com):

```bash
gh repo create notes_app --template aazirani/flutter_agentify --private --clone
cd notes_app
```

Then run the last three lines from above, starting with `dart tool/setup.dart`.

What the setup flags mean:

- `--name` is the Dart package name.
- `--org` is your organization in reverse-domain form. The application id becomes `<org>.<name without underscores>`, here `com.acme.notesapp`.
- `--starter` is `empty` or `example`. `empty` starts clean. `example` keeps a small item list to look at. See [Choose a starting point](guides/choose-a-starting-point.md).
- `--model` is where the assistant's model runs: `server` (the default) uses a model server; `both` and `on-device` add a model that runs inside the app and raise the platform floors. See [Choose where the model runs](guides/choose-where-the-model-runs.md).

A clone keeps the template's history and its `origin` remote. To start your own history instead, add `--reset-git` to the setup line. For every flag:

```bash
dart tool/setup.dart --help
```

Setup removes itself when it is done, and with it the template's `docs/`, `CHANGELOG.md` and other framework-only files; the same pages stay on GitHub. The first `dart run build_runner build` and the first build of the app each take a few minutes. Setup prints the next commands:

```text
Next:
  git add -A && git commit -m "Set up notes_app"
  flutter pub get
  dart run build_runner build
  tool/check.sh
Try the app: flutter run
Coding agents: read AGENTS.md, then load the build-an-app skill.
```

The first command commits what setup changed, so your own changes stay apart. Setup prints it only in a git repository.

If the project is a folder inside a larger git repository, `git add -A` also takes changes from outside the folder. Commit only the folder instead:

```bash
git add -A . && git commit -m "Set up notes_app" -- .
```

`tool/check.sh` is the quality gate. Run it once now; it ends with `All checks passed.` See [Quality gate](concepts/quality-gate.md).

If setup refuses to run, see [Troubleshooting](guides/troubleshooting.md#setup-refuses-to-run).

## Run it

`flutter run` asks which device to use when there is more than one. To pick one yourself:

```bash
flutter devices
flutter run -d macos
```

With `--starter empty`, the app opens on a welcome screen with two buttons: Assistant and Settings. With `example`, it opens on the item list. What each platform needs is in [Platforms](guides/platforms.md).

## Connect a model

The assistant needs a model. Until one is set, opening the assistant shows **Set up a model** with a button to Settings. To use Ollama on the same computer, start it (open its app, or run `ollama serve` in a second terminal), then get a model:

```bash
ollama pull qwen3:8b
```

In the app, open Settings. Under Assistant, keep the model server at Ollama, type `qwen3:8b` as the model and save. `qwen3:8b` is a download of several GB. If Ollama is not running, the chat says it can't reach the model server. For hosted models, phones and web, see [Connect a model](guides/connect-a-model.md).

A project set up with `--model both` or `on-device` can also answer with the model inside the app: the assistant offers the download the first time it opens. See [Choose where the model runs](guides/choose-where-the-model-runs.md).

## First chat

Open the assistant with the Assistant button and send:

```text
Switch to dark mode.
```

The assistant calls the `set_theme_mode` action, the app turns dark, and a receipt in the chat says what changed. The settings screen calls the same action when you tap Dark. See [Overview](concepts/overview.md) for why.

You can call the same action from a terminal, without the app:

```bash
dart run tool/action.dart set_theme_mode '{"mode":"dark"}'
```

This uses a scratch database under `.dart_tool/`, never the app's data.

## Next

- [Build your first feature](tutorial/build-your-first-feature.md): a notes screen by hand, with every file.
- [Build with a coding agent](tutorial/build-with-a-coding-agent.md): the same feature, built by an agent.
