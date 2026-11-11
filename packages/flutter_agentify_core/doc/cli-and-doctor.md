# CLI and doctor

## Doctor

`dart run flutter_agentify_core:doctor` checks the repository. `tool/check.sh` runs it last.

| Check | What it checks |
|---|---|
| `agent-files` | `AGENTS.md` exists and has at most 6,000 characters; `CLAUDE.md` and `GEMINI.md` hold only `@AGENTS.md`; `.claude/skills` links to `.agents/skills` (on Windows it prints how to restore the link). |
| `skills` | Each skill in `.agents/skills/` has a `SKILL.md` of at most 6,000 characters with `name` and a `description` that says "Use when", and its related skills and repo paths exist. |
| `bundled-secrets` | Files listed under `flutter.assets` hold no key-shaped text and no `.env` file, and neither does the Dart source in each package's `lib`, `bin`, `test` and `tool` folders (a line, or the line below an `// ignore: flutter_agentify_lints/no_secret_literals` comment, is skipped there). Key shapes are the 13 patterns of `secretPatterns`, the same as the `no_secret_literals` lint and runtime redaction. |
| `migrations` | Database schema dumps in `drift_schemas/` only add: no table or column is removed, retyped or made non-nullable, and a new column on an existing table is nullable or has a default. `drift_schemas/allowed_removals.json` can list a removal per version. Every dump after the first needs `test/data/local/database/migrations/to_v<N>_test.dart`. |
| `ratchet` | The counts of `// ignore:` comments (also `ignore_for_file:`), `!` null assertions (also inside `${...}` in strings) and `dynamic` do not rise above `tool/baselines/ratchet.json`; generated files are skipped. With `"scope": "app"` in that file it counts only `lib/`; without it, `lib/` and `packages/*/lib/`. |
| `doc-links` | Each relative link (`[text](target)` or `![alt](target)`, outside code blocks and code spans) in the root `*.md` files, `docs/`, and each package's `README.md` and `doc/` points at a file or folder that exists. Web links and links that start with `#` are skipped. |

Flags: `--only a,b` runs the named checks; `--changed` limits `bundled-secrets` to changed files and makes `ratchet` fail on any `// ignore:`, `!` or `dynamic` on a line added since `--base <branch>` (default `main`), without comparing to the baseline; `--update-baselines` writes the current ratchet counts. The doctor has no `--help`; a bad flag or unknown check name exits 2.

Exit codes: 0 all passed, 1 a check failed, 2 a check could not run (or a bad flag or unknown check name). Each check prints `PASS`, `FAIL` or `ERROR` and its messages.

## Action CLI

The app's `tool/action.dart` builds its registry without Flutter and hands over to `runActionCli` from `package:flutter_agentify_core/cli.dart`:

```bash
dart run tool/action.dart --list
dart run tool/action.dart add_note '{"text":"Milk"}'
dart run tool/action.dart delete_note '{"id":"7"}' --approved
dart run tool/action.dart --write-reference
```

A call runs as `Caller.cli`, so an action that needs approval needs `--approved`. Success prints the result JSON on one line and a `receipt: <summary>` line per receipt; failure prints `<code>: <message>` (with the field path in parentheses for invalid input) on stderr. Exit codes: 0 ok, 1 the action failed, 64 a usage error such as invalid JSON. `--write-reference` writes the action reference that `buildActionReference(registry)` generates. Its flags per action: `read-only` or `writes <resources>`, `UI-only`, and `needs approval` when a minimal sample input needs it, or `may need approval` when that sample cannot be built or checked (approval then depends on the real input).

## Parity check

`parityProblems(...)` from `package:flutter_agentify_core/parity.dart` lists what keeps the UI and the assistant apart: an action without a test file (or whose test never mentions its name; the built-in actions are skipped), an action reference that differs from the generated one, a route without a screen-context entry, or an entry without a route. An app's test is one line: `expect(parityProblems(...), isEmpty);`. It never writes files.

## Docs search

```bash
dart run flutter_agentify_core:docs --query "needs approval"
dart run flutter_agentify_core:docs --list
```

Prints `<file>:<line>: <text>` for each line of these pages holding every word, ignoring case. These pages come with the installed version, so no web lookup is needed. Exit code 1 when nothing matches, 64 for a usage error.
