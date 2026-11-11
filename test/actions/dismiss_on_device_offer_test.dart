import 'package:flutter_test/flutter_test.dart';

import '../support/actions_harness.dart';

void main() {
  test('remembers that the person said Not now', () async {
    final harness = ActionsHarness();
    expect(harness.settings.getOnDeviceOfferDismissed(), isFalse);
    await harness.registry.run(harness.actions.dismissOnDeviceOffer, null);
    expect(harness.settings.getOnDeviceOfferDismissed(), isTrue);
  });

  test('is not offered to the assistant', () async {
    final harness = ActionsHarness();
    expect(harness.actions.dismissOnDeviceOffer.agentTool, isFalse);
    await expectLater(
      harness.call('dismiss_on_device_offer', {}),
      failsWith('unknown_action'),
    );
  });
}
