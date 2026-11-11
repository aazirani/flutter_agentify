# Troubleshooting

Find the message or the symptom, then run the fix.

## Setup refuses to run

Setup checks its flags and the git tree before it writes a file. A refusal at that point leaves the project as it was. A failure after it started writing prints the command that undoes it.

### "This project is already set up."

Setup runs once, on a fresh copy of the template. It removes itself when it is done. To start again, get a new copy:

```bash
git clone --depth 1 https://github.com/aazirani/flutter_agentify.git notes_app
```

### "Commit or stash your changes first, so a failed run can be undone."

The folder is a git repo with changes. Commit them, or put them aside:

```bash
git stash
```

### A flag is wrong (exit code 64)

Setup names the flag and what it accepts, then prints its usage. For example:

```text
--name "NotesApp": use lowercase letters, digits and _, starting with a letter (for example notes_app).
```

Change the flag as the message says. For the rules of every flag, run:

```bash
dart tool/setup.dart --help
```

The [reference](../reference/README.md) points to the same help. If setup refuses the name people see (`--title`), see [Rebrand](rebrand.md#a-name-setup-refuses).

### Setup lists lines that still hold the old name

After writing, setup searches the project for the template's name. A file you added before setup can hold it. Setup stops, lists each line, and prints the command that undoes its changes, such as:

```bash
git reset --hard && git clean -fd
```

Run it, change or remove the file it named, commit, and run setup again.

## Generated code is stale

Errors such as `Target of URI hasn't been generated`, a missing `part` file, or an undefined `_$AppDatabase` mean the generated files are missing or old. They are not in git. Generate them:

```bash
dart run build_runner build
```

Run it after a clone, a pull, a branch switch, and any change to a drift table or an `@riverpod` function.

## "The database schema changed"

The gate compares the tables in the code with the dumps in `drift_schemas/`. You changed a table without a new schema version. Raise `schemaVersion`, add the step to `onUpgrade`, then dump the schema and write a migration test, as in [Build your first feature](../tutorial/build-your-first-feature.md#3-the-database):

```bash
dart run drift_dev schema dump lib/data/local/database/app_database.dart drift_schemas/
```

## The parity test fails

`test/ai/parity_test.dart` names what is missing: an action with no test file in `test/actions/`, a stale action reference, or a route with no entry in `lib/ai/screen_contexts.dart`. For a stale reference:

```bash
dart run tool/action.dart --write-reference
```

## The lint rules do not show

The custom rules come from the `flutter_agentify_lints` analyzer plugin. They show only in `dart analyze` run from the project root, and in the gate:

```bash
dart analyze --fatal-infos
```

They do not show in `flutter analyze` or in `dart analyze lib`.

If `dart analyze` from the root shows none of them either:

1. Get the plugin's own dependencies:

   ```bash
   (cd packages/flutter_agentify_lints && dart pub get)
   ```

2. Check that `analysis_options.yaml` still has the `plugins:` section with `flutter_agentify_lints` and its rules under `diagnostics:`.
3. In your editor, restart the Dart analysis server. It loads the plugin only at start.

The rules themselves are listed in [Lint rules](../../packages/flutter_agentify_core/doc/lints.md).

## The assistant cannot reach the model

First check the server from the same machine:

```bash
curl http://localhost:11434/v1/models
```

### On a phone or an emulator

`localhost` on a phone is the phone itself. Use your computer's address on the network, such as `http://192.168.1.20:11434/v1`, and make the server listen on the network. An Android emulator reaches the computer at `10.0.2.2`. See [Connect a model](connect-a-model.md#a-phone-and-a-server-on-your-computer).

### On macOS

The sandbox blocks network calls unless the entitlements allow them. Both `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements` must have `com.apple.security.network.client`. See [Platforms](platforms.md#macos).

### With a key, over `http://`

The app refuses to send a key over plain `http://` to a host that is not local. Use `https://`.

### On web: CORS

The browser blocks a call when the server does not allow the page's address. The browser's console shows a CORS error. Make the server allow that address, for Ollama with `OLLAMA_ORIGINS`, or put your own proxy in between. A page on `https://` cannot call an `http://` server at all. See [Connect a model](connect-a-model.md#web).

## The model on this device does not answer

Only in a project set up with `--model both` or `on-device`. The chat or Settings says why:

- "This device cannot run the on-device assistant." or "Not enough memory on this device.": the device is below the floors. Use a model server instead. See [Which devices can run it](choose-where-the-model-runs.md#which-devices-can-run-it).
- "The download failed.": choose Retry.
- "The model did not fit in memory last time." or "The model on this device could not start.": choose Retry, or Delete model to free the space. See [When the model does not fit in memory](choose-where-the-model-runs.md#when-the-model-does-not-fit-in-memory).
- "Not ready yet" in the chat: no model can answer. Download the model, or set up a model server in Settings.

## The assistant answers but does nothing

The chat says the model cannot use the app's actions. The model is set up without tool calling, so the assistant is in answer-only mode. Choose a model that supports tools. If yours does, check "Model can call tools" under Advanced in Settings. See [Model providers](../concepts/model-providers.md#answer-only-mode).

## The gate fails

The gate prints a `== <step>` line before each step and stops at the first failure. The last `==` line in its output names the step that failed; the lines under it say why. Fix that, then run the whole gate again:

```bash
tool/check.sh
```

[Quality gate](../concepts/quality-gate.md) says what each step checks.
