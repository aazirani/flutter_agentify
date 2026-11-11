import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/actions_harness.dart';
import '../support/on_device_fixture.dart';

void main() {
  test('unloads and deletes the model', () async {
    final engine = FakeOnDeviceEngine()..installed = true;
    final model = await startedModel(engine);
    await model.ensureLoaded();
    final harness = (ActionsHarness()..onDeviceModel = model);
    await harness.registry.run(harness.actions.deleteOnDeviceModel, null);
    expect(model.state, isA<ModelNotDownloaded>());
    expect(engine.unloadCalls, 1);
    expect(engine.installed, isFalse);
  });

  test('is not offered to the assistant', () async {
    final harness = ActionsHarness();
    expect(harness.actions.deleteOnDeviceModel.agentTool, isFalse);
    await expectLater(
      harness.call('delete_on_device_model', {}),
      failsWith('unknown_action'),
    );
  });
}
