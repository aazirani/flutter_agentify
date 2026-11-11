import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart' as edge;
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';

import 'engine_chat.dart';
import 'host/host.dart';
import 'on_device_provider.dart';

const _mib = 1024 * 1024;

/// [OnDeviceEngine] on flutter_edge_ai with Google's LiteRT-LM.
class EdgeAiEngine implements OnDeviceEngine {
  /// [useGpu] false runs on the processor; the measuring tool compares both.
  ///
  /// The other parameters replace the engine's calls in tests.
  EdgeAiEngine({
    this.useGpu = true,
    @visibleForTesting Future<void> Function()? initializer,
    @visibleForTesting Future<bool> Function(String file)? isInstalledFile,
    @visibleForTesting Future<void> Function(String file)? uninstallFile,
    @visibleForTesting
    Future<void> Function(
      OnDeviceModelSpec spec,
      void Function(int percent) onProgress,
      edge.CancelToken cancel,
    )?
    install,
  }) : _initializer =
           initializer ??
           (() => edge.FlutterEdgeAi.initialize(
             inferenceEngines: const [LiteRtLmEngine()],
           )),
       _isInstalledFile =
           isInstalledFile ?? edge.FlutterEdgeAi.isModelInstalled,
       _uninstallFile = uninstallFile ?? edge.FlutterEdgeAi.uninstallModel,
       _install =
           install ??
           ((spec, onProgress, cancel) =>
               _installer(spec)
                   .withProgress(onProgress)
                   .withCancelToken(cancel)
                   .install());

  final bool useGpu;
  final Future<void> Function() _initializer;
  final Future<bool> Function(String file) _isInstalledFile;
  final Future<void> Function(String file) _uninstallFile;
  final Future<void> Function(
    OnDeviceModelSpec spec,
    void Function(int percent) onProgress,
    edge.CancelToken cancel,
  )
  _install;

  Future<void>? _initialized;
  edge.InferenceModel? _model;
  OnDeviceProvider? _provider;

  /// The newest download per file; an older one must not remove the file a
  /// newer one is writing.
  final _downloads = <String, int>{};

  /// A failed download still removing its file; the next one waits for it.
  final _removing = <String, Future<void>>{};

  Future<void> _initialize() =>
      _initialized ??= _initializer().onError<Object>((e, stack) {
        // A failure is not kept, so Retry can try again.
        _initialized = null;
        Error.throwWithStackTrace(e, stack);
      });

  static String _url(OnDeviceModelSpec spec) =>
      kIsWeb ? spec.webUrl ?? spec.url : spec.url;

  static int _size(OnDeviceModelSpec spec) =>
      kIsWeb ? spec.webSizeBytes ?? spec.sizeBytes : spec.sizeBytes;

  /// The name the engine installs the file under.
  static String _file(OnDeviceModelSpec spec) =>
      Uri.parse(_url(spec)).pathSegments.last;

  // shortcut: every spec is treated as Gemma 4, the only model verified on
  // LiteRT-LM across platforms; add a model type to the spec with a second model.
  static edge.InferenceInstallationBuilder _installer(OnDeviceModelSpec spec) =>
      edge.FlutterEdgeAi.installModel(
        modelType: edge.ModelType.gemma4,
        fileType: edge.ModelFileType.litertlm,
      ).fromNetwork(_url(spec), expectedSize: kIsWeb ? null : _size(spec));

  @override
  Future<DeviceSupport> support(OnDeviceModelSpec spec) async {
    if (kIsWeb && spec.webUrl == null) {
      return const DeviceSupport(unsupported: UnsupportedReason.platform);
    }
    if (hostUnsupported() case final reason?) {
      return DeviceSupport(unsupported: reason);
    }
    final BaseDeviceInfo info;
    try {
      info = await DeviceInfoPlugin().deviceInfo;
    } on Object {
      return const DeviceSupport();
    }
    // Floors from flutter_edge_ai 2.6.0: Android 11 (SDK 30), iOS 15, macOS 14.
    final (tooOld, ram) = switch (info) {
      AndroidDeviceInfo i => (i.version.sdkInt < 30, i.physicalRamSize * _mib),
      IosDeviceInfo i => (
        (int.tryParse(i.systemVersion.split('.').first) ?? 0) < 15,
        i.physicalRamSize * _mib,
      ),
      MacOsDeviceInfo i => (i.majorVersion < 14, i.memorySize),
      WindowsDeviceInfo i => (false, i.systemMemoryInMegabytes * _mib),
      _ => (false, null),
    };
    return DeviceSupport(
      unsupported: tooOld ? UnsupportedReason.osVersion : null,
      ramBytes: ram != null && ram > 0 ? ram : null,
    );
  }

  @override
  Future<bool> isInstalled(OnDeviceModelSpec spec) async {
    await _initialize();
    return _isInstalledFile(_file(spec));
  }

  @override
  Stream<(int, int)> download(OnDeviceModelSpec spec) {
    final total = _size(spec);
    final cancel = edge.CancelToken();
    final file = _file(spec);
    final id = _downloads[file] = (_downloads[file] ?? 0) + 1;
    var cancelled = false;
    late final StreamController<(int, int)> controller;
    controller = StreamController(
      onListen: () async {
        try {
          await _initialize();
          await _removing[file];
          await _install(spec, (percent) {
            if (!cancelled) controller.add((total * percent ~/ 100, total));
          }, cancel);
        } on Object catch (e, stack) {
          // The engine records a model only once its file is complete, so a
          // failed or cancelled download is never treated as installed. Not
          // when a newer download of the file has started: it owns the file.
          if (_downloads[file] == id) {
            final removing = _removing[file] = _forget(spec);
            await removing;
            if (identical(_removing[file], removing)) _removing.remove(file);
          }
          if (!cancelled) controller.addError(e, stack);
        }
        if (_downloads[file] == id) _downloads.remove(file);
        await controller.close();
      },
      onCancel: () {
        cancelled = true;
        cancel.cancel('Download cancelled.');
      },
    );
    return controller.stream;
  }

  /// Removes the model's record and file; nothing to do when there is none.
  Future<void> _forget(OnDeviceModelSpec spec) async {
    try {
      await _uninstallFile(_file(spec));
    } on Object {
      // Not installed.
    }
  }

  @override
  Future<void> delete(OnDeviceModelSpec spec) async {
    await _initialize();
    await _forget(spec);
  }

  @override
  Future<LlmProvider> load(OnDeviceModelSpec spec) async {
    await _initialize();
    // Never a silent 2.6 GB download: loading needs the model on disk.
    if (!await isInstalled(spec)) {
      throw StateError('${spec.label} is not downloaded.');
    }
    // Already installed, so this only makes it the engine's active model.
    await _installer(spec).install();
    final model = _model = await edge.FlutterEdgeAi.getActiveModel(
      maxTokens: spec.config.contextWindow,
      preferredBackend: useGpu
          ? edge.PreferredBackend.gpu
          : edge.PreferredBackend.cpu,
      // At half precision the GPU garbles long ids (measured on Metal).
      activationDataType: edge.ActivationDataType.float32,
    );
    return _provider = OnDeviceProvider(({
      required system,
      required tools,
      required maxOutputTokens,
    }) async {
      return EdgeAiChat(
        await model.openChat(
          tools: tools,
          supportsFunctionCalls: tools.isNotEmpty,
          systemInstruction: system,
          maxOutputTokens: maxOutputTokens,
        ),
      );
    });
  }

  @override
  Future<void> unload() async {
    // The chat first, then the model it runs on.
    await _provider?.dispose();
    _provider = null;
    final model = _model;
    _model = null;
    await model?.close();
  }
}
