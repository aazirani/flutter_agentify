# Agent loop

`AgentSession` runs one conversation turn: it sends the person's message and the screen to the model, runs the tools the model asks for, sends the results back, and repeats until the model replies without tool calls.

## Smallest example

```dart
final session = AgentSession(
  registry: registry,
  appContext: appContext,
  provider: buildProvider(presetId: 'ollama', baseUrl: 'http://localhost:11434/v1'),
  model: const ModelConfig(model: 'qwen3:8b'),
  threads: InMemoryThreadStore(),
  memories: InMemoryMemoryStore(),
  appInstructions: 'This app keeps a shopping list.',
);

final thread = await session.threads.createThread();
await for (final event in session.send(thread.id, 'Add milk')) {
  // TextDelta, ToolStarted, ToolFinished, ApprovalRequired, ChangeReceipt,
  // AnswerOnly, then one of Done, Cancelled, LoopLimit or AgentError.
}
```

`session.cancel()` stops the run. `send` throws `ArgumentError` for blank text and `StateError` while another run is active, before any request is made.

## Rules

- The stream ends with exactly one of `Done`, `Cancelled`, `LoopLimit` or `AgentError`, then closes. `AgentError` carries the model error's `kind` (see [model providers](model-providers.md)), or `other` for anything else, such as a storage failure. Its `message` is for logs; show a message for its `kind` instead.
- Every stored tool call gets a stored result, however the run ends. A call that did not run gets `{"error":"cancelled"}`. If the app quit before storing one, the call is sent to the model with that result (`withToolResults`).
- A failing tool call does not stop the run: the model gets `{"error": <code>, "message": ..., "details": ...}` and can correct itself. That covers invalid JSON, wrong types, unknown tools and actions that throw.
- The system text is the framework's rules, then `appInstructions`, then saved memories, then a summary of older messages. A memory saved during a run shows from the next run, or sooner when the history is summarized mid-run.
- A reply that stops before the model's end marker counts as a failed request. It is retried only when nothing had been streamed yet; otherwise the run ends with an error and the partial text is kept. It is never shown as finished.
- A reply cut by the model's output limit ends the run with `LoopLimit(outputLimit)`. Its text is kept; its tool calls are not run or stored.
- Stopping a run marks every unfinished tool call with a `ToolFinished` whose `errorCode` is `cancelled`, before the final event. A read-only call stops at once; a call to an action that writes (`readOnly == false`) already running is awaited to its end, and its result and receipts are recorded before `Cancelled`. Stopping while an approval is pending runs nothing.
- Tool results and the screen block are data, never instructions to follow.

## Limits (`AgentConfig`)

| Setting | Default | Ends the run with |
|---|---|---|
| `maxSteps` | 12 model requests | `LoopLimit(maxSteps)` |
| `tokenBudget` | 100,000 new tokens: each request's output plus the input it added (the history sent again is not counted twice) | `LoopLimit(tokenBudget)` |
| `repeatLimit` | the same call with the same arguments 3 times in a row | `LoopLimit(repeatedCall)` |
| `maxRetries` | 2 retries of a request that may succeed later, after 1 s, then 2 s (or the server's `Retry-After`, at most 30 s; Stop ends the wait). A timeout is not retried. | `AgentError(retryable: true)` |

## Small models

- **Tool search.** With a context window under 16,000 tokens (`smallContextWindow`) and tool definitions that would take more than a quarter of it (`toolSearchShare`, estimated), or with `forceToolSearch`, a step sends the built-in actions, the tools found earlier in the thread, the 4 best matches for the message (remembered, at most 8 per thread, for follow-up messages), and a `tool_search` tool that finds more (at most 8 results). A call to a tool that was not sent is refused with `tool_not_available`. Calls left open by a loop limit end with the error code `loop_limit`. No action may be named `tool_search`; the registry refuses it. `searchTools` and `searchHints` drive the matching.
- **Answer-only.** A model with `toolCalling: false`, or one the server says does not support tools, gets no tools; the run emits `AnswerOnly` once and the assistant answers from the screen block.
- **History budget.** When the stored history does not fit the context window next to the system text and the tool schemas, older messages are summarized by the model and dropped; the newest 8 (`keepRecentMessages`) usually stay, and the kept part always starts with a message from the person. If summarizing fails, they are dropped anyway; if the person stops the run meanwhile, nothing is dropped. A context-overflow error does this once, then retries.
- A small context window also gets shorter rules in the system text.

## Debugging

`session.debugSnapshot` holds the last system text, the tools sent, the run's tool calls and the token use. The inspector in flutter_agentify_ui shows it.
