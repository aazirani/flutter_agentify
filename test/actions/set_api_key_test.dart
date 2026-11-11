import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/actions_harness.dart';

void main() {
  test('is not offered to the assistant', () async {
    final h = ActionsHarness();
    expect(h.registry.tools.map((t) => t.name), isNot(contains('set_api_key')));
    await expectLater(
      h.call('set_api_key', {'preset': 'openai', 'key': 'x'}),
      failsWith('unknown_action'),
    );
  });

  test('stores the key; neither output nor receipt contains it', () async {
    final h = ActionsHarness();
    final key = 'sk-${'a' * 30}';
    final result = await h.call(
      'set_api_key',
      {'preset': 'openai', 'key': key},
      caller: Caller.cli,
      approved: true,
    );
    expect(await h.secrets.getApiKey('openai'), key);
    expect(result.content, isNot(contains(key)));
    expect(result.content, '{"saved":true}');
    expect(result.receipts.single.summary, 'API key saved');
    expect(result.receipts.single.summary, isNot(contains(key)));
  });

  test('an empty key removes it', () async {
    final h = ActionsHarness();
    await h.secrets.setApiKey('openai', 'something');
    await h.secrets.setApiKey('gemini', 'other');
    final result = await h.call(
      'set_api_key',
      {'preset': 'openai', 'key': ''},
      caller: Caller.cli,
      approved: true,
    );
    expect(await h.secrets.getApiKey('openai'), isNull);
    expect(await h.secrets.getApiKey('gemini'), 'other');
    expect(result.content, '{"saved":false}');
    expect(result.receipts.single.summary, 'API key removed');
  });

  test('each preset keeps its own key', () async {
    final h = ActionsHarness();
    await h.registry.run(h.actions.setApiKey, (presetId: 'openai', key: 'k1'));
    expect(await h.secrets.getApiKey('openai'), 'k1');
    expect(await h.secrets.getApiKey('openrouter'), isNull);
  });

  test('an unknown preset is invalid_input', () async {
    final h = ActionsHarness();
    await expectLater(
      h.registry.run(h.actions.setApiKey, (presetId: 'nope', key: 'k')),
      failsWith('invalid_input'),
    );
  });
}
