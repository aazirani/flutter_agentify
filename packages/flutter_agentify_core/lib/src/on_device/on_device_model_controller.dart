import 'dart:async';

import 'on_device_engine.dart';
import 'on_device_model.dart';

/// True when compiled for the web, where the model has its own size.
const _web = bool.fromEnvironment('dart.library.js_interop');

/// The in-app model's lifecycle. Registers an installed model at start,
/// loads it only on [ensureLoaded], and refuses to load by itself after a
/// load that never finished (the process was most likely killed for memory).
class OnDeviceModelController {
  OnDeviceModelController({
    required OnDeviceEngine engine,
    required OnDeviceModelSpec spec,
    required LoadMarker marker,
  }) : _engine = engine,
       _spec = spec,
       _marker = marker;

  final OnDeviceEngine _engine;
  final OnDeviceModelSpec _spec;
  final LoadMarker _marker;
  final _states = StreamController<OnDeviceModelState>.broadcast();

  OnDeviceModelState _state = const ModelNotDownloaded();
  StreamSubscription<(int, int)>? _download;
  Completer<void>? _downloadDone;
  Future<void>? _loading;
  Future<void>? _starting;
  Future<void>? _retrying;
  Future<void>? _deleting;

  OnDeviceModelState get state => _state;

  /// Every change after the current [state].
  Stream<OnDeviceModelState> get states => _states.stream;

  void _set(OnDeviceModelState state) {
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }

  /// Checks support, the load marker and the disk. Never loads. Every other
  /// call waits for it, so none acts on the state from before.
  Future<void> start() => _starting ??= _start();

  /// Completes when [start] has; at once when it was never called.
  Future<void> get started => _starting ?? Future.value();

  Future<void> _start() async {
    try {
      await _check();
    } catch (e) {
      // Never stay in ModelNotDownloaded on a failed check; retry() recovers.
      _set(ModelFailed(OnDeviceFailure.other, '$e'));
    }
  }

  Future<void> _check() async {
    final support = await _engine.support(_spec);
    final ram = support.ramBytes;
    if (support.unsupported case final reason?) {
      _set(ModelUnsupported(reason));
    } else if (ram != null && ram < _spec.minRamBytes) {
      _set(const ModelUnsupported(UnsupportedReason.notEnoughMemory));
    } else if (await _marker.isSet()) {
      _set(const ModelFailed(OnDeviceFailure.memory));
    } else {
      _set(
        await _engine.isInstalled(_spec)
            ? const ModelDownloaded()
            : const ModelNotDownloaded(),
      );
    }
  }

  /// Completes when the download ends: installed, failed or cancelled.
  /// Throws [StateError] when the device cannot run the model. Does nothing
  /// unless the model is not downloaded or its download failed.
  Future<void> download() async {
    await started;
    await _deleting;
    if (_state is ModelUnsupported) {
      throw StateError('This device cannot run ${_spec.label}.');
    }
    final failedDownload = switch (_state) {
      ModelFailed(kind: OnDeviceFailure.download) => true,
      _ => false,
    };
    if (_state is! ModelNotDownloaded && !failedDownload) {
      return _downloadDone?.future;
    }
    final done = _downloadDone = Completer<void>();
    _set(
      ModelDownloading(
        0,
        _web ? _spec.webSizeBytes ?? _spec.sizeBytes : _spec.sizeBytes,
      ),
    );
    _download = _engine
        .download(_spec)
        .listen(
          (p) => _set(ModelDownloading(p.$1, p.$2)),
          onError: (Object e) {
            _endDownload();
            _set(ModelFailed(OnDeviceFailure.download, '$e'));
          },
          onDone: () {
            _endDownload();
            _set(const ModelDownloaded());
          },
          cancelOnError: true,
        );
    return done.future;
  }

  void _endDownload() {
    _download = null;
    _downloadDone?.complete();
    _downloadDone = null;
  }

  Future<void> cancelDownload() async {
    final download = _download;
    if (download == null) return;
    _endDownload();
    _set(const ModelNotDownloaded());
    // The engine removes the partial file on its own; nothing waits for it.
    unawaited(download.cancel());
  }

  /// Frees memory and disk; the model can be downloaded again. Loads and
  /// downloads asked for meanwhile wait until it is done.
  Future<void> delete() =>
      _deleting ??= _delete().whenComplete(() => _deleting = null);

  Future<void> _delete() async {
    await started;
    await cancelDownload();
    if (_loading case final loading?) await loading;
    final loaded = _state is ModelReady;
    // Shown at once, so nothing uses the model while it goes.
    if (_state is! ModelUnsupported) _set(const ModelNotDownloaded());
    if (loaded) await _engine.unload();
    await _engine.delete(_spec);
    await _marker.set(false);
  }

  /// Loads a downloaded model; does nothing in any other state.
  Future<void> ensureLoaded() async {
    await started;
    await _deleting;
    if (_loading case final loading?) return loading;
    if (_state is! ModelDownloaded) return;
    return _loading = _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    await _marker.set(true);
    _set(const ModelLoading());
    try {
      final provider = await _engine.load(_spec);
      await _marker.set(false);
      _set(ModelReady(provider));
    } catch (e) {
      await _marker.set(false);
      _set(ModelFailed(OnDeviceFailure.load, '$e'));
    }
  }

  /// From [ModelFailed]: downloads again after a failed download, otherwise
  /// loads again (the marker is cleared, so a crash can happen once more).
  Future<void> retry() =>
      _retrying ??= _retry().whenComplete(() => _retrying = null);

  Future<void> _retry() async {
    await started;
    final state = _state;
    if (state is! ModelFailed) return;
    if (state.kind == OnDeviceFailure.other) {
      // The first check failed: run it again.
      _starting = null;
      return start();
    }
    await _marker.set(false);
    if (state.kind == OnDeviceFailure.download ||
        !await _engine.isInstalled(_spec)) {
      _set(const ModelNotDownloaded());
      return download();
    }
    _set(const ModelDownloaded());
    return ensureLoaded();
  }

  void dispose() {
    unawaited(_download?.cancel());
    _endDownload();
    unawaited(_states.close());
  }
}
