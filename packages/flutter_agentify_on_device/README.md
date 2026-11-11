# flutter_agentify_on_device

Flutter: runs the assistant on a model inside the app, with no server and no key. It wraps [flutter_edge_ai](https://pub.dev/packages/flutter_edge_ai) 2.6.0 and `flutter_edge_ai_litertlm` 1.20.0 (Google's LiteRT-LM), pinned exactly, and is the only package that imports them.

A project gets this package when it is set up with `dart tool/setup.dart ... --model both` or `--model on-device`. The app uses it in one place, `lib/ai/assistant_setup.dart`:

```dart
const assistantSetup = AssistantSetup(
  mode: ModelMode.both,
  onDevice: OnDeviceSetup(model: gemma4E2b),
  server: ServerSetup(),
);
```

## What is in it

- `gemma4E2b`: Gemma 4 E2B (Apache-2.0, about 2.6 GB, no Hugging Face token), pinned to one revision, with an 8192-token context window.
- `EdgeAiEngine`: the `OnDeviceEngine` that checks the device, downloads, deletes and loads the model (GPU at float32; `useGpu: false` for the processor).
- `OnDeviceProvider`: the `LlmProvider` that keeps the engine's chat warm between steps and replays the history only when the request does not extend the last one. Gemma's chat template leaves out tool parameters named `description`, `type`, `properties`, `required` or `nullable`, so the provider sends them to the model as `<name>_value` and turns the model's calls back to the real names.
- `web/cache_api.js` and `web/opfs_helper.js`: the engine's web helpers. `tool/upgrade.dart` copies them into the app's `web/`.

The model's lifecycle (download, load guard, states) is `OnDeviceModelController` in `flutter_agentify_core`, so it is tested without the engine. See [Choose where the model runs](https://github.com/aazirani/flutter_agentify/blob/main/docs/guides/choose-where-the-model-runs.md).

This package is used by path and is not on pub.dev.
