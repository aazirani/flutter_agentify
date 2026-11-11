# Choose where the model runs

The assistant's model can run on a model server, inside the app, or both. You choose once, in one file: `lib/ai/assistant_setup.dart`. Everything else follows from it: the Settings screen, which actions are registered, and what the chat shows.

| Mode | Who answers | Platform floors |
|---|---|---|
| `ModelMode.server` | A model server: Ollama, LM Studio, a hosted API or your own proxy. | The template's (no change). |
| `ModelMode.both` | The model inside the app once it is downloaded and loaded; the server until then, or while the person has chosen the server in Settings. | Raised, see [Which devices can run it](#which-devices-can-run-it). |
| `ModelMode.onDevice` | Only the model inside the app. No server, no key. | Raised. |

The model inside the app is Gemma 4 E2B (Apache-2.0), run by Google's LiteRT-LM through [flutter_edge_ai](https://pub.dev/packages/flutter_edge_ai). It is about 2.6 GB (about 2 GB on web), needs no Hugging Face token, and its download address is pinned to one revision. It is not bundled: the app downloads it after asking.

## Choose at setup

`dart tool/setup.dart` takes `--model server|both|on-device`. The default is `server`, so a new project has no engine and no raised floors:

```bash
dart tool/setup.dart --name notes_app --org com.acme --starter empty --model both
```

Setup prints the floors it applies. With `both` it also says that no model server is set yet, so the assistant uses only the in-app model until you set one.

## The setup file

Paste the one you want into `lib/ai/assistant_setup.dart`.

### Server only

```dart
import 'package:flutter_agentify_core/flutter_agentify_core.dart';

const assistantSetup = AssistantSetup(
  mode: ModelMode.server,
  server: ServerSetup(),
);
```

`ServerSetup()` starts the Settings screen at Ollama on `http://localhost:11434/v1` with no model. Give it your own values to ship pointing at your server:

```dart
  server: ServerSetup(
    presetId: 'custom',
    baseUrl: 'https://ai.example.com/v1',
    model: '<model>',
  ),
```

### Both

```dart
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_on_device/flutter_agentify_on_device.dart';

const assistantSetup = AssistantSetup(
  mode: ModelMode.both,
  onDevice: OnDeviceSetup(model: gemma4E2b),
  server: ServerSetup(),
);
```

### On the device only

```dart
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_on_device/flutter_agentify_on_device.dart';

const assistantSetup = AssistantSetup(
  mode: ModelMode.onDevice,
  onDevice: OnDeviceSetup(model: gemma4E2b),
);
```

`OnDeviceSetup` has two more switches:

- `askBeforeDownload` (default `true`): the chat shows a card with the download size before anything is downloaded. With `false`, the download starts the first time the assistant opens.
- `enableOnWeb` (default `false`): see [Web](#web).

The gate checks the file: `test/ai/assistant_setup_test.dart` fails when a mode has no model it can use.

## Stop people changing the server model

```dart
  server: ServerSetup(
    presetId: 'custom',
    baseUrl: 'https://ai.example.com/v1',
    model: '<model>',
    userEditable: false,
  ),
```

With `userEditable: false`:

- Settings has no Model server block.
- `set_assistant_provider` and `set_api_key` are not registered, so neither the person nor the assistant can change the server.
- Saved settings are ignored; the values in this file are final.

Such a server needs `model` set and a preset that does not require a key (`custom`, `ollama` or `lm_studio`), since nobody can type one. The gate's setup test fails otherwise. To keep a key off the device, point it at your own proxy; see [Ship without user keys](ship-without-user-keys.md).

## What the person sees

- **The header's second line** names the model: "Gemma 4 E2B · On this device", or the server's preset and model, such as "Ollama · llama3.2".
- **The download card**, when the model is not downloaded: what it is, its size, a Wi-Fi hint, **Download** and **Not now**. In `onDevice` mode, or `both` without a server, the card stays and replaces the input, since nothing else can answer. In `both` with a server, **Not now** is remembered and the card does not come back; Download stays in the chat's menu.
- **Progress:** "Downloading… 958 MB of 2.6 GB" with a bar and Cancel, then "Getting ready…" while the model loads.
- **The chat's menu** (the chip icon) has Download with its size, or Delete model to free the space. In `both` with a server set up, once the model is downloaded, it also has an entry to switch between the device and the server. Deleting asks first.
- **Settings > Assistant** shows, in `both`, an **Answers with** choice: This device or Model server. The default is This device, so the in-app model answers once it is ready. With Model server, the server answers and the model is not loaded into memory. The choice is greyed out until a server is set up, since nothing else could answer, and hidden when the device cannot run the model. The assistant can change it too, with `set_use_on_device_model`.
- **Settings > Assistant, "Model on this device"** shows the model's name, its size and its state. While it downloads, a progress bar shows "958 MB of 2.6 GB". The buttons are Download, Cancel, Retry and Delete. Download and Delete ask for confirmation in a dialog that names the model and its size.
- **Settings > Assistant, "Model server"** (preset, address, model, API key) shows only when the app uses a server: in `server` and `both`, not in `onDevice`.
- **When no model can answer**, the chat says "Not ready yet" instead of "How can I help?". If the device cannot run the model and a server can be set up, it offers **Open settings**.
- **States** the device cannot get past say so: the device cannot run the model, there is not enough memory, the download failed (Retry), or the model did not start or did not fit in memory last time (Retry, Delete model). This is the same in the chat and in Settings.

The model loads the first time the assistant opens, not at app start.

## Why `both` prefers the device

`both` promises that messages stay on the device whenever they can. So once the in-app model is ready, the next message uses it, even if the server's model is stronger, unless the person chose the server in Settings. A reply that is running finishes on the model it started with; the switch happens between messages, in the same conversation, with one line in the thread: "Now answered on this device".

The other way is guarded. When a conversation has turns answered on the device and the next message would go to the server (the model was deleted, failed to load, or the person chose the server), the chat asks first: **Continue with \<server\>** sends the whole conversation from then on; **Start a new chat** leaves it on the device and sends the message in a new one. Nothing is sent before the choice. The app remembers which conversations have such turns, across restarts.

With "Answers with" set to Model server, the server answers every message; the in-app model does not step in when the server cannot be reached.

## When the model does not fit in memory

On a phone, running out of memory while loading ends the app; there is no error to catch. So the app saves a mark before it loads the model and clears it after. If the mark is still there at the next launch, the model shows "did not fit in memory last time" and is not loaded again by itself. Retry tries once more; Delete model frees the space. A device that reports less memory than the model needs (5 GiB for Gemma 4 E2B, so phones sold with 6 GB pass) gets "Not enough memory" before any download.

## Which devices can run it

| Platform | Floor |
|---|---|
| Android | Android 11 (API 30), arm64. Other processors install the app and report that the device cannot run the model. |
| iOS | iOS 15, with the increased memory limit entitlement. |
| macOS | macOS 14 on Apple Silicon. |
| Windows | x64. |
| Linux | x64 or arm64, glibc 2.34 or newer; a Vulkan driver for the GPU, else the processor. |
| Web | Experimental; see below. |

Which of these have been measured is under [Measured](#measured). A platform without a row there has not been tried.

### Web

The engine's web runtime is a preview, and the model is about 2 GB in the browser's storage (the web build's size, which the UI shows there). The in-app model is off on web unless you set `enableOnWeb: true`; with it off, `both` uses the server and hides the on-device settings and menu entries, and in `onDevice` the chat says this device cannot run the model while Settings says the app does not run it on the web. It needs a browser with WebGPU.

### Builds

- The first build of a project with the in-app model needs the network: the engine downloads its native libraries at build time.
- macOS debug builds are signed to run locally (ad hoc), because an unsigned app cannot load the engine. This turns the app sandbox on in debug builds, which moves the app's data folder. The saved API key still works. This holds in every mode.

## Measure it on your device

```bash
tool/measure_on_device.sh -d macos
tool/measure_on_device.sh -d macos --cpu
```

It downloads the model if needed, sends ten fixed requests against the app's actions in one conversation, checks what each one changed, and prints one Markdown row: correct answers, time to the first token, peak memory. On an emulator or a simulator the row says "works; speed not representative". `flutter test` uninstalls the app after each run on a phone, so every run downloads the model again. The requests use the item example, so in a project made with `--starter empty` the test is in `.agents/example/integration_test/`.

### Measured

Ten fixed requests against the example app's actions, in one conversation, each checked against what it must change.

| Device | OS | Backend | Correct | First token, median (user / tool step) | First token, worst | Peak memory | Date | Versions |
|---|---|---|---|---|---|---|---|---|
| MacBook Air (Apple M4, 24 GB) | macOS 26.5.2 | GPU | 10/10 | 0.44 s / 0.16 s | 2.69 s | 1.1 GB | 2026-11-11 | flutter_edge_ai 2.6.0, flutter_edge_ai_litertlm 1.20.0, Gemma 4 E2B b3ca0d2f |
| MacBook Air (Apple M4, 24 GB) | macOS 26.5.2 | CPU | 10/10 | 0.92 s / 0.24 s | 3.47 s | 4.0 GB | 2026-11-11 | flutter_edge_ai 2.6.0, flutter_edge_ai_litertlm 1.20.0, Gemma 4 E2B b3ca0d2f |
| iPhone 13 Pro Max (A15 Bionic, 6 GB) | iOS 26.6.2 | GPU | 10/10 | 1.00 s / 0.37 s | 6.74 s | 1.4 GB | 2026-11-11 | flutter_edge_ai 2.6.0, flutter_edge_ai_litertlm 1.20.0, Gemma 4 E2B b3ca0d2f |
| iPhone 13 Pro Max (A15 Bionic, 6 GB) | iOS 26.6.2 | CPU | 10/10 | 1.80 s / 0.81 s | 12.24 s | 2.4 GB | 2026-11-11 | flutter_edge_ai 2.6.0, flutter_edge_ai_litertlm 1.20.0, Gemma 4 E2B b3ca0d2f |
| Redmi A5 (Unisoc T7250, 3 GB) | Android 15 | GPU | cannot run: the system ends the app while the model loads (out of memory) | | | | 2026-11-11 | flutter_edge_ai 2.6.0, flutter_edge_ai_litertlm 1.20.0, Gemma 4 E2B b3ca0d2f |
| Redmi A5 (Unisoc T7250, 3 GB) | Android 15 | CPU | 10/10 | 13.75 s / 7.76 s | 132.06 s | 1.6 GB | 2026-11-11 | flutter_edge_ai 2.6.0, flutter_edge_ai_litertlm 1.20.0, Gemma 4 E2B b3ca0d2f |

The Redmi A5 reports 2.9 GB, under the 5 GiB the app asks for, so the app shows "Not enough memory" there; the measurement skips that check. On its GPU, Android's low-memory killer ended the app twice while the model loaded; on its processor it worked, but slowly.

## Add the in-app model later

Setup removes the in-app model's code from a `server` project, so adding it means putting that code back. The reliable way is to set up a second copy of the same framework commit with `--model both` (same name, org and starter) and compare:

```bash
git diff --no-index --stat ../notes_app ../notes_app_both
```

Bring these across, then run `flutter pub get`, `dart run build_runner build`, `dart run tool/action.dart --write-reference` and `tool/check.sh`:

1. `packages/flutter_agentify_on_device/`, the whole folder.
2. `pubspec.yaml`: the `flutter_agentify_on_device` path dependency and the `integration_test` dev dependency.
3. `lib/ai/assistant_setup.dart`: the import, the `onDevice:` line and the mode.
4. The in-app model's code in `lib/`: `lib/ai/on_device_model.dart` (the engine, the model and its state) and `lib/data/repositories/prefs_load_marker.dart`; the lines that use them in `lib/ai/model_route.dart` and `lib/ai/assistant_providers.dart` (the device session, opening and downloading); the five actions (`download_on_device_model`, `cancel_on_device_model_download`, `delete_on_device_model`, `dismiss_on_device_offer`, `set_use_on_device_model`) in `lib/domain/actions/settings_actions.dart` and `app_actions.dart`, their wiring in `lib/domain/di/domain_layer_injection.dart` and `lib/di/service_locator.dart`, the "Not now" and "Answers with" settings in the settings repositories, the chat's model status in `lib/presentation/assistant/assistant_shell.dart` and `assistant_toggle_button.dart`, `lib/presentation/settings/on_device_model_tile.dart` and its row in `settings_screen.dart`, and the small additions in `change_event_adapter.dart`, `assistant_settings_provider.dart` and `action_failure_message.dart`.
5. The tests: `test/actions/` for the five actions, `test/ai/assistant_model_switch_test.dart`, `test/ai/on_device_route_test.dart`, `test/support/on_device_fixture.dart`, and the in-app parts of `test/presentation/settings/settings_follow_setup_test.dart`, `test/support/actions_harness.dart` and `test/support/test_app.dart`.
6. The measuring tool: `integration_test/on_device_measure_test.dart` and `tool/measure_on_device.sh`.
7. The platform floors:
   - Android: `minSdk = 30` in `android/app/build.gradle.kts` (instead of `flutter.minSdkVersion`).
   - iOS: `ios/Runner/Runner.entitlements` and a `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;` line in each of the Runner target's three configurations in `ios/Runner.xcodeproj/project.pbxproj`.
   - macOS: `MACOSX_DEPLOYMENT_TARGET = 14.0;` (instead of `12.0`) in `macos/Runner.xcodeproj/project.pbxproj`.
   - Web: `web/cache_api.js`, `web/opfs_helper.js`, and their script tags with the `litertLmReady` module script in `web/index.html`.

## Remove it

The same list, the other way:

1. Set `mode: ModelMode.server` and remove the `onDevice:` line and the import in `lib/ai/assistant_setup.dart`.
2. Delete `packages/flutter_agentify_on_device/`, the dependency and `integration_test` in `pubspec.yaml`, `lib/ai/on_device_model.dart`, `lib/data/repositories/prefs_load_marker.dart`, `lib/presentation/settings/on_device_model_tile.dart`, the five action tests (`test/actions/*_on_device_*` and `dismiss_on_device_offer_test.dart`), `test/ai/assistant_model_switch_test.dart`, `test/ai/on_device_route_test.dart`, `test/support/on_device_fixture.dart`, `integration_test/on_device_measure_test.dart` and `tool/measure_on_device.sh`.
3. Remove the in-app code from the files in step 4 of the list above. `dart analyze` names every line that still uses it.
4. Put the floors back: `minSdk = flutter.minSdkVersion`, `MACOSX_DEPLOYMENT_TARGET = 12.0;`, no `Runner.entitlements` and no `CODE_SIGN_ENTITLEMENTS` lines for it, no web helper files or script tags. The macOS debug signing stays.
5. Run `flutter pub get`, `dart run build_runner build`, `dart run tool/action.dart --write-reference` and `tool/check.sh`.

The template's own check sets up each starter with `server` and with `both`, and the example with `on-device`, so every direction stays buildable.
