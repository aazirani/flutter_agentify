# Build with a coding agent

In this tutorial a coding agent builds the notes feature from [Build your first feature](build-your-first-feature.md). You write one prompt. The agent gets the template, sets it up, builds the feature and runs the gate. You check its report.

Any agent that reads `AGENTS.md` works: Claude Code, Codex, Gemini CLI and others. It needs a terminal with Flutter, Git and, for the first command, the [GitHub CLI](https://cli.github.com). See [Coding agents](../concepts/coding-agents.md) for the files that guide it.

## The prompt

Paste this into the agent, with your app's name and what it should do:

```text
Create a new app with Flutter Agentify. Get the template with
`gh repo create <name> --template aazirani/flutter_agentify --private --clone`
(or `git clone --depth 1 https://github.com/aazirani/flutter_agentify.git <name>`),
read AGENTS.md in it and follow it from the top. The app I want: <describe the app>.
```

For this tutorial, `<name>` is `notes_app` and the app is:

```text
A notes app. One screen at /notes lists my notes, newest first. I can add a
note and delete one. The assistant can list, add and delete notes; it asks me
before it deletes. Run it on macOS. I use Ollama on this computer, no key.
```

## What the agent does

### 1. Gets the template

It runs one of the two commands in the prompt. `gh repo create … --private --clone` makes a new private repository on your GitHub account and clones it. `git clone` only copies the template.

### 2. Reads `AGENTS.md`

The first section of a fresh template says it is not set up yet, and gives the setup command. It also says to load the `build-an-app` skill next.

### 3. Runs setup

```bash
dart tool/setup.dart --name notes_app --org com.example --starter empty
```

`AGENTS.md` shows `--starter empty`; `--starter example` keeps the item list. Setup removes the "not set up" section from `AGENTS.md`, moves the item example to `.agents/example/` and prints the next commands. The agent runs them, starting with a commit of what setup changed:

```bash
git add -A && git commit -m "Set up notes_app"
flutter pub get
dart run build_runner build
tool/check.sh
```

The agent does not start `flutter run` unless you ask, since it keeps running. To try the app yourself, run `flutter run`.

### 4. Loads `build-an-app`

The skill is in `.agents/skills/build-an-app/SKILL.md`. It makes the agent settle six things before it writes code: purpose, data, screens, actions, model setup and platforms. It asks you only what your request leaves open, then states its choices in a few lines. Answer, or say "go on". Your prompt names Ollama without a key, so the model server setup stays at its default; you still pick the model in the app's Settings (see [Connect a model](../guides/connect-a-model.md)).

### 5. Builds one slice, following `.agents/example/`

`.agents/example/` holds the item example: table, repository, actions, screen and tests. The agent copies its shape for notes, through every layer. It also loads the skills each layer needs, such as `storing-data` for the schema change and `actions` for the actions.

### 6. Runs the gate

```bash
dart run tool/action.dart --write-reference
tool/check.sh
```

`AGENTS.md` says work is done only when the gate ends with `All checks passed.` If a step fails, the agent fixes the code and runs the gate again.

## What to check in its report

`build-an-app` asks the agent to end with a report. Check that it has:

- **The gate's last line.** It must say `All checks passed.` Run the gate yourself to be sure:

  ```bash
  tool/check.sh
  ```

- **What it built.** The new files under `lib/` and `test/`, and the routes.
- **What it left out.** Screens, platforms, edge cases or translations it did not do. An empty list is a reason to ask.
- **The actions.** `list_notes`, `create_note` and `delete_note` should be there:

  ```bash
  dart run tool/action.dart --list
  ```

- **Approval on deletes.** This should fail with `approval_required`:

  ```bash
  dart run tool/action.dart delete_note '{"id":"any"}'
  ```

- **No edits it should not make.** Nothing under `packages/`, no generated files, no raised baselines:

  ```bash
  git diff --stat "$(git rev-list -1 --grep='Set up notes_app' HEAD)" -- packages/ tool/baselines/
  git status --short packages/ tool/baselines/
  ```

  The first line compares with the commit setup made, so it also shows what the agent already committed; the second shows new files not committed yet.

  This prints nothing when it kept to the rules. The `edit-boundaries` skill lists what is off limits.

Then run the app and try the notes screen and the assistant, as in [Build your first feature](build-your-first-feature.md#17-try-the-app).

## When it goes wrong

- **The agent skips setup.** Point it at `AGENTS.md` again. Setup refuses a second run, so a project set up once stays set up.
- **The agent reports done without the gate.** Ask for the last lines of `tool/check.sh`.
- **The agent edits `packages/`.** Ask it to undo that. Changes there are lost on the next upgrade; see [Upgrade](../guides/upgrade.md).

More fixes are in [Troubleshooting](../guides/troubleshooting.md).
