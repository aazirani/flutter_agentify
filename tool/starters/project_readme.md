# {{title}}

## Requirements

Flutter 3.47 or newer (Dart 3.13 or newer) with the toolchain for at least one platform (`flutter doctor` says what is missing), and bash for `tool/check.sh` (on Windows, Git Bash or WSL).

## Run

    flutter pub get
    dart run build_runner build
    flutter run

## Connect a model

The assistant needs a model. With [Ollama](https://ollama.com) on the same computer: start it, run `ollama pull qwen3:8b`, then in the app open Settings, keep the model server at Ollama, type `qwen3:8b` as the model and save. Where the model runs is set in `lib/ai/assistant_setup.dart`.

## Check

    tool/check.sh

Work is done when it ends with `All checks passed.`

## About

Built with [Flutter Agentify](https://github.com/aazirani/flutter_agentify). Docs: https://github.com/aazirani/flutter_agentify/tree/main/docs. Rules for people and coding agents working in this repo: [AGENTS.md](AGENTS.md). To bring in the newest framework: `dart tool/upgrade.dart`.
