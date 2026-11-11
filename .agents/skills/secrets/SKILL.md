---
name: secrets
description: How API keys are handled in a shipped app, the three allowed patterns and the places a key must never appear. Use when adding anything that needs a key, token or password, or when a secret check fails.
---

# Secrets

Don't load this for choosing a model server; see `model-providers`.

## Rule

No key in source, assets, tests or anything sent to the model. A shipped app uses one of three patterns:

1. **On the device or local network:** a model that needs no key (Ollama, LM Studio).
2. **Your own proxy:** a server holds the key; the app only knows the proxy's address (`backend-proxy`).
3. **A key the person types:** saved in secure storage, one per preset, never on web.

Enforced by the `no_secret_literals` lint (app source, run by `dart analyze --fatal-infos`) and the doctor's `bundled-secrets` check (assets listed in `pubspec.yaml`, and the Dart source under `packages/`).

## Why

An app bundle can be unpacked, so a key inside it is public. A key in model input can be repeated back by the model, stored in a thread, or logged.

## How

- The key's only home is `SecretStore` (`lib/domain/repositories/secret_store.dart`), implemented by `SecureSecretStore` in `lib/data/repositories/secure_secret_store.dart` (Keychain, Keystore and desktop equivalents). It keeps one key per preset (`getApiKey(presetId)`), so a key typed for one server is never sent to another. Tests use `lib/data/repositories/in_memory_secret_store.dart`.
- The key is written by the `set_api_key` action in `lib/domain/actions/settings_actions.dart`, which is not an agent tool (`agentTool => false`): the assistant cannot read or set it.
- `set_assistant_provider` refuses an `http://` address to a host outside the local network when the preset takes a key (`keyUse` is not `none`); `http://` is only for local hosts (`isLocalHost` in `lib/domain/entities/assistant_settings.dart`). Use `https://` for everything else.
- The settings form (`lib/presentation/settings/assistant_settings_section.dart`) hides the key field on web and when the preset takes no key (`KeyUse.none`), uses `obscureText`, and shows only "key saved", never the value.
- The lint and the doctor match the shapes in `secret_patterns.dart` (core and lints each keep a copy): `sk-`, Google, GitHub, Slack, AWS, Stripe, Groq, Hugging Face and xAI keys, JWTs, `Bearer` tokens and private-key headers.
- The registry redacts key-shaped text from action output; do not rely on it, just never return a key.
- The macOS keychain note in `SecureSecretStore` (login keychain, because debug builds are unsigned) is deliberate; leave it.
- Build-time values (`--dart-define`) are compiled into the app, so they are not a hiding place.
- If the lint or check fires on a test string that only looks like a key, change the string. Use `// ignore: flutter_agentify_lints/no_secret_literals` only with a reason; the doctor's ratchet counts ignores and the number may only go down.

## Anti-patterns

- A `.env` file, or a key, in `assets/` (the doctor fails on both).
- A key in a prompt, a screen summary (`lib/ai/screen_contexts.dart`), a receipt or a log line.
- Storing the key in shared preferences instead of `SecretStore`.
- Adding a web field for the key "just for testing".

## Verification

- `dart analyze --fatal-infos` for the lint; `dart run flutter_agentify_core:doctor --only bundled-secrets` for assets.
- `test/actions/set_api_key_test.dart` covers the action.
- `tool/check.sh` runs both (see `verify`).

## Related skills
- `backend-proxy` — pattern 2 in detail
- `model-providers` — which presets need a key
- `approval-and-safety` — what the assistant may not do
