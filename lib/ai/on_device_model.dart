import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_agentify/ai/model_route.dart';
import 'package:flutter_agentify/data/repositories/prefs_load_marker.dart';
import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_on_device/flutter_agentify_on_device.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'on_device_model.g.dart';

/// The engine for the model inside the app; tests swap in a fake.
@Riverpod(keepAlive: true)
OnDeviceEngine onDeviceEngine(Ref ref) => EdgeAiEngine();

@Riverpod(keepAlive: true)
LoadMarker loadMarker(Ref ref) =>
    PrefsLoadMarker(ServiceLocator.getIt<SharedPreferences>());

/// An engine for a platform the setup turned the in-app model off on.
class _Off implements OnDeviceEngine {
  const _Off(this.reason);

  final UnsupportedReason reason;

  @override
  Future<DeviceSupport> support(OnDeviceModelSpec spec) async =>
      DeviceSupport(unsupported: reason);

  @override
  Never noSuchMethod(Invocation invocation) =>
      throw StateError('The in-app model is off here.');
}

/// What downloading [spec] takes here: the web build on the web.
int onDeviceDownloadBytes(OnDeviceModelSpec spec) =>
    kIsWeb ? spec.webSizeBytes ?? spec.sizeBytes : spec.sizeBytes;

/// [engine], or one that reports `webDisabled` when the setup leaves the
/// in-app model off on the web.
OnDeviceEngine engineFor(
  OnDeviceEngine engine,
  OnDeviceSetup setup, {
  required bool web,
}) => web && !setup.enableOnWeb
    ? const _Off(UnsupportedReason.webDisabled)
    : engine;

/// The in-app model; null when the setup has none. Started (support, load
/// marker, disk) at once, but loaded only when the assistant opens.
@Riverpod(keepAlive: true)
OnDeviceModelController? onDeviceModel(Ref ref) {
  final setup = ref.watch(activeSetupProvider);
  final device = setup.onDevice;
  if (!setup.usesDevice || device == null) return null;
  final controller = OnDeviceModelController(
    engine: engineFor(ref.watch(onDeviceEngineProvider), device, web: kIsWeb),
    spec: device.model,
    marker: ref.watch(loadMarkerProvider),
  );
  ref.onDispose(controller.dispose);
  unawaited(controller.start());
  return controller;
}

/// The in-app model's state; null when the setup has none.
@Riverpod(keepAlive: true)
class OnDeviceModelStateNotifier extends _$OnDeviceModelStateNotifier {
  @override
  OnDeviceModelState? build() {
    final controller = ref.watch(onDeviceModelProvider);
    if (controller == null) return null;
    final subscription = controller.states.listen((s) => state = s);
    ref.onDispose(subscription.cancel);
    return controller.state;
  }
}

/// Whatever the in-app model has loaded at the time of each request, so a
/// session never holds a model that was unloaded and loaded again.
class LoadedOnDeviceModel implements LlmProvider {
  LoadedOnDeviceModel(this._model);

  final OnDeviceModelController _model;

  @override
  Stream<LlmEvent> stream({
    required String system,
    required List<ChatMessage> messages,
    List<ToolSpec> tools = const [],
    required ModelConfig config,
    CancelToken? cancel,
  }) => switch (_model.state) {
    ModelReady(:final provider) => provider.stream(
      system: system,
      messages: messages,
      tools: tools,
      config: config,
      cancel: cancel,
    ),
    _ => Stream.error(
      const LlmError(
        'The model on this device is not loaded.',
        kind: LlmErrorKind.other,
        retryable: true,
      ),
    ),
  };

  // The loaded model outlives any one session: nothing to close here.
  @override
  void close() {}
}
