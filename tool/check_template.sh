#!/usr/bin/env bash
# Proves every starting point passes its own gate: each starter, with a model
# server only and with the in-app model too (and the example with only the
# in-app model), is set up in a temp copy of this
# repo and runs that project's tool/check.sh, then upgrades it from this same
# checkout, which must change nothing. Last, the tutorial is followed on a new
# empty project, which must pass its gate too.
# Usage: tool/check_template.sh [--build]   (--build also builds web, and macOS on a Mac)
set -euo pipefail
cd "$(dirname "$0")/.."
framework="$PWD"

build=false
case "${1:-}" in
  "") ;;
  --build) build=true ;;
  *) echo "Usage: tool/check_template.sh [--build]" >&2; exit 64 ;;
esac

step() { printf '\n== %s\n' "$1"; }
git_() { git -c user.name='Template Check' -c user.email=template-check@example.com -c commit.gpgsign=false "$@"; }

dirs=()
current=""
trap 'status=$?; if [ "$status" -ne 0 ] && [ -n "$current" ]; then echo; echo "Template check failed. Inspect: $current"; fi' EXIT

for variant in example:server example:both example:on-device empty:server empty:both; do
  starter="${variant%%:*}"
  model="${variant##*:}"
  current="$(mktemp -d "${TMPDIR:-/tmp}/check_${starter}_${model}.XXXXXX")"
  dirs+=("$current")

  step "$starter, $model: copy"
  # tar keeps symlinks (.claude/skills) as symlinks.
  git ls-files -z --cached --others --exclude-standard |
    while IFS= read -r -d '' f; do
      if [ -e "$f" ] || [ -L "$f" ]; then printf '%s\0' "$f"; fi # skip deleted files
    done |
    tar --null -cf - -T - | tar -xf - -C "$current"
  (cd "$current" && git init -q && git_ add -A && git_ commit -q -m Template)

  step "$starter, $model: setup"
  (cd "$current" && dart tool/setup.dart --name "check_$starter" --org com.example --starter "$starter" --model "$model")
  (cd "$current" && git_ add -A && git_ commit -q -m "Set up")

  step "$starter, $model: gate"
  (cd "$current" && tool/check.sh 2>&1 | tee .check.log)
  [ "$(tail -n 1 "$current/.check.log")" = "All checks passed." ] || exit 1
  rm "$current/.check.log"

  step "$starter, $model: upgrade from this checkout changes nothing"
  (cd "$current" && git_ add -A && git_ commit -q --allow-empty -m "Gate")
  (cd "$current" && dart tool/upgrade.dart --from "$framework")
  changed="$(cd "$current" && git status --porcelain)"
  if [ -n "$changed" ]; then echo "$changed"; exit 1; fi

  if $build; then
    step "$starter, $model: build web"
    (cd "$current" && flutter build web)
    if [ "$(uname)" = Darwin ]; then
      step "$starter, $model: build macos"
      (cd "$current" && flutter build macos --debug)
    fi
  fi
done

# The tutorial, step by step, on a new empty project: its code must still
# build and pass the gate.
current="$(mktemp -d "${TMPDIR:-/tmp}/check_tutorial.XXXXXX")"
dirs+=("$current")
step "tutorial: copy and set up"
git ls-files -z --cached --others --exclude-standard |
  while IFS= read -r -d '' f; do
    if [ -e "$f" ] || [ -L "$f" ]; then printf '%s\0' "$f"; fi
  done |
  tar --null -cf - -T - | tar -xf - -C "$current"
(cd "$current" && git init -q && git_ add -A && git_ commit -q -m Template)
(cd "$current" && dart tool/setup.dart --name notes_app --org com.example --starter empty)
(cd "$current" && git_ add -A && git_ commit -q -m "Set up notes_app")
(cd "$current" && flutter pub get && dart run build_runner build)
step "tutorial: follow it"
dart tool/apply_tutorial.dart docs/tutorial/build-your-first-feature.md "$current"
(cd "$current" &&
  dart run build_runner build &&
  dart run drift_dev schema dump lib/data/local/database/app_database.dart drift_schemas/ &&
  dart run drift_dev schema generate drift_schemas/ test/generated_migrations/ &&
  dart format test/generated_migrations &&
  dart run tool/action.dart --write-reference)
step "tutorial: gate"
(cd "$current" && tool/check.sh 2>&1 | tee .check.log)
[ "$(tail -n 1 "$current/.check.log")" = "All checks passed." ] || exit 1

current=""
rm -rf "${dirs[@]}"
printf '\nTemplate checks passed.\n'
