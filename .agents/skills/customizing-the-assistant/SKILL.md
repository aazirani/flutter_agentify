---
name: customizing-the-assistant
description: How to change what the assistant is told, what its chat says, how it looks, where it opens, and how to see what it sent. Use when editing the assistant's instructions, chat texts, chat appearance, panel or sheet behavior, or the debug inspector.
---

# Customizing the assistant

Don't load this for choosing the model or its settings; see `model-providers`. For what the assistant knows about the current screen, see `app-context`.

## Rule

Change the assistant by editing the files below, not the packages. The instructions are a runtime asset, the chat texts come from the app's translations, and the chat takes its look from the app theme. The instructions file is bundled with the app, so the doctor's `bundled-secrets` check scans it: no key or key-shaped text in it.

## Why

The assistant is part of the app, so it speaks the person's language and follows the theme. Keeping the instructions in an asset lets you change them without touching Dart, and keeping them short leaves room for the conversation.

## How

- **Instructions:** `assets/assistant/instructions.md`, loaded once at start in `lib/ai/ai_injection.dart` and passed to the session as `appInstructions` (`lib/ai/assistant_providers.dart`). Say what the app is, which tools exist and the rules the model must follow (for example: delete right away, the app shows the approval card). Update it when you add or rename an action. Don't paste the action list from the reference; the model already receives the tool definitions.
- **Chat texts:** the chat takes an `AssistantStrings` object (defaults in English, `packages/flutter_agentify_ui/lib/src/assistant_strings.dart`). The app builds it from translations in `lib/presentation/assistant/assistant_strings_l10n.dart`. To change a text, change its `assistant_*` key in every file in `assets/lang/`; to add a text, add a field to `AssistantStrings` and a line in the l10n file (`i18n-and-rtl`).
- **Theming:** the chat reads `Theme.of(context)` colors and text styles. Change the theme, not the chat widget. No hard-coded colors (`no_hardcoded_colors`).
- **Panel versus sheet:** `lib/presentation/assistant/assistant_shell.dart` shows a 380-wide side panel when the window is at least `assistantPanelBreakpoint` (840) wide and a full-height bottom sheet otherwise. `lib/presentation/assistant/assistant_toggle_button.dart` makes the same decision when tapped. Change the breakpoint in one place, the constant.
- **Debug inspector:** in debug builds only, the chat shows a button that opens the inspector: the system text sent, the tools offered and the last calls. Use it to check what the model really received. It does not exist in release builds.
- **Answer-only notice:** shown when the model cannot use tools; see `model-providers`.
- **Which model answers:** the chat takes a `ModelStatus` (header label, the in-app model's card, progress and states, the chat's menu). The app builds it in `lib/presentation/assistant/assistant_shell.dart`; its texts are the `on_device_*` keys. Where the model runs is chosen in `lib/ai/assistant_setup.dart` (`model-providers`).

## Anti-patterns

- Pasting a key, a URL with a token or user data into the instructions.
- A literal string in the chat code instead of an `assistant_*` key.
- Instructions that contradict approval (telling the model to ask in the chat before a delete; the app already asks).
- Editing `packages/flutter_agentify_ui` to restyle one app.

## Verification

- `dart run flutter_agentify_core:doctor --only bundled-secrets` for the asset.
- `test/i18n/translations_test.dart` for matching `en` and `fa` keys; `test/presentation/assistant/assistant_shell_test.dart` for panel versus sheet.
- Run the app in debug and open the inspector to read the system text.
- `tool/check.sh` (see `verify`).

## Related skills
- `app-context` — the screen block sent with each message
- `approval-and-safety` — what the instructions must not override
- `i18n-and-rtl` — adding translated chat texts
- `ui-design` — theme and layout rules
