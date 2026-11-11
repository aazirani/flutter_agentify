# Flutter widgets

`flutter_agentify_ui` turns an `AgentSession` into a Material 3 chat. It has two parts: `AssistantController`, which holds the chat's state, and `AssistantChat`, the widget that shows it. An app that wants another look can keep the controller and draw its own widget.

## Smallest example

```dart
final controller = AssistantController(session: session, threads: threads);
await controller.open(); // the newest thread, or a new one

Scaffold(body: AssistantChat(controller: controller));
```

## What the chat shows

- A header with the title, a Conversations button (past threads, newest first, titled by their first message), New chat, and a close button when `onClose` is set. New chat on an empty chat keeps that chat instead of making another empty one.
- Messages in a list that follows the newest one. Sending brings the newest message into view; scrolled far up, a button jumps back down. The person's bubble shows only what they typed, never the screen context sent with it. Assistant text is plain, selectable text (the core rules ask the model not to write Markdown). Each bubble runs in the direction of its own text, so Persian in an English chat reads right to left.
- Three pulsing dots while the model works out its next step: from Send until the first text, tool or approval request, again after each tool, and during a retry. Screen readers hear `thinking`. They never stay after Stop, an error or the end of a reply.
- One row per tool the assistant runs, named by `AssistantStrings.actionLabel` (a readable form of the action name unless `actionLabels` gives one), with a spinner while it runs. A failed call is marked in the error color; a call the person rejected reads Declined and one cut by Stop or by a safety limit reads Stopped, both in a neutral color. The loop's own `tool_search` is not shown.
- An approval card for an action that needs approval: the action label, its summary line when it has one, and its arguments as `key: value` lines (behind Details when there is a summary). Approve, Always allow and Reject sit in one row when they fit. Always allow is left out when the action's `allowAlways` is false; such an action is destructive, so Approve uses the error colors. The card is a live region, so screen readers announce it.
- Receipt chips under the reply they belong to: what really changed. A receipt the action could not read back (`verified` false) shows a question mark and says so in its tooltip.
- A notice above the composer when the model cannot use tools (answer-only).
- A notice when a reply stopped at a safety limit, with Continue. An error notice says what went wrong and what to do, from the error's `kind`; it never shows the raw error. It offers Open settings when `onOpenSettings` is set and the settings may fix it, and Retry when trying again may help. The raw error is in `controller.error` and in the debug log.
- When a reply ends, screen readers hear its text (or the error) once.
- While a reply runs, the send button becomes a stop button; after Stop it is disabled until a write that already started finishes. Send stays disabled for blank input. With a hardware keyboard (desktop and web), Enter sends and Shift+Enter starts a new line; the field keeps focus after sending.

## Controller

| Member | What it does |
|---|---|
| `items` | `UserItem` and `AssistantItem` entries (text, `tools`, `receipts`, `approval`, `cancelled`). |
| `open({threadId})` | Loads a thread, the newest one, or a new one. |
| `newThread()` | Starts an empty conversation, or keeps the current one when it is empty. |
| `retry()` | Repeats what failed: the load, or the last message. |
| `send(text)` | Sends a message; completes when the reply is finished. Blank text and sends during a reply are ignored. |
| `stop()` | Stops the running reply. |
| `approve(callId, {always, editedArgs})` | Approves a pending call; returns a message when edited arguments are invalid, and the card stays. |
| `reject(callId)` | Declines a pending call; the assistant hears that the person declined. |
| `onDevice`, `leavingDevice`, `continueOnServer()`, `startNewChat()` | With `onDevice: true` every sent turn marks the thread unshared (`ThreadStore.setUnshared`). Sending in an unshared thread with `onDevice: false` does not send: `leavingDevice` holds the text and the chat asks the person to continue with the server or start a new chat. |
| `isRunning`, `isWaiting`, `isStopping`, `pendingApproval`, `answerOnly`, `error`, `errorKind`, `canRetry`, `limit`, `lastUserText` | State for the widget. `isWaiting` is true while the model works out its next step; `pendingApproval` lets an app badge its assistant button. |

## Text and colors

Every color comes from `Theme.of(context)`, so light, dark and custom themes apply. Every piece of text comes from `AssistantStrings`; pass translated values for other languages:

```dart
AssistantChat(
  controller: controller,
  strings: AssistantStrings(
    inputHint: t('assistant_input_hint'),
    send: t('assistant_send'),
    emptyTitle: t('assistant_empty_title'),
  ),
);
```

The layout uses start and end instead of left and right, so it works in right-to-left languages. It fits a 320 × 480 screen.

## Debug inspector

`AssistantInspector(session: session)` shows what the model got on the last request: the system text, the tools sent, and the last run's tool calls with their results. Before the first message it shows a placeholder.

Pass the session to the chat to add a button that opens it in a sheet. The button appears in debug builds only:

```dart
AssistantChat(controller: controller, inspect: session);
```

The inspector's texts are `AssistantStrings` fields too (`inspectorOpen`, `inspectorTitle`, `inspectorSystem`, `inspectorTools`, `inspectorCalls`, `inspectorEmpty`).
