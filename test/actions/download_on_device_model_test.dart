import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/actions_harness.dart';
import '../support/on_device_fixture.dart';

void main() {
  test('downloads the model and loads it once it is in', () async {
    final engine = FakeOnDeviceEngine();
    final model = await startedModel(engine);
    final harness = (ActionsHarness()..onDeviceModel = model);
    await harness.registry.run(harness.actions.downloadOnDeviceModel, null);
    await pumpEventQueue();
    expect(engine.downloadCalls, 1);
    expect(model.state, isA<ModelReady>());
  });

  test('after a failed download it downloads again', () async {
    final engine = FakeOnDeviceEngine()..downloadError = Exception('net');
    final model = await startedModel(engine);
    await model.download();
    engine.downloadError = null;
    final harness = (ActionsHarness()..onDeviceModel = model);
    await harness.registry.run(harness.actions.downloadOnDeviceModel, null);
    await pumpEventQueue();
    expect(engine.downloadCalls, 2);
    expect(model.state, isA<ModelReady>());
  });

  test('a device that cannot run the model fails with unsupported', () async {
    final engine = FakeOnDeviceEngine()
      ..deviceSupport = const DeviceSupport(
        unsupported: UnsupportedReason.platform,
      );
    final harness = (ActionsHarness()
      ..onDeviceModel = await startedModel(engine));
    await expectLater(
      harness.call(
        'download_on_device_model',
        {},
        caller: Caller.cli,
        approved: true,
      ),
      failsWith('unsupported'),
    );
    expect(engine.downloadCalls, 0);
  });

  test('an app without the in-app model fails with unavailable', () async {
    final harness = ActionsHarness();
    await expectLater(
      harness.call(
        'download_on_device_model',
        {},
        caller: Caller.cli,
        approved: true,
      ),
      failsWith('unavailable'),
    );
  });

  test('is not offered to the assistant', () async {
    final harness = ActionsHarness();
    expect(harness.actions.downloadOnDeviceModel.agentTool, isFalse);
    await expectLater(
      harness.call('download_on_device_model', {}),
      failsWith('unknown_action'),
    );
  });

  test('right after launch it waits for the device check', () async {
    final engine = FakeOnDeviceEngine()
      ..deviceSupport = const DeviceSupport(
        unsupported: UnsupportedReason.platform,
      );
    final model = OnDeviceModelController(
      engine: engine,
      spec: testModelSpec,
      marker: InMemoryLoadMarker(),
    );
    addTearDown(model.dispose);
    final starting = model.start();
    final harness = (ActionsHarness()..onDeviceModel = model);
    await expectLater(
      harness.call(
        'download_on_device_model',
        {},
        caller: Caller.cli,
        approved: true,
      ),
      failsWith('unsupported'),
    );
    await starting;
    expect(engine.downloadCalls, 0);
  });
}
