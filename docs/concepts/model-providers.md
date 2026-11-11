# Model providers

A provider is the connection to a model. The app does not host a model. The person, or you, choose one in the app's settings.

## Local and hosted

- **Local.** A model server on the same computer or the local network, such as Ollama. It needs no key.
- **Hosted.** A model behind a paid API, such as OpenAI's. It needs a key.
- **Your own server.** A proxy that holds the key and passes requests on. The app sends no key.
- **Inside the app.** A model the app downloads and runs itself, with no server and no key. It answers alone, or first with a server as the fallback. See [Choose where the model runs](../guides/choose-where-the-model-runs.md).

A **preset** is a ready-made setting for one of these: a base URL, defaults for the model, and whether a key is needed. The core package lists the presets.

## Why

Different apps need different models. A local model keeps data on your network and costs nothing; a model inside the app keeps it on the device and works offline, but is smaller and needs a recent device. A hosted model is stronger. A proxy lets you ship an app without asking people for a key.

## Answer-only mode

Some models cannot call tools. For such a model the assistant gets no tools. It answers from the `<current-screen>` block alone and cannot change data.

## Where keys live

A key never goes into code, assets or tests. A key the person enters is kept in secure storage, apart from the other settings. The settings themselves hold only the choice of model, from [`lib/domain/entities/assistant_settings.dart`](../../lib/domain/entities/assistant_settings.dart). Before anything is saved they start from the `server` in `lib/ai/assistant_setup.dart`. Its defaults are Ollama on this computer with no model chosen:

```dart
const assistantSetup = AssistantSetup(
  mode: ModelMode.server,
  server: ServerSetup(),
);
```

`ServerSetup()` defaults to preset `ollama`, base URL `http://localhost:11434/v1` and no model. A project set up with `--model both` or `--model on-device` also has an `onDevice:` line and a different `mode`.

`mode` is `ModelMode.server`, `ModelMode.onDevice` or `ModelMode.both`. The settings screen shows the server form only when the app uses a server and `ServerSetup.userEditable` is true. With `both`, an "Answers with" choice (This device or Model server) picks which one answers.

The app also refuses to send a key over plain `http://` to a host that is not local.

## Reference

- [Model providers](../../packages/flutter_agentify_core/doc/model-providers.md): the providers, the presets and what each one needs.
- [Connect a model](../guides/connect-a-model.md): how to set one up, step by step.
