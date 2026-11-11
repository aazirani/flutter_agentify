import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/actions_harness.dart';

void main() {
  test('forgets every always-allow', () async {
    final harness = ActionsHarness();
    final approvals = harness.approvals;
    await approvals.setAlwaysAllowed('save_memory', true);
    await harness.registry.run(harness.actions.resetApprovals, null);
    expect(approvals.isAlwaysAllowed('save_memory'), isFalse);
  });

  test('is not offered to the assistant', () async {
    final harness = ActionsHarness();
    expect(harness.actions.resetApprovals.agentTool, isFalse);
    await expectLater(
      harness.call('reset_approvals', null),
      failsWith('unknown_action'),
    );
  });

  test('a ui call reports the reset', () async {
    final harness = ActionsHarness();
    final result = await harness.call(
      'reset_approvals',
      {},
      caller: Caller.cli,
      approved: true,
    );
    expect(result.content, '{"reset":true}');
  });
}
