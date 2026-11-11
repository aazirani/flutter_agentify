import 'dart:async';

import '../llm/llm_provider.dart';
import '../on_device/on_device_engine.dart';
import '../on_device/on_device_model.dart';
import 'scripted_provider.dart';

/// An [OnDeviceEngine] with no engine: support, progress and failures are
/// set on its fields; it counts the calls it gets.
class FakeOnDeviceEngine implements OnDeviceEngine {
  FakeOnDeviceEngine({LlmProvider? provider})
    : provider = provider ?? ScriptedProvider(const []);

  /// What [load] returns.
  LlmProvider provider;
  DeviceSupport deviceSupport = const DeviceSupport();
  bool installed = false;

  /// When set, [support] throws it.
  Object? supportError;

  /// What [download] emits, in order.
  List<(int, int)> progress = const [(100, 100)];

  /// When set, [download] fails with it after [progress].
  Object? downloadError;

  /// When set, [download] waits for it after [progress] before it ends.
  Completer<void>? downloadGate;

  /// When set, [load] throws it.
  Object? loadError;

  /// When set, [load] waits for it.
  Completer<void>? loadGate;

  /// When set, [delete] waits for it before it removes the model.
  Completer<void>? deleteGate;

  /// Runs at the start of [load].
  Future<void> Function()? onLoad;

  var downloadCalls = 0;
  var loadCalls = 0;
  var unloadCalls = 0;
  var deleteCalls = 0;
  var downloadCancelled = false;

  @override
  Future<DeviceSupport> support(OnDeviceModelSpec spec) async {
    if (supportError case final error?) throw error;
    return deviceSupport;
  }

  @override
  Future<bool> isInstalled(OnDeviceModelSpec spec) async => installed;

  @override
  Stream<(int, int)> download(OnDeviceModelSpec spec) {
    downloadCalls++;
    var cancelled = false;
    late final StreamController<(int, int)> controller;
    controller = StreamController(
      onListen: () async {
        for (final step in progress) {
          controller.add(step);
        }
        if (downloadGate case final gate?) await gate.future;
        if (cancelled) return;
        if (downloadError case final error?) {
          controller.addError(error);
        } else {
          installed = true;
        }
        await controller.close();
      },
      onCancel: () {
        cancelled = downloadCancelled = true;
        if (downloadGate case final gate? when !gate.isCompleted) {
          gate.complete();
        }
      },
    );
    return controller.stream;
  }

  @override
  Future<void> delete(OnDeviceModelSpec spec) async {
    deleteCalls++;
    await deleteGate?.future;
    installed = false;
  }

  @override
  Future<LlmProvider> load(OnDeviceModelSpec spec) async {
    loadCalls++;
    await onLoad?.call();
    if (loadGate case final gate?) await gate.future;
    if (loadError case final error?) throw error;
    return provider;
  }

  @override
  Future<void> unload() async => unloadCalls++;
}

/// A [LoadMarker] kept in memory.
class InMemoryLoadMarker implements LoadMarker {
  InMemoryLoadMarker([this.value = false]);

  bool value;

  @override
  Future<bool> isSet() async => value;

  @override
  Future<void> set(bool value) async => this.value = value;
}
