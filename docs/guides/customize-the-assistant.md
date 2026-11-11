# Customize the assistant

The assistant is part of your app. You change what it is told, what its chat says and how it looks in the app's own files. Leave `packages/` alone: an upgrade replaces it.

## What it is told

`assets/assistant/instructions.md` holds the app's instructions to the model. The app loads it once at start and sends it to the model as part of the system text.

Say three things in it, briefly:

- what the app is for;
- which tools exist, by name, and what they are for;
- any rule the model must follow.

The empty starter's file:

```markdown
This app has a home screen and a settings screen. The person can change the theme and the language.

You can do the same through your tools:
- set_theme_mode and set_language for the settings;
- navigate to open the home screen (/) or the settings (/settings).

You cannot change your own settings: the model server, the model or the API key. When asked, open the settings (/settings) and say they can change them there under Assistant.

Answer in the person's language, in a sentence or two.
```

Update it when you add or rename an action, as in [Build your first feature](../tutorial/build-your-first-feature.md#15-tell-the-assistant).

Do not:

- paste the action reference into it. The model already gets each tool's description and input;
- tell the model to ask in the chat before a delete. The app asks for approval itself; see [Approval and receipts](../concepts/approval-and-receipts.md);
- put a key, a token or personal data in it. The file ships inside the app, and the doctor's `bundled-secrets` check scans it:

  ```bash
  dart run flutter_agentify_core:doctor --only bundled-secrets
  ```

To see what the model really received, run a debug build and open the inspector from the chat. It shows the system text, the tools offered and the last calls. It does not exist in release builds.

## What the chat says

The chat's texts come from the language files, under keys that start with `assistant_`, such as:

```json
  "assistant_input_hint": "Ask the assistant",
  "assistant_empty_title": "How can I help?",
```

Change the value in every file in `assets/lang/` (`en.json` and `fa.json` to start with). `lib/presentation/assistant/assistant_strings_l10n.dart` maps each key to the chat. Then check that the files still match:

```bash
flutter test test/i18n
```

## How it looks

The chat takes its colors and text styles from the app's theme in `lib/core/theme/`. Change the theme, not the chat. The lint rule `no_hardcoded_colors` fails the gate on a literal color.

## Where it opens

`lib/presentation/assistant/assistant_shell.dart` wraps every screen. On a window at least 840 wide, the chat opens as a side panel; on a narrower one, as a bottom sheet. The width is one constant there, `assistantPanelBreakpoint`. The toggle button in `lib/presentation/assistant/assistant_toggle_button.dart` reads the same constant.

## What it sees of the screen

Each route has an entry in `lib/ai/screen_contexts.dart`. That is what the assistant knows about the screen the person is on. See [App context](../concepts/app-context.md).

## Check

```bash
tool/check.sh
```

The `customizing-the-assistant` skill in `.agents/skills/` covers the same ground for a coding agent.
