# Contributing

Thank you for your interest in contributing to Flutter Agentify. This document outlines the process for contributing code, reporting issues, and requesting features.

## Getting Started

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:

```bash
git clone https://github.com/YOUR_USERNAME/flutter_agentify.git
cd flutter_agentify
```

3. Add the upstream remote:

```bash
git remote add upstream https://github.com/aazirani/flutter_agentify.git
```

### Prerequisites

- [Flutter](https://flutter.dev/docs/get-started/install) 3.47 or later
- [Dart](https://dart.dev/get-dart) 3.13 or later
- A code editor with Dart/Flutter support (VS Code or Android Studio recommended)

### Setup

```bash
flutter pub get
dart run build_runner build
```

After making changes to Riverpod providers or drift tables, re-run the build runner:

```bash
dart run build_runner build
```

## Code Style

This project uses `flutter_lints` and its own rules from `packages/flutter_agentify_lints` for static analysis. Before submitting code, run the gate:

```bash
tool/check.sh
```

It generates code, checks the database schema dump, formatting, analysis, every test suite and the doctor, and ends with `All checks passed.` See [Quality gate](docs/concepts/quality-gate.md) for each step, the rules, and how to opt a line out with `// ignore: flutter_agentify_lints/<rule>`.

- Maximum line length: 80 characters for Dart files
- Indentation: 2 spaces (never tabs)
- Follow Clean Architecture layer boundaries: domain code must not depend on data or presentation layers

## Working on the app

`AGENTS.md` describes the rules every change follows, for people and coding agents alike: the layers, changing data only through actions, localized strings and theme colors, and additive database migrations. A new feature covers four areas: the screen, an action with its test in `test/actions/`, the regenerated action reference (`dart run tool/action.dart --write-reference`) and a screen-context entry in `lib/ai/screen_contexts.dart`. The skills in `.agents/skills/` explain each topic in more depth.

## Testing

`tool/check.sh` runs every test suite: the app's (`flutter test`) and each package's (`dart test` in `packages/flutter_agentify_core` and `packages/flutter_agentify_lints`, `flutter test` in `packages/flutter_agentify_ui` and `packages/flutter_agentify_on_device`). Every action needs `test/actions/<action_name>_test.dart`; the parity test reports a missing one.

All new features and bug fixes should include appropriate tests. Place widget tests in `test/` following the same directory structure as `lib/`.

## Branch Naming

Use the following prefixes for branch names:

| Prefix       | Purpose                         |
|--------------|---------------------------------|
| `feat/`      | New features                    |
| `fix/`       | Bug fixes                       |
| `docs/`      | Documentation changes           |
| `refactor/`  | Code restructuring (no behavior change) |
| `chore/`     | Maintenance tasks, dependency updates |

Example: `feat/add-firebase-auth`, `fix/router-navigation-bug`

## Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
type(scope): short description

Longer description if needed, wrapped at 72 characters.
```

| Type       | Purpose                         |
|------------|---------------------------------|
| `feat:`    | New feature                     |
| `fix:`     | Bug fix                         |
| `docs:`    | Documentation only              |
| `refactor:`| Code change that neither fixes nor adds |
| `chore:`   | Build process, tools, deps      |
| `test:`    | Adding or updating tests        |

Example: `feat(router): add navigation guard for unauthenticated users`

## Pull Request Process

1. Create a branch from `main` using the naming convention above
2. Make your changes and commit them following the commit convention
3. Push your branch to your fork
4. Open a pull request against the `main` branch
5. Fill in the pull request template completely
6. Ensure `tool/check.sh` passes
7. Request review from a maintainer

Pull requests are squashed and merged. Keep PRs focused: one feature or fix per PR.

## Before merging into main

1. Run the gate:

   ```bash
   tool/check.sh
   ```

2. Set up both starting points in temporary copies, with a model server and with the model inside the app, run each one's gate, follow the tutorial on a new empty project, and build each one for web, and for macOS on a Mac:

   ```bash
   tool/check_template.sh --build
   ```

3. Follow [Build your first feature](docs/tutorial/build-your-first-feature.md) literally, from its first command, and end with its gate. It creates a new empty project. To test this checkout instead of the `main` on GitHub, commit your work first (a clone takes only committed work), then run its `git clone` line with this repo's path in place of the GitHub address, from this repo's root:

   ```bash
   git clone --depth 1 "file://$PWD" ../notes_app
   ```

4. If the chat or the Home screen looks different, draw the screenshots in `docs/images/` again and look at each one. The script drives the real app with scripted model replies:

   ```bash
   flutter test tool/docs_screenshots_test.dart --update-goldens
   ```

   The animated demo at the top of the README comes from the same app; draw it again with `tool/make_demo.sh` (needs ffmpeg).

5. Head the top changelog entry with today's date, for example `## 2027-01-15`, and merge into `main`. There are no versions or tags: `dart tool/upgrade.dart` takes the newest `main`.

6. Once the merge is on GitHub, make a new `example` project from `main` and follow [Drop the example later](docs/guides/choose-a-starting-point.md#drop-the-example-later) to its end. Its upgrade step fetches `main` from GitHub.

## Reporting Bugs

Use the [Bug Report](https://github.com/aazirani/flutter_agentify/issues/new?template=bug_report.md) issue template. Include:

- A clear, descriptive title
- Steps to reproduce the issue
- Expected and actual behavior
- Your environment (Flutter version, OS, device)

## Requesting Features

Use the [Feature Request](https://github.com/aazirani/flutter_agentify/issues/new?template=feature_request.md) issue template. Describe:

- The problem or need your feature addresses
- Your proposed solution
- Any alternatives you have considered

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
