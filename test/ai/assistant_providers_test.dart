import 'package:flutter_agentify/ai/assistant_providers.dart';
import 'package:flutter_agentify/data/repositories/in_memory_secret_store.dart';
import 'package:flutter_agentify/data/repositories/in_memory_settings_repository.dart';
import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/domain/actions/app_actions.dart';
import 'package:flutter_agentify/domain/entities/assistant_settings.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// A container whose model connections record the key they were given and
/// are kept in [connections].
Future<(ProviderContainer, List<String?>)> _setUp(
  String presetId, {
  List<ScriptedProvider>? connections,
  Map<String, String>? storedKeys,
  String baseUrl = 'https://x',
}) async {
  final settings = InMemorySettingsRepository();
  await settings.setAssistantSettings(
    AssistantSettings(presetId: presetId, baseUrl: baseUrl, model: 'm'),
  );
  final secrets = InMemorySecretStore();
  for (final MapEntry(:key, :value)
      in (storedKeys ?? {presetId: 'old'}).entries) {
    await secrets.setApiKey(key, value);
  }
  final keys = <String?>[];
  final container = setUpTestServices(
    settings: settings,
    secrets: secrets,
    overrides: [
      modelConnectorProvider.overrideWithValue(({
        required presetId,
        required baseUrl,
        apiKey,
      }) {
        keys.add(apiKey);
        final connection = ScriptedProvider(const []);
        connections?.add(connection);
        return connection;
      }),
    ],
  );
  return (container, keys);
}

void main() {
  test('saving a new key restarts the assistant with it', () async {
    final (container, keys) = await _setUp('anthropic');
    final first = await container.read(assistantSessionProvider.future);
    final actions = ServiceLocator.getIt<AppActions>();
    await ServiceLocator.getIt<ActionRegistry>().run(actions.setApiKey, (
      presetId: 'anthropic',
      key: 'new',
    ));
    final second = await container.read(assistantSessionProvider.future);
    expect(second, isNot(same(first)));
    expect(keys, ['old', 'new']);
  });

  test('replacing the assistant closes its old connection', () async {
    final connections = <ScriptedProvider>[];
    final (container, _) = await _setUp('anthropic', connections: connections);
    await container.read(assistantSessionProvider.future);
    final actions = ServiceLocator.getIt<AppActions>();
    await ServiceLocator.getIt<ActionRegistry>().run(actions.setApiKey, (
      presetId: 'anthropic',
      key: 'new',
    ));
    await container.read(assistantSessionProvider.future);
    expect([for (final c in connections) c.closed], [true, false]);
  });

  test('a preset that needs no key is not sent the saved one', () async {
    final (container, keys) = await _setUp('ollama');
    await container.read(assistantSessionProvider.future);
    expect(keys, [null]);
  });

  test('a key saved for one provider is not sent to another', () async {
    final (container, keys) = await _setUp(
      'openrouter',
      storedKeys: {'openai': 'k-openai'},
    );
    await container.read(assistantSessionProvider.future);
    expect(keys, [null]);
  });

  test('the custom preset sends its own key', () async {
    final (container, keys) = await _setUp(
      'custom',
      storedKeys: {'custom': 'k-custom', 'openai': 'k-openai'},
    );
    await container.read(assistantSessionProvider.future);
    expect(keys, ['k-custom']);
  });

  test('ollama never reads a key', () async {
    final (container, keys) = await _setUp(
      'ollama',
      storedKeys: {'ollama': 'k-ollama'},
    );
    await container.read(assistantSessionProvider.future);
    expect(keys, [null]);
  });

  test('a key is not sent over http to a non-local host', () async {
    final (container, keys) = await _setUp(
      'openai',
      storedKeys: {'openai': 'k-openai'},
      baseUrl: 'http://api.example.com/v1',
    );
    await container.read(assistantSessionProvider.future);
    expect(keys, [null]);
  });

  test('a key is sent over https', () async {
    final (container, keys) = await _setUp(
      'openai',
      storedKeys: {'openai': 'k-openai'},
      baseUrl: 'https://api.example.com/v1',
    );
    await container.read(assistantSessionProvider.future);
    expect(keys, ['k-openai']);
  });
}
