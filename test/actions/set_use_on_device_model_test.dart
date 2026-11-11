import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/actions_harness.dart';
import '../support/on_device_fixture.dart';

void main() {
  test('turns the model on this device off and on, with a receipt', () async {
    final harness = ActionsHarness();
    expect(harness.settings.getUseOnDeviceModel(), isTrue);

    final off = await harness.call('set_use_on_device_model', {'use': false});
    expect(off.receipts.single.summary, 'The model server answers');
    expect(off.receipts.single.resource, 'settings');
    expect(off.receipts.single.verified, isTrue);
    expect(harness.settings.getUseOnDeviceModel(), isFalse);

    await harness.registry.run(harness.actions.setUseOnDeviceModel, true);
    expect(harness.settings.getUseOnDeviceModel(), isTrue);
  });

  test('turning it on loads a downloaded model', () async {
    final engine = FakeOnDeviceEngine()..installed = true;
    final model = await startedModel(engine);
    final harness = ActionsHarness()..onDeviceModel = model;
    await harness.registry.run(harness.actions.setUseOnDeviceModel, true);
    await pumpEventQueue();
    expect(model.state, isA<ModelReady>());
  });

  test('turning it off does not load the model', () async {
    final engine = FakeOnDeviceEngine()..installed = true;
    final model = await startedModel(engine);
    final harness = ActionsHarness()..onDeviceModel = model;
    await harness.registry.run(harness.actions.setUseOnDeviceModel, false);
    await pumpEventQueue();
    expect(engine.loadCalls, 0);
  });

  test('a value that is not true or false is refused', () async {
    final harness = ActionsHarness();
    await expectLater(
      harness.call('set_use_on_device_model', {'use': 'yes'}),
      failsWith('invalid_input'),
    );
    expect(harness.settings.getUseOnDeviceModel(), isTrue);
  });
}
