# flutter_agentify_ui

Flutter: the chat widget and its controller, approval cards, receipt chips and a debug inspector.

## Use

```dart
import 'package:flutter_agentify_ui/flutter_agentify_ui.dart';

// AssistantController(session: session, threads: threads, onDevice: false)
AssistantChat(controller: controller)
```

`AssistantChat` also takes `strings`, `inspect`, `onOpenSettings`, `onClose` and `modelStatus`. A `ModelStatus` shows which model answers (for example "Gemma 4 E2B · On this device" or "Ollama · llama3.2") and, for the model inside the app, its download state. `formatModelSize` turns a byte count into text such as "2.6 GB".

See `lib/presentation/assistant/assistant_shell.dart` in the app for a full example.

This package is used by path and is not on pub.dev.
