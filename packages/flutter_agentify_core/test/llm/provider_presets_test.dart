import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:test/test.dart';

void main() {
  test('preset ids are unique and include ollama and custom', () {
    final ids = providerPresets.map((p) => p.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(
      ids,
      containsAll([
        'ollama',
        'lm_studio',
        'openai',
        'openrouter',
        'gemini',
        'anthropic',
        'custom',
      ]),
    );
    final ollama = providerPresets.firstWhere((p) => p.id == 'ollama');
    expect(ollama.baseUrl, 'http://localhost:11434/v1');
    final keyUse = {for (final p in providerPresets) p.id: p.keyUse};
    expect(keyUse, {
      'ollama': KeyUse.none,
      'lm_studio': KeyUse.none,
      'openai': KeyUse.required,
      'openrouter': KeyUse.required,
      'gemini': KeyUse.required,
      'anthropic': KeyUse.required,
      'custom': KeyUse.optional,
    });
    expect(ollama.defaults.contextWindow, 8192);
    final anthropic = providerPresets.firstWhere((p) => p.id == 'anthropic');
    expect(anthropic.defaults.model, 'claude-sonnet-5-5');
    expect(anthropic.defaults.contextWindow, 200000);
    expect(providerPresets.firstWhere((p) => p.id == 'custom').baseUrl, '');
  });

  test('buildProvider returns AnthropicProvider for anthropic, '
      'OpenAiCompatibleProvider otherwise', () {
    expect(
      buildProvider(
        presetId: 'anthropic',
        baseUrl: 'https://api.anthropic.com',
        apiKey: 'k',
      ),
      isA<AnthropicProvider>(),
    );
    final openai = buildProvider(
      presetId: 'openai',
      baseUrl: 'https://api.openai.com/v1',
      apiKey: 'k',
    );
    expect(
      (openai as OpenAiCompatibleProvider).maxTokensField,
      'max_completion_tokens',
    );
    expect(
      (buildProvider(
        presetId: 'ollama',
        baseUrl: 'http://localhost:1/v1',
      ) as OpenAiCompatibleProvider).maxTokensField,
      'max_tokens',
    );
    for (final id in ['ollama', 'openai', 'custom']) {
      expect(
        buildProvider(presetId: id, baseUrl: 'http://localhost:1/v1'),
        isA<OpenAiCompatibleProvider>(),
        reason: id,
      );
    }
  });
}
