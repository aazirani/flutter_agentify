# Model providers

A provider reaches a model. The app chooses one; nothing is hosted for it.

| Provider | Covers |
|---|---|
| `OpenAiCompatibleProvider(baseUrl:, apiKey:)` | OpenAI, OpenRouter, Ollama (`/v1`), LM Studio, llama.cpp server, Gemini's OpenAI-compatible endpoint, and your own proxy. `maxTokensField` names the output limit field: `max_tokens` by default, `max_completion_tokens` for OpenAI's own API (the `openai` preset sets it). |
| `AnthropicProvider(apiKey:)` | Claude through Anthropic's Messages API. |

`providerPresets` lists ready-made settings (`ollama`, `lm_studio`, `openai`, `openrouter`, `gemini`, `anthropic`, `custom`), each a `ProviderPreset` with `id`, `label`, `baseUrl`, `keyUse` and `defaults` (a `ModelConfig`; the model name is empty except for `anthropic`, which sets `claude-sonnet-5-5`, a 200,000-token window and 16,000 output tokens; the other hosted presets set 128,000 and 8,192). `ModelConfig` itself defaults to `toolCalling: true`, `streaming: true`, `contextWindow: 8192`, `maxOutputTokens: 2048`. `buildProvider(presetId:, baseUrl:, apiKey:)` builds the matching provider. Each preset's `keyUse` says whether its server takes a key: `KeyUse.none` (`ollama`, `lm_studio`), `KeyUse.optional` (`custom`) or `KeyUse.required` (the hosted ones).

## Smallest example

```dart
final provider = buildProvider(presetId: 'ollama', baseUrl: 'http://localhost:11434/v1');
const model = ModelConfig(model: 'qwen3:8b', toolCalling: true, contextWindow: 8192);
```

## Rules

- Capabilities belong to the model, not the provider: `ModelConfig` holds `toolCalling`, `streaming`, `contextWindow` and `maxOutputTokens`. One Ollama server can host models with and without tool calling.
- Every provider streams `LlmTextDelta` and `LlmToolCall` events, then one `LlmDone` with the token use. `LlmDone.truncated` is true when the model stopped at its output limit (`maxOutputTokens`). Cancelling closes the stream without `LlmDone` and without an error.
- `close()` frees the connection a provider opened itself (a client passed in stays open). Call it when you replace the provider, for example after the person changes the model settings.
- Failures are `LlmError` with `status`, `kind`, `retryable`, `retryAfter`, `contextOverflow` and `toolsUnsupported`. Retryable means 408, 429, 5xx, dropped connections and timeouts; malformed replies and certificate errors are not retried.
- `kind` says why it failed, so a chat can say what to do next: `connection`, `timeout`, `auth` (401, 403), `notFound` (404), `rateLimit` (429), `server` (5xx), `request` (other 4xx), `badReply` (a reply that cannot be read or stops part way) or `other`.
- When the server sends no bytes for `llmIdleTimeout` (120 seconds), the request is aborted with a retryable `timeout` error. The wait restarts with every chunk, so a streaming model that is thinking keeps it alive. With streaming off the whole reply comes at the end, so a reply that takes longer fails. Pass `idleTimeout:` to a provider to change it. The agent loop does not retry a timeout on its own (it already waited that long); the error is retryable, so the chat offers Retry.
- Claude replies carry thinking blocks that the next tool round must send back unchanged. `AnthropicProvider` returns them in `LlmDone.content`, the session stores them with the message, and the provider sends them back within the run.
- No API key goes into the app's code or assets; the `no_secret_literals` lint and the doctor's `bundled-secrets` check enforce it. Choose one of:
  - a model on the device or on the local network (no key);
  - your own proxy server that holds the key;
  - a key the person enters, kept in secure storage (not on web).

## Testing

`ScriptedProvider` from `package:flutter_agentify_core/testing.dart` replies with scripted steps (`text`, `toolCalls`, `error`, `hang`) records every request, and notes whether `close()` was called.
