---
name: model-providers
description: Which model servers the assistant can talk to, what a preset sets, and where a model's abilities are configured. Use when choosing, adding or debugging a model provider, a preset, tool calling, or "the assistant cannot reach the model".
---

# Model providers

Don't load this for keeping the API key safe; see `secrets`. For a server that holds the key, see `backend-proxy`.

## Rule

The app reaches a model only through an `LlmProvider` built by `buildProvider(presetId:, baseUrl:, apiKey:)` from `packages/flutter_agentify_core/lib/src/llm/provider_presets.dart`. What a model can do (`toolCalling`, `streaming`, `contextWindow`, `maxOutputTokens`) belongs to the `ModelConfig`, never to the provider. Enforced by the provider conformance tests in `packages/flutter_agentify_core/test/llm/conformance.dart`, run by `openai_compatible_provider_test.dart` and `anthropic_provider_test.dart` in the same folder.

## Why

One Ollama server can host a model with tool calling and one without. If abilities sat on the provider, the second model would be sent tools it cannot use. Every provider must also behave the same (stream text and tool calls, end with one `LlmDone`, report failures as `LlmError`), so the agent loop never needs to know which one it has.

## How

- Where the model runs is set in `lib/ai/assistant_setup.dart`: `ModelMode.server`, `ModelMode.onDevice` or `ModelMode.both`. `lib/ai/model_route.dart` picks who answers the next message (`AnsweredBy`); the route changes only between replies. `ServerSetup` holds the server's defaults; `userEditable: false` makes them final and leaves `set_assistant_provider` and `set_api_key` out of the registry. The Flutter Agentify guide *Choose where the model runs* explains the modes.
<!-- @on-device:begin -->
- The model inside the app is `packages/flutter_agentify_on_device` (only in projects set up with `--model both` or `on-device`): `EdgeAiEngine`, `OnDeviceProvider` and the `gemma4E2b` spec. Its lifecycle is `OnDeviceModelController` in core. Test with `FakeOnDeviceEngine` and `InMemoryLoadMarker` from `package:flutter_agentify_core/testing.dart`; never download the model in a test.
<!-- @on-device:end -->
- Presets: `ollama`, `lm_studio`, `openai`, `openrouter`, `gemini`, `anthropic`, `custom`. Everything except `anthropic` is an `OpenAiCompatibleProvider`; `custom` starts with an empty address. `keyUse` on each preset says whether it takes a key: `none` for `ollama` and `lm_studio`, `optional` for `custom`, `required` for the hosted ones. Each preset keeps its own key.
- Each preset carries `defaults`, a `ModelConfig`. `lib/ai/assistant_providers.dart` copies it with the saved model name, `toolCalling` and `contextWindow`. The settings form (`lib/presentation/settings/assistant_settings_section.dart`) stores only the values that differ from the preset.
- Small context windows: when the tool list would exceed `AgentConfig.toolSearchShare` (default 0.25) of the window, the session sends only the best matches plus a `tool_search` tool (`packages/flutter_agentify_core/doc/agent-loop.md`). Give an action `searchHints` so it is found.
- Answer-only mode: when the model has `toolCalling: false`, or the server answers that tools are unsupported, the session sends no tools and the chat shows `answerOnlyNotice`. Do not work around it; turn the switch off for that model.
- A phone cannot reach the computer's `localhost`. On a real device or emulator, the Ollama and LM Studio presets need the computer's address on the network (for example `http://192.168.1.20:11434/v1`), and the server must listen on that interface. Android emulators use `10.0.2.2` for the host machine. See `permissions-and-platform` for the cleartext and local-network settings this needs.
- Web: the browser enforces CORS. Use a server that sends CORS headers, or your own proxy (`backend-proxy`). No key is entered or stored on web, so the settings form leaves out the presets whose `keyUse` is `required`.
- Adding a provider means a class implementing `LlmProvider`, a row in the conformance run, and a preset. The full contract is in `packages/flutter_agentify_core/doc/model-providers.md`.

## Anti-patterns

- Hard-coding `toolCalling: true` for a provider instead of for a model.
- Putting a model name or key in source to "make the preset work".
- Treating a plain `LlmError` as final: check `retryable`, `contextOverflow` and `toolsUnsupported` first.
- Testing against a real server. Use `ScriptedProvider` from `package:flutter_agentify_core/testing.dart` (see `testing`).

## Verification

- `cd packages/flutter_agentify_core && dart test test/llm` runs the conformance tests and `provider_presets_test.dart`.
- `test/presentation/settings/assistant_settings_section_test.dart` covers the settings form.
- `test/ai/model_route_test.dart` and `test/ai/assistant_setup_test.dart` cover the modes and the setup file.
<!-- @on-device:begin -->
- `tool/measure_on_device.sh -d <device>` measures the in-app model on a real device.
<!-- @on-device:end -->
- `tool/check.sh` runs all of it (see `verify`).

## Related skills
- `secrets` — where the key lives
- `backend-proxy` — when the key must stay on a server
- `customizing-the-assistant` — instructions and chat text
- `testing` — scripting a model in tests
