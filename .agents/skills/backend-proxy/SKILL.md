---
name: backend-proxy
description: What a proxy server in front of a model must do, and how to point the app's Custom preset at it. Use when an app must ship without the person supplying a key, or the app runs on web.
---

# Backend proxy

Don't load this for storing a key the person types; see `secrets`. For preset and model settings, see `model-providers`.

## Rule

If you ship the app without asking people for a key, the key lives on a server you run, and the app talks to that server through the `custom` preset. No automated check covers this skill: nothing in the gate tests a proxy.

## Why

A key inside the app can be extracted (`secrets`). Web cannot hold one at all, and browsers also block calls to servers that do not allow them (CORS). A proxy fixes both.

## How

The proxy must:

1. **Accept the OpenAI-compatible request** the app sends: `POST <baseUrl>/chat/completions` with `messages`, optional `tools`, and `stream: true`. `OpenAiCompatibleProvider` in `packages/flutter_agentify_core/lib/src/llm/` is the client; read it for the exact fields.
2. **Add the key on the server** and forward to the real model. With the `custom` preset the app sends an `authorization` header only if a key is saved for it; leave it empty and the proxy adds its own.
3. **Stream the reply** back as server-sent events, unbuffered, and end with `data: [DONE]`. A proxy that buffers makes the chat look frozen.
4. **Limit use per person**: sign-in or a per-device token, a request rate, and a cap on tokens. The app cannot do this for you.
5. **Send CORS headers** for the web origin (and answer `OPTIONS`), if the app runs on web.
6. **Pass errors through** with their real status (429, 5xx) so `LlmError.retryable` works.

Pointing the app at it: in Settings choose "Custom (OpenAI-compatible)", set the address to the proxy's `/v1` root and the model name to one the proxy accepts. Set `toolCalling` for that model in the advanced section (`lib/presentation/settings/assistant_settings_section.dart`). The key is optional for `custom`: leave it empty, or enter a token your proxy checks (not on web). Use `https://` for a proxy outside your network; the `custom` preset refuses `http://` to a non-local host, key or not (`SetAssistantProvider`).

To ship the app already pointing at the proxy, set its values in `lib/ai/assistant_setup.dart`: `ServerSetup(presetId: 'custom', baseUrl: ..., model: ...)`, with `userEditable: false` when the person must not change them. Never add a key there. The address is public, so protect the proxy itself with limits.

## Anti-patterns

- A proxy with no per-person limit: anyone who finds the address spends your money.
- Putting the real key in the app "just for the demo".
- Rewriting the request into another format in the app; keep the app speaking the one format and translate on the server.

## Verification

- No automated check. Test by hand with `curl -N` against the proxy, then in the app on a real device.
- For app-side behavior against a fake server, see the helpers in `packages/flutter_agentify_core/test/llm/fake_llm_server.dart`.

## Related skills
- `secrets` — why the key stays off the device
- `model-providers` — the Custom preset and web limits
- `permissions-and-platform` — cleartext and local-network settings for non-HTTPS addresses
