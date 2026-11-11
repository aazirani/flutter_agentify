#!/usr/bin/env bash
# The single gate: run this before saying work is done. CI runs the same file.
set -euo pipefail
cd "$(dirname "$0")/.."

step() { printf '\n== %s\n' "$1"; }

step "dependencies"
flutter pub get
# The packages resolve on their own (their test tools need a newer test_api
# than Flutter pins), so they are not part of a pub workspace.
(cd packages/flutter_agentify_core && dart pub get)
(cd packages/flutter_agentify_lints && dart pub get)
(cd packages/flutter_agentify_ui && flutter pub get)
# Only projects set up with the in-app model have this package.
on_device=packages/flutter_agentify_on_device
if [ -d "$on_device" ]; then (cd "$on_device" && flutter pub get); fi

step "generate code"
dart run build_runner build

step "schema dump is current"
rm -rf .dart_tool/flutter_agentify/schema && mkdir -p .dart_tool/flutter_agentify/schema
dart run drift_dev schema dump lib/data/local/database/app_database.dart .dart_tool/flutter_agentify/schema/
for f in .dart_tool/flutter_agentify/schema/*.json; do
  cmp -s "$f" "drift_schemas/$(basename "$f")" || {
    echo "The database schema changed. Raise schemaVersion, add a migration, then run:"
    echo "  dart run drift_dev schema dump lib/data/local/database/app_database.dart drift_schemas/"
    exit 1
  }
done

step "format"
# .agents/ holds reference code nobody edits, so a new format style must not fail on it.
git ls-files -z --cached --others --exclude-standard '*.dart' ':!.agents/' | xargs -0 dart format --output=none --set-exit-if-changed

step "analyze"
# dart analyze, not flutter analyze: it waits for the flutter_agentify_lints
# plugin, and --fatal-infos makes its rules fail the gate.
dart analyze --fatal-infos

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

printf '\nAll checks passed.\n'
