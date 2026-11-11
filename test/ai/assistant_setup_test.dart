import 'package:flutter_agentify/ai/assistant_setup.dart';
import 'package:flutter_agentify/data/repositories/in_memory_settings_repository.dart';
import 'package:flutter_agentify/domain/entities/assistant_settings.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_test/flutter_test.dart';

bool _needsKey(String presetId) =>
    providerPresets.firstWhere((p) => p.id == presetId).keyUse ==
    KeyUse.required;

void main() {
  test('the checked-in setup is consistent', () {
    expect(setupProblems(assistantSetup, presetNeedsKey: _needsKey), isEmpty);
  });

  test('saved settings start from the setup file\'s server', () {
    const server = ServerSetup(
      presetId: 'lm_studio',
      baseUrl: 'http://localhost:1234/v1',
      model: 'qwen',
    );
    final settings = InMemorySettingsRepository(
      defaults: AssistantSettings.fromServer(server),
    ).getAssistantSettings();
    expect(settings.presetId, 'lm_studio');
    expect(settings.baseUrl, 'http://localhost:1234/v1');
    expect(settings.model, 'qwen');
  });

  test('the default settings match the default server', () {
    expect(
      AssistantSettings.fromServer(const ServerSetup()),
      const AssistantSettings(),
    );
  });
}
