# Quality gate

`tool/check.sh` is the one command that says whether work is done. It runs every check in order and stops at the first failure. Work is done only when it ends with `All checks passed.`

```bash
tool/check.sh
```

## Why

People and coding agents both change this code. The gate gives both the same answer to "is it done?". It checks the rules that review often misses: layer imports, hard-coded strings, keys in assets, and actions without a test.

## What it runs

The last steps, from [`tool/check.sh`](../../tool/check.sh):

```bash
step "tests"
flutter test
(cd packages/flutter_agentify_core && dart test)
(cd packages/flutter_agentify_lints && dart test)
(cd packages/flutter_agentify_ui && flutter test)
if [ -d "$on_device" ]; then (cd "$on_device" && flutter test); fi

step "doctor"
dart run flutter_agentify_core:doctor

step "action smoke check"
# The default language: the first locale in kSupportedLanguages.
locale="$(sed -nE "/locale:[[:space:]]*['\"]/{s/.*locale:[[:space:]]*['\"]([^'\"]+)['\"].*/\1/p;q;}" lib/domain/entities/language/supported_languages.dart)"
[ -n "$locale" ] || { echo "No locale found in lib/domain/entities/language/supported_languages.dart"; exit 1; }
dart run tool/action.dart set_language "{\"locale\":\"$locale\"}" > /dev/null
```

`$on_device` is `packages/flutter_agentify_on_device`, which only a project with the model inside the app has. Before these, it gets the dependencies, generates code, compares the database schema, checks the format, and runs `dart analyze --fatal-infos`. The smoke check runs one action from the command line, which proves the actions still run without Flutter.

## The parts

- **Lint rules.** They run inside `dart analyze` from the repo root. They hold the architecture, such as which layer may import which. `flutter analyze` does not show them.
- **The doctor.** It checks the files around the code, such as `AGENTS.md`, the skills and the database migrations. Its ratchet counts escape hatches such as `// ignore:`, and the counts may only go down.
- **The parity test.** [`test/ai/parity_test.dart`](../../test/ai/parity_test.dart) fails when an action has no test, the action reference is stale, a route has no screen entry, a screen entry matches no route, or an action the assistant can call has no `action_<name>` label in a language file. It keeps the UI and the assistant in step.

Run one part on its own:

```bash
dart analyze --fatal-infos
dart run flutter_agentify_core:doctor --only doc-links
flutter test test/ai/parity_test.dart
```

## Reference

- [Lints](../../packages/flutter_agentify_core/doc/lints.md): every rule, with good and bad code.
- [CLI and doctor](../../packages/flutter_agentify_core/doc/cli-and-doctor.md): every doctor check, its flags and exit codes.
