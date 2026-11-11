import '../llm/llm_provider.dart';
import '../llm/llm_types.dart';

/// A model that runs inside the app, as the developer picks it.
class OnDeviceModelSpec {
  const OnDeviceModelSpec({
    required this.id,
    required this.label,
    required this.url,
    this.webUrl,
    required this.sizeBytes,
    this.webSizeBytes,
    required this.minRamBytes,
    required this.config,
  });

  /// A stable name for the model, such as a file name.
  final String id;

  /// Shown to people, such as "Gemma 4 E2B".
  final String label;

  /// Download address for native platforms, pinned to one revision.
  final String url;

  /// Download address on the web; null when the model has no web build.
  final String? webUrl;

  final int sizeBytes;
  final int? webSizeBytes;

  /// Devices that report less memory than this cannot run the model.
  final int minRamBytes;

  final ModelConfig config;
}

/// Why a device cannot run the in-app model.
enum UnsupportedReason {
  platform,
  osVersion,
  noWebGpu,
  notEnoughMemory,
  webDisabled,
}

/// What went wrong last time.
enum OnDeviceFailure { download, load, memory, other }

/// Where the in-app model is in its life: on disk, in memory, or neither.
sealed class OnDeviceModelState {
  const OnDeviceModelState();
}

final class ModelUnsupported extends OnDeviceModelState {
  const ModelUnsupported(this.reason);
  final UnsupportedReason reason;
}

final class ModelNotDownloaded extends OnDeviceModelState {
  const ModelNotDownloaded();
}

final class ModelDownloading extends OnDeviceModelState {
  const ModelDownloading(this.received, this.total);
  final int received;
  final int total;

  /// 0 to 100; 0 while the total is unknown.
  int get percent => total <= 0 ? 0 : (received * 100 ~/ total).clamp(0, 100);
}

/// On disk, not in memory.
final class ModelDownloaded extends OnDeviceModelState {
  const ModelDownloaded();
}

final class ModelLoading extends OnDeviceModelState {
  const ModelLoading();
}

final class ModelReady extends OnDeviceModelState {
  const ModelReady(this.provider);
  final LlmProvider provider;
}

final class ModelFailed extends OnDeviceModelState {
  const ModelFailed(this.kind, [this.reason]);
  final OnDeviceFailure kind;

  /// The engine's message, for logs; not shown to people as is.
  final String? reason;
}
