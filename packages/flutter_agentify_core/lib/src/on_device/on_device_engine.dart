import '../llm/llm_provider.dart';
import 'on_device_model.dart';

/// What the device can do, as far as the engine and the platform can tell.
class DeviceSupport {
  const DeviceSupport({this.unsupported, this.ramBytes});

  /// Set when the engine cannot run here at all.
  final UnsupportedReason? unsupported;

  /// Total memory; null when the platform does not say.
  final int? ramBytes;
}

/// The runtime that downloads, loads and runs an in-app model. The app's
/// on-device package implements it; tests use `FakeOnDeviceEngine`.
abstract class OnDeviceEngine {
  Future<DeviceSupport> support(OnDeviceModelSpec spec);

  Future<bool> isInstalled(OnDeviceModelSpec spec);

  /// Emits (received, total); ends when installed; errors on failure.
  /// Cancelling the subscription cancels the download and removes partial data.
  Stream<(int, int)> download(OnDeviceModelSpec spec);

  Future<void> delete(OnDeviceModelSpec spec);

  /// Loads the model into memory. On a phone, running out of memory here
  /// ends the process instead of throwing.
  Future<LlmProvider> load(OnDeviceModelSpec spec);

  Future<void> unload();
}

/// Persists one boolean across launches (the app backs it with
/// shared_preferences).
abstract class LoadMarker {
  Future<bool> isSet();

  Future<void> set(bool value);
}
