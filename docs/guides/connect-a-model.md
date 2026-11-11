# Connect a model

The assistant talks to a model you choose. Nothing is hosted for you. You set the model in the app's Settings, under Assistant, in the "Model server" block:

- **Provider:** a preset: Ollama, LM Studio, OpenAI, OpenRouter, Gemini, Anthropic (Claude) or Custom (OpenAI-compatible). A preset fills in the address and says whether a key is needed.
- **Server address:** the server's `/v1` root (Anthropic's is its own root).
- **Model:** the model's name on that server. A line under the field gives an example name.
- **API key:** only for servers that need one. A button shows or hides what you type.
- **Advanced:** whether the model can call tools, and its context window.

The block shows only when the app uses a model server. In a project that runs only a model inside the app (`ModelMode.onDevice`), it is not there.

A project can also run a model inside the app, with no server at all, or fix the server so people cannot change it. Both are set in `lib/ai/assistant_setup.dart`; see [Choose where the model runs](choose-where-the-model-runs.md).

The list of presets, with what each one needs, is in [Model providers](../../packages/flutter_agentify_core/doc/model-providers.md). [Model providers](../concepts/model-providers.md) explains the idea.

## A local server

A local server needs no key and keeps the data on your machine. With [Ollama](https://ollama.com), start it (open its app, or run `ollama serve` in a second terminal), then get a model:

```bash
ollama pull qwen3:8b
```

In Settings choose Ollama, keep the address `http://localhost:11434/v1`, type `qwen3:8b` as the model and save.

Not every model can call tools. If the chat says the model cannot use the app's actions, it is in answer-only mode: it answers from the screen but changes nothing. Pick a model that supports tool calling, or turn "Model can call tools" off under Advanced for that model.

## A hosted API

A hosted model is stronger but needs a key, for example OpenAI's. In Settings choose its preset, type the model name, paste your key and save.

The app keeps the key in the platform's secure storage, apart from the other settings. It never goes into code, assets or tests. Web stores no key at all, so the presets that need one are not offered there.

To ship an app that does not ask people for a key, see [Ship without user keys](ship-without-user-keys.md).

## A phone and a server on your computer

A phone or an emulator cannot reach your computer's `localhost`. Use the computer's address on your network instead.

1. Make the server listen on the network, not only on `localhost`. For Ollama, stop it first if it runs, so the port is free:

   ```bash
   OLLAMA_HOST=0.0.0.0 ollama serve
   ```

2. Find the computer's address. On macOS:

   ```bash
   ipconfig getifaddr en0
   ```

3. In the app on the phone, set the server address to that address, for example `http://192.168.1.20:11434/v1`. An Android emulator reaches the computer at `http://10.0.2.2:11434/v1`.

Plain `http://` to a local address is allowed on Android and iOS; [Platforms](platforms.md) lists the settings that allow it. With a key in use, the app refuses `http://` to a host that is not local.

## Web

In a browser the page can call a server only if the server allows it. This is called CORS. A local server must send CORS headers for the page's address. Ollama lets you name the addresses it accepts (stop Ollama first if it runs, so the port is free):

```bash
OLLAMA_ORIGINS="http://localhost:8080" ollama serve
flutter run -d chrome --web-port 8080
```

A hosted API usually does not allow calls from a browser, and web stores no key anyway. Put your own server in between: see [Ship without user keys](ship-without-user-keys.md).

A page served over `https://` cannot call an `http://` server.

## Check what the model received

In a debug build the chat has an inspector button. It shows the system text, the tools offered and the last calls. See [Customize the assistant](customize-the-assistant.md).

If the assistant cannot reach the model, see [Troubleshooting](troubleshooting.md#the-assistant-cannot-reach-the-model).
