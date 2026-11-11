import 'dart:async';

import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:test/test.dart';

const _spec = OnDeviceModelSpec(
  id: 'm',
  label: 'M',
  url: 'https://example.com/m',
  sizeBytes: 100,
  minRamBytes: 1000,
  config: ModelConfig(model: 'm'),
);

void main() {
  late FakeOnDeviceEngine engine;
  late InMemoryLoadMarker marker;

  OnDeviceModelController controller() =>
      OnDeviceModelController(engine: engine, spec: _spec, marker: marker);

  setUp(() {
    engine = FakeOnDeviceEngine();
    marker = InMemoryLoadMarker();
  });

  test('start does not load an installed model', () async {
    engine.installed = true;
    final c = controller();
    await c.start();
    expect(c.state, isA<ModelDownloaded>());
    expect(engine.loadCalls, 0);
  });

  test('start without the model is NotDownloaded', () async {
    final c = controller();
    await c.start();
    expect(c.state, isA<ModelNotDownloaded>());
  });

  test('ensureLoaded goes Loading then Ready', () async {
    engine.installed = true;
    final c = controller();
    await c.start();
    final seen = <OnDeviceModelState>[];
    final sub = c.states.listen(seen.add);
    await c.ensureLoaded();
    await pumpEventQueue();
    expect(seen.map((s) => s.runtimeType), [ModelLoading, ModelReady]);
    expect((c.state as ModelReady).provider, same(engine.provider));
    await sub.cancel();
  });

  test('a marker left set at start means Failed(memory) and no load', () async {
    engine.installed = true;
    await marker.set(true);
    final c = controller();
    await c.start();
    expect(
      c.state,
      isA<ModelFailed>().having((s) => s.kind, 'kind', OnDeviceFailure.memory),
    );
    await c.ensureLoaded();
    expect(engine.loadCalls, 0);
  });

  test('the marker is set before load and cleared after success and after a thrown load', () async {
    engine.installed = true;
    bool? duringLoad;
    engine.onLoad = () async => duringLoad = await marker.isSet();
    final c = controller();
    await c.start();
    await c.ensureLoaded();
    expect(duringLoad, isTrue);
    expect(await marker.isSet(), isFalse);

    engine.loadError = Exception('no');
    final d = controller();
    await d.start();
    await d.ensureLoaded();
    expect(
      d.state,
      isA<ModelFailed>().having((s) => s.kind, 'kind', OnDeviceFailure.load),
    );
    expect(await marker.isSet(), isFalse);
  });

  test('retry from Failed(memory) clears the marker and loads', () async {
    engine.installed = true;
    await marker.set(true);
    final c = controller();
    await c.start();
    await c.retry();
    expect(c.state, isA<ModelReady>());
    expect(engine.loadCalls, 1);
    expect(await marker.isSet(), isFalse);
  });

  test('RAM below the floor is Unsupported(notEnoughMemory) and download() throws StateError', () async {
    engine.deviceSupport = const DeviceSupport(ramBytes: 999);
    final c = controller();
    await c.start();
    expect(
      c.state,
      isA<ModelUnsupported>().having(
        (s) => s.reason,
        'reason',
        UnsupportedReason.notEnoughMemory,
      ),
    );
    expect(c.download, throwsStateError);
    expect(engine.downloadCalls, 0);
  });

  test('an unsupported platform is Unsupported with its reason', () async {
    engine.deviceSupport = const DeviceSupport(
      unsupported: UnsupportedReason.platform,
    );
    final c = controller();
    await c.start();
    expect(
      c.state,
      isA<ModelUnsupported>().having(
        (s) => s.reason,
        'reason',
        UnsupportedReason.platform,
      ),
    );
  });

  test('unknown RAM does not block', () async {
    engine.deviceSupport = const DeviceSupport();
    final c = controller();
    await c.start();
    expect(c.state, isA<ModelNotDownloaded>());
  });

  test('download emits progress then Downloaded', () async {
    engine.progress = [(10, 100), (100, 100)];
    final c = controller();
    await c.start();
    final seen = <OnDeviceModelState>[];
    final sub = c.states.listen(seen.add);
    await c.download();
    await pumpEventQueue();
    expect(seen.whereType<ModelDownloading>().map((s) => s.percent), [
      0,
      10,
      100,
    ]);
    expect(seen.last, isA<ModelDownloaded>());
    expect(engine.loadCalls, 0);
    await sub.cancel();
  });

  test(
    'a download error is Failed(download) and isInstalled stays false',
    () async {
      engine.progress = [(60, 100)];
      engine.downloadError = Exception('network');
      final c = controller();
      await c.start();
      await c.download();
      expect(
        c.state,
        isA<ModelFailed>().having(
          (s) => s.kind,
          'kind',
          OnDeviceFailure.download,
        ),
      );
      expect(await engine.isInstalled(_spec), isFalse);
      await c.retry();
      expect(engine.downloadCalls, 2);
    },
  );

  test('cancelDownload returns to NotDownloaded', () async {
    engine.progress = [(60, 100)];
    engine.downloadGate = Completer<void>();
    final c = controller();
    await c.start();
    final done = c.download();
    await pumpEventQueue();
    expect(c.state, isA<ModelDownloading>());
    await c.cancelDownload();
    await done;
    expect(c.state, isA<ModelNotDownloaded>());
    expect(engine.downloadCancelled, isTrue);
    expect(await engine.isInstalled(_spec), isFalse);
  });

  test('delete from Ready unloads and returns to NotDownloaded', () async {
    engine.installed = true;
    final c = controller();
    await c.start();
    await c.ensureLoaded();
    await c.delete();
    expect(c.state, isA<ModelNotDownloaded>());
    expect(engine.unloadCalls, 1);
    expect(await engine.isInstalled(_spec), isFalse);
  });

  test('ensureLoaded twice at once loads once', () async {
    engine.installed = true;
    final gate = engine.loadGate = Completer<void>();
    final c = controller();
    await c.start();
    final a = c.ensureLoaded();
    final b = c.ensureLoaded();
    gate.complete();
    await Future.wait([a, b]);
    expect(engine.loadCalls, 1);
    expect(c.state, isA<ModelReady>());
  });

  test('ensureLoaded while downloading or unsupported does nothing', () async {
    engine.deviceSupport = const DeviceSupport(
      unsupported: UnsupportedReason.osVersion,
    );
    final c = controller();
    await c.start();
    await c.ensureLoaded();
    expect(engine.loadCalls, 0);

    engine.deviceSupport = const DeviceSupport();
    engine.downloadGate = Completer<void>();
    final d = controller();
    await d.start();
    unawaited(d.download());
    await pumpEventQueue();
    await d.ensureLoaded();
    expect(engine.loadCalls, 0);
    await d.cancelDownload();
  });

  test('ensureLoaded before start finishes waits for it, then loads', () async {
    engine.installed = true;
    final c = controller();
    final starting = c.start();
    final loading = c.ensureLoaded();
    await Future.wait([starting, loading]);
    expect(c.state, isA<ModelReady>());
    expect(engine.loadCalls, 1);
  });

  test(
    'a download asked for before start finishes keeps the load guard',
    () async {
      engine.installed = true;
      await marker.set(true);
      final c = controller();
      final starting = c.start();
      await c.download();
      await c.ensureLoaded();
      await starting;
      expect(
        c.state,
        isA<ModelFailed>().having(
          (s) => s.kind,
          'kind',
          OnDeviceFailure.memory,
        ),
      );
      expect(engine.downloadCalls, 0);
      expect(engine.loadCalls, 0);
    },
  );

  test('retry twice at once downloads once', () async {
    engine.downloadError = Exception('net');
    final c = controller();
    await c.start();
    await c.download();
    engine.downloadError = null;
    await Future.wait([c.retry(), c.retry()]);
    expect(engine.downloadCalls, 2);
    expect(c.state, isA<ModelDownloaded>());
  });

  test('nothing loads or downloads while a delete runs', () async {
    engine.installed = true;
    final gate = engine.deleteGate = Completer<void>();
    final c = controller();
    await c.start();
    final deleting = c.delete();
    await pumpEventQueue();
    expect(c.state, isA<ModelNotDownloaded>());
    final loading = c.ensureLoaded();
    final downloading = c.download();
    gate.complete();
    await Future.wait([deleting, loading, downloading]);
    expect(engine.loadCalls, 0);
    // The download asked for during the delete runs after it.
    expect(engine.downloadCalls, 1);
    expect(c.state, isA<ModelDownloaded>());
  });

  test('delete while loading waits for the load, then unloads', () async {
    engine.installed = true;
    final gate = engine.loadGate = Completer<void>();
    final c = controller();
    await c.start();
    final loading = c.ensureLoaded();
    await pumpEventQueue();
    final deleting = c.delete();
    gate.complete();
    await Future.wait([loading, deleting]);
    expect(engine.unloadCalls, 1);
    expect(engine.installed, isFalse);
    expect(c.state, isA<ModelNotDownloaded>());
  });

  test('a failing support check ends in Failed, and retry recovers', () async {
    engine.supportError = StateError('no');
    final c = controller();
    await c.start();
    expect(c.state, isA<ModelFailed>());
    engine.supportError = null;
    await c.retry();
    expect(c.state, isA<ModelNotDownloaded>());
  });
}
