import 'package:flutter_agentify/ai/screen_contexts.dart';
import 'package:flutter_agentify/data/repositories/in_memory_settings_repository.dart';
import 'package:flutter_agentify/domain/entities/assistant_settings.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  test(
    'settings reports theme, locale and assistant settings without a key',
    () async {
      final settings = InMemorySettingsRepository();
      await settings.setAssistantSettings(
        const AssistantSettings(
          presetId: 'openai',
          baseUrl: 'https://api.openai.com/v1',
          model: 'm',
        ),
      );
      final container = setUpTestServices(settings: settings);
      final view = buildScreenContexts(container)['/settings']?.view;
      final result = await view?.call(
        const NavigationState(route: '/settings', location: '/settings'),
      ) as Map<String, Object?>;
      expect(result['screen'], 'settings');
      expect(result['themeMode'], 'system');
      expect(result['locale'], isA<String>());
      expect(result['assistant'], {
        'preset': 'openai',
        'model': 'm',
        'configured': true,
      });
      expect(result.toString(), isNot(contains('key')));
    },
  );
}
