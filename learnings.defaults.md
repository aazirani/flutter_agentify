# Learnings

Things already learned about this repository. Read this file and `learnings.md` (your own notes, not committed) at the start of a session. Add new findings to `learnings.md`, one line each, with the date.

- Generated files (`*.g.dart`, `*.drift.dart`) are not committed. Run `dart run build_runner build` before analyzing or testing a fresh checkout; `tool/check.sh` does it first for that reason.
- `build_runner` does not accept `--delete-conflicting-outputs`; leave it out.
- Riverpod 3: generated provider functions take `Ref`; there are no generated `XxxRef` types.
- drift part files end in `.drift.dart`, and drift's row classes for the assistant tables are named `AssistantThreadRow`, `AssistantMessageRow` and `AssistantMemoryRow` so they do not clash with `flutter_agentify_core` types.
- The lint plugin's rules show only in `dart analyze` from the repo root. After changing the plugin or its config in `analysis_options.yaml`, restart the IDE's analysis server.
- Screens call actions with typed input through `registry.run`, which skips the JSON schema: actions validate inside `run`. `registry.call` (JSON input) is for the assistant and CLI and refuses `Caller.ui`.
- In widget tests, `pumpTestApp` clears the asset cache: a translation cached by an earlier test never finishes loading in the next one.
- macOS debug builds keep the API key in the login keychain (`usesDataProtectionKeychain: false`); the data-protection keychain needs a signing entitlement.
