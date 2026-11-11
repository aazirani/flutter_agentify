import 'on_device_model.dart';

/// Where the assistant's model runs.
enum ModelMode {
  /// Only the in-app model.
  onDevice,

  /// Only a model server.
  server,

  /// The in-app model when it is ready, otherwise the server.
  both,
}

/// Which model answers the next message.
enum AnsweredBy { device, server, none }

/// The model that runs inside the app, and how it is offered.
class OnDeviceSetup {
  const OnDeviceSetup({
    required this.model,
    this.askBeforeDownload = true,
    this.enableOnWeb = false,
  });

  /// Which model to download and run.
  final OnDeviceModelSpec model;

  /// Show a card with the size before downloading; false starts at first launch.
  final bool askBeforeDownload;

  /// The web engine is a preview; off unless the developer turns it on.
  final bool enableOnWeb;
}

/// The model server the assistant starts with.
class ServerSetup {
  const ServerSetup({
    this.presetId = 'ollama',
    this.baseUrl = 'http://localhost:11434/v1',
    this.model = '',
    this.userEditable = true,
  });

  /// The provider preset, such as `ollama` or `anthropic`.
  final String presetId;

  /// The server's address.
  final String baseUrl;

  /// The model name; empty until the person picks one in Settings.
  final String model;

  /// False: no server section in Settings and no actions that change it, so
  /// these values are final.
  final bool userEditable;
}

/// Everything the app decides about its models, in one value.
class AssistantSetup {
  const AssistantSetup({
    required this.mode,
    this.onDevice,
    this.server = const ServerSetup(),
  });

  /// Where the model runs.
  final ModelMode mode;

  /// The in-app model; null when [mode] is [ModelMode.server].
  final OnDeviceSetup? onDevice;
  final ServerSetup server;

  bool get usesDevice => mode != ModelMode.server && onDevice != null;
  bool get usesServer => mode != ModelMode.onDevice;
}

/// Empty when the setup is consistent; otherwise one sentence per problem.
List<String> setupProblems(
  AssistantSetup setup, {
  required bool Function(String presetId) presetNeedsKey,
}) {
  final server = setup.server;
  return [
    if (setup.mode != ModelMode.server && setup.onDevice == null)
      'Mode ${setup.mode.name} needs an on-device model in `onDevice:`.',
    if (setup.usesServer && !server.userEditable && server.model.isEmpty)
      'A server people cannot edit needs `model:` set.',
    if (setup.usesServer &&
        !server.userEditable &&
        presetNeedsKey(server.presetId))
      'A server people cannot edit needs a preset that asks for no key; '
          '"${server.presetId}" needs one.',
  ];
}
