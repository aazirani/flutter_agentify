import 'package:flutter_agentify/ai/assistant_setup.dart';
// @on-device:begin
import 'package:flutter_agentify/ai/on_device_model.dart';
// @on-device:end
import 'package:flutter_agentify/presentation/providers/assistant_settings_provider.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'model_route.g.dart';

/// The route for [mode]: `both` prefers the device once its model is ready,
/// unless the person turned it off ([useDevice]) and a server is set up.
AnsweredBy routeFor(
  ModelMode mode, {
  required bool deviceReady,
  required bool serverConfigured,
  bool useDevice = true,
}) {
  final server = serverConfigured ? AnsweredBy.server : AnsweredBy.none;
  return switch (mode) {
    ModelMode.server => server,
    ModelMode.onDevice => deviceReady ? AnsweredBy.device : AnsweredBy.none,
    ModelMode.both =>
      deviceReady && (useDevice || !serverConfigured)
          ? AnsweredBy.device
          : server,
  };
}

/// The app's [AssistantSetup]; tests swap in another.
@Riverpod(keepAlive: true)
AssistantSetup activeSetup(Ref ref) => assistantSetup;

/// Whether the chat is running a reply. The chat sets it; the route waits
/// for it so a reply finishes on the model it started with.
@Riverpod(keepAlive: true)
class ReplyRunning extends _$ReplyRunning {
  @override
  bool build() => false;

  void set(bool value) {
    if (ref.mounted) state = value;
  }
}

/// Which model answers the next message. Changes only while no reply runs.
@Riverpod(keepAlive: true)
class ModelRoute extends _$ModelRoute {
  @override
  AnsweredBy build() {
    final wanted = routeFor(
      ref.watch(activeSetupProvider).mode,
      deviceReady: _deviceReady,
      serverConfigured: ref.watch(assistantSettingsProvider).isConfigured,
      useDevice: _useDevice,
    );
    if (ref.watch(replyRunningProvider) case true) {
      if (stateOrNull case final held?) return held;
    }
    return wanted;
  }

  bool get _useDevice {
    // @on-device:begin
    if (!ref.watch(useOnDeviceModelProvider)) return false;
    // @on-device:end
    return true;
  }

  bool get _deviceReady {
    // @on-device:begin
    if (ref.watch(onDeviceModelStateProvider) is ModelReady) return true;
    // @on-device:end
    return false;
  }
}
