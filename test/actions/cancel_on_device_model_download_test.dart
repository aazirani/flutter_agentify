import 'dart:async';

import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/actions_harness.dart';
import '../support/on_device_fixture.dart';

void main() {
  test('stops the download and nothing is installed', () async {
    final engine = FakeOnDeviceEngine()..downloadGate = Completer<void>();
    final model = await startedModel(engine);
    unawaited(model.download());
    await pumpEventQueue();
    final harness = (ActionsHarness()..onDeviceModel = model);
    await harness.registry.run(
      harness.actions.cancelOnDeviceModelDownload,
      null,
    );
    expect(model.state, isA<ModelNotDownloaded>());
    expect(engine.installed, isFalse);
  });

  test('is not offered to the assistant', () async {
    final harness = ActionsHarness();
    expect(harness.actions.cancelOnDeviceModelDownload.agentTool, isFalse);
    await expectLater(
      harness.call('cancel_on_device_model_download', {}),
      failsWith('unknown_action'),
    );
  });
}
