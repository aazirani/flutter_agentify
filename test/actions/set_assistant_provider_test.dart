import 'package:flutter_agentify/domain/entities/assistant_settings.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/actions_harness.dart';

void main() {
  test('is not offered to the assistant', () {
    final h = ActionsHarness();
    final tools = h.registry.tools.map((t) => t.name);
    expect(tools, isNot(contains('set_assistant_provider')));
    expect(tools, isNot(contains('set_api_key')));
  });

  test('trims the base URL and removes trailing slashes', () async {
    final h = ActionsHarness();
    final result = await h.call(
      'set_assistant_provider',
      {
        'preset': 'ollama',
        'base_url': ' http://x:1/v1// ',
        'model': ' qwen3 ',
        'tool_calling': false,
        'context_window': 4096,
      },
      caller: Caller.cli,
      approved: true,
    );
    final saved = h.settings.getAssistantSettings();
    expect(saved.baseUrl, 'http://x:1/v1');
    expect(saved.model, 'qwen3');
    expect(saved.toolCalling, isFalse);
    expect(saved.contextWindow, 4096);
    expect(result.receipts.single.summary, 'Assistant model settings saved');
  });

  test('a typed call from the UI is trimmed and checked too', () async {
    final h = ActionsHarness();
    await h.registry.run(
      h.actions.setAssistantProvider,
      const AssistantSettings(baseUrl: ' http://x:1/v1/ ', model: ' m '),
    );
    expect(h.settings.getAssistantSettings().baseUrl, 'http://x:1/v1');
    expect(h.settings.getAssistantSettings().model, 'm');
    await expectLater(
      h.registry.run(
        h.actions.setAssistantProvider,
        const AssistantSettings(presetId: 'nope'),
      ),
      failsWith('invalid_input'),
    );
  });

  test('an unknown preset is invalid_input', () async {
    final h = ActionsHarness();
    await expectLater(
      h.call(
        'set_assistant_provider',
        {'preset': 'nope', 'base_url': 'http://x', 'model': 'm'},
        caller: Caller.cli,
        approved: true,
      ),
      failsWith('invalid_input'),
    );
  });

  test('a context window below 1024 is invalid_input', () async {
    final h = ActionsHarness();
    await expectLater(
      h.call(
        'set_assistant_provider',
        {
          'preset': 'ollama',
          'base_url': 'http://x',
          'model': 'm',
          'context_window': 512,
        },
        caller: Caller.cli,
        approved: true,
      ),
      failsWith('invalid_input'),
    );
  });

  group('the server address', () {
    Future<ActionCallResult> save(
      ActionsHarness h,
      String baseUrl, {
      String preset = 'custom',
    }) => h.call(
      'set_assistant_provider',
      {'preset': preset, 'base_url': baseUrl, 'model': 'm'},
      caller: Caller.cli,
      approved: true,
    );

    for (final url in ['', 'localhost:11434/v1', 'http://api.example.com/v1']) {
      test('"$url" is invalid_input', () async {
        await expectLater(
          save(ActionsHarness(), url),
          failsWith('invalid_input'),
        );
      });
    }

    for (final url in [
      'http://192.168.1.20:11434/v1',
      'http://[::1]:11434/v1',
      'http://my-pc:11434/v1',
      'http://ollama.local/v1',
      'https://api.example.com/v1',
    ]) {
      test('"$url" is saved', () async {
        final h = ActionsHarness();
        await save(h, url);
        expect(h.settings.getAssistantSettings().baseUrl, url);
      });
    }

    test('a preset that never sends a key may use http to any host', () async {
      final h = ActionsHarness();
      await save(h, 'http://example.com:11434/v1', preset: 'ollama');
      expect(
        h.settings.getAssistantSettings().baseUrl,
        'http://example.com:11434/v1',
      );
    });
  });
}
