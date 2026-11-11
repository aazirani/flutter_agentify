---
name: delegate-to-agent
description: Where judgment work goes. Summarizing, classifying and drafting are done by the assistant in the chat, using actions to read and write, while actions stay deterministic and no model is called outside lib/ai/. Use when a feature seems to need the app to think, write text or decide something.
---

# Delegate to the agent

Don't load this for writing an ordinary deterministic action; see `actions`.

## Rule

- Work that needs judgment (summarize, classify, draft, rewrite, suggest) is done by the assistant in the chat.
- It uses actions to read the data and to write the result.
- Actions are deterministic: same input, same effect, no model call inside.
- No model call anywhere outside `lib/ai/`.

No automated check exists for this rule. It is held by review and by the layer rules (`domain_layer_boundaries` keeps `lib/domain/` free of Flutter and `data/`), which do not stop a stray HTTP call to a model.

## Why

A model call inside an action makes it slow, costly, flaky and impossible to test, and it hides a second model from the person's model setup, key and approval flow. In the chat the person sees the work, can correct it, and the app only writes through actions with receipts.

## How

Say the feature as two steps: the assistant reads, thinks, then writes.

- "Summarize my items": the assistant calls `list_items` (`lib/domain/actions/items_actions.dart`), writes the summary in its answer. No new action.
- "Give each item a better title": it reads with `list_items`, then calls `update_item` for each. If it needs many writes, a bulk action may be right, with approval; see `approval-and-safety`.
- "Draft a description": it proposes text; the person agrees, then it calls `update_item`.

What you add is the plumbing the assistant needs: a read action that returns the data with ids, a write action that accepts the result, and a screen-context entry (`app-context`). Then tell the assistant about the capability in `assets/assistant/instructions.md`, the app's own instructions that `lib/ai/assistant_providers.dart` loads into the session (`appInstructions`). The model, key and provider come from the person's settings there; features never choose them.

Test the flow without a real model using `ScriptedProvider` in `test/ai/assistant_flow_test.dart`: script the tool calls the model would make, and assert the stored result.

## Anti-patterns

- An action named `summarize_items` or `suggest_title` that calls a model.
- A repository, screen or provider calling a model API directly.
- An action that produces text "by rule" and pretends to be judgment (keyword matching to classify).
- Putting a key in an action to reach a model.
- Hiding the work: the assistant writes without the person seeing a receipt.

## Verification

- No automated check. Search for stray model calls: `grep -rn "http" lib/` and confirm none outside `lib/ai/` reach a model.
- `flutter test test/ai/assistant_flow_test.dart` for the scripted flow.
- `tool/check.sh` ends with `All checks passed.`

## Related skills

- `actions` — the read and write actions the assistant uses.
- `app-context` — what the assistant can see while it works.
- `approval-and-safety` — approval for bulk writes the assistant makes.
- `adding-a-feature` — the checklist for the plumbing.
- `customizing-the-assistant` — where the assistant's instructions live.
- `model-providers` — which model does the judgment work.
