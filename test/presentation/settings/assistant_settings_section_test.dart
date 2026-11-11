import 'package:flutter/material.dart';
import 'package:flutter_agentify/ai/assistant_providers.dart';
import 'package:flutter_agentify/data/repositories/in_memory_settings_repository.dart';
import 'package:flutter_agentify/domain/entities/assistant_settings.dart';
import 'package:flutter_agentify/domain/repositories/secret_store.dart';
import 'package:flutter_agentify/presentation/settings/assistant_settings_section.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

/// Records every call, so a test can prove secure storage was never used.
class _SpySecretStore implements SecretStore {
  _SpySecretStore([Map<String, String>? keys]) : keys = {...?keys};

  final Map<String, String> keys;
  var calls = 0;

  @override
  Future<String?> getApiKey(String presetId) async {
    calls++;
    return keys[presetId];
  }

  @override
  Future<void> setApiKey(String presetId, String? value) async {
    calls++;
    if (value == null || value.isEmpty) {
      keys.remove(presetId);
    } else {
      keys[presetId] = value;
    }
  }
}

Future<InMemorySettingsRepository> _pump(
  WidgetTester tester, {
  bool isWeb = false,
  SecretStore? secrets,
  AssistantSettings? initial,
}) async {
  final settings = InMemorySettingsRepository();
  if (initial != null) await settings.setAssistantSettings(initial);
  final container = setUpTestServices(settings: settings, secrets: secrets);
  await pumpTestAppWith(
    tester,
    locale: english,
    container,
    Scaffold(
      body: SingleChildScrollView(
        child: AssistantSettingsSection(isWeb: isWeb),
      ),
    ),
  );
  return settings;
}

Finder _field(String label) => find.widgetWithText(TextField, label);

Future<void> _choosePreset(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('assistant_preset')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('choosing a preset fills base URL and model', (tester) async {
    await _pump(tester);
    await _choosePreset(tester, 'Anthropic (Claude)');
    expect(find.text('https://api.anthropic.com'), findsOneWidget);
    expect(find.text('claude-sonnet-5-5'), findsOneWidget);
  });

  testWidgets('save stores trimmed settings', (tester) async {
    final settings = await _pump(tester);
    await tester.enterText(
      _field('Server address'),
      ' http://localhost:11434/v1/ ',
    );
    await tester.enterText(_field('Model'), ' qwen3 ');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = settings.getAssistantSettings();
    expect(saved.baseUrl, 'http://localhost:11434/v1');
    expect(saved.model, 'qwen3');
    expect(saved.presetId, 'ollama');
  });

  testWidgets('after save the form shows what was stored', (tester) async {
    await _pump(tester);
    await tester.enterText(
      _field('Server address'),
      ' http://localhost:11434/v1/ ',
    );
    await tester.enterText(_field('Model'), ' qwen3 ');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('http://localhost:11434/v1'), findsOneWidget);
    expect(find.text('qwen3'), findsOneWidget);
  });

  testWidgets('a context window that is not a number is not saved', (
    tester,
  ) async {
    final settings = await _pump(
      tester,
      initial: const AssistantSettings(model: 'qwen3'),
    );
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Context window (tokens)'), 'abc');
    await tester.enterText(_field('Model'), 'llama3');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a whole number of tokens.'), findsOneWidget);
    expect(settings.getAssistantSettings().model, 'qwen3');
  });

  testWidgets('save is disabled while the model name is empty', (tester) async {
    await _pump(tester);
    FilledButton save() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
    expect(save().onPressed, isNull);
    await tester.enterText(_field('Model'), '  ');
    await tester.pump();
    expect(save().onPressed, isNull);
    await tester.enterText(_field('Model'), 'qwen3');
    await tester.pump();
    expect(save().onPressed, isNotNull);
  });

  testWidgets(
    'the key field is hidden when isWeb is true and no key is stored',
    (tester) async {
      final spy = _SpySecretStore();
      await _pump(
        tester,
        isWeb: true,
        secrets: spy,
        initial: const AssistantSettings(
          presetId: 'openai',
          baseUrl: 'https://api.openai.com/v1',
          model: 'm',
        ),
      );
      expect(_field('API key'), findsNothing);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(spy.calls, 0);
    },
  );

  testWidgets('the key field is hidden for the ollama preset', (tester) async {
    await _pump(tester);
    expect(_field('API key'), findsNothing);
    await _choosePreset(tester, 'OpenAI');
    expect(_field('API key'), findsOneWidget);
  });

  testWidgets('the stored key is never shown back', (tester) async {
    final key = 'sk-${'z' * 30}';
    await _pump(
      tester,
      secrets: _SpySecretStore({'openai': key}),
      initial: const AssistantSettings(
        presetId: 'openai',
        baseUrl: 'https://api.openai.com/v1',
        model: 'm',
      ),
    );
    expect(find.text(key), findsNothing);
    expect(
      tester.widget<TextField>(_field('API key')).controller?.text,
      isEmpty,
    );
    expect(find.textContaining('A key is saved'), findsOneWidget);
  });

  testWidgets(
    'turning off "Model can call tools" is saved and the session runs answer-only',
    (tester) async {
      final settings = await _pump(
        tester,
        initial: const AssistantSettings(model: 'qwen3'),
      );
      await tester.tap(find.text('Advanced'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Model can call tools'),
      );
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(settings.getAssistantSettings().toolCalling, isFalse);
      final container = containerOf(tester);
      final session = await container.read(assistantSessionProvider.future);
      expect(session?.answerOnly, isTrue);
    },
  );

  testWidgets('on web, presets that require a key are not offered', (
    tester,
  ) async {
    await _pump(
      tester,
      isWeb: true,
      initial: const AssistantSettings(
        presetId: 'openai',
        baseUrl: 'https://api.openai.com/v1',
        model: 'm',
      ),
    );
    expect(find.text('Custom (OpenAI-compatible)'), findsOneWidget);
    expect(
      find.text(
        'On web no key is stored. Use a local server, or point Custom at '
        'your own proxy.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('assistant_preset')));
    await tester.pumpAndSettle();
    for (final label in [
      'OpenAI',
      'OpenRouter',
      'Gemini',
      'Anthropic (Claude)',
    ]) {
      expect(find.text(label), findsNothing, reason: label);
    }
    expect(find.text('Custom (OpenAI-compatible)'), findsWidgets);
    expect(find.text('Ollama'), findsWidgets);
  });

  testWidgets(
    'Save is disabled while nothing changed or the address is empty',
    (tester) async {
      await _pump(tester, initial: const AssistantSettings(model: 'qwen3'));
      FilledButton save() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(save().onPressed, isNull);
      await tester.enterText(_field('Server address'), '  ');
      await tester.pump();
      expect(save().onPressed, isNull);
      await tester.enterText(_field('Server address'), 'http://localhost:1/v1');
      await tester.pump();
      expect(save().onPressed, isNotNull);
    },
  );

  testWidgets('the key field shows for Custom', (tester) async {
    await _pump(tester);
    await _choosePreset(tester, 'Custom (OpenAI-compatible)');
    expect(_field('API key'), findsOneWidget);
  });

  testWidgets('the saved-key hint follows the chosen preset', (tester) async {
    await _pump(
      tester,
      secrets: _SpySecretStore({'openai': 'k1'}),
      initial: const AssistantSettings(
        presetId: 'openai',
        baseUrl: 'https://api.openai.com/v1',
        model: 'm',
      ),
    );
    expect(find.textContaining('A key is saved'), findsOneWidget);
    await _choosePreset(tester, 'OpenRouter');
    expect(find.textContaining('A key is saved'), findsNothing);
  });

  testWidgets('saving a key stores it under the chosen preset', (tester) async {
    final spy = _SpySecretStore();
    await _pump(tester, secrets: spy);
    await _choosePreset(tester, 'OpenRouter');
    await tester.enterText(_field('Model'), 'm');
    await tester.enterText(_field('API key'), 'k-router');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(spy.keys, {'openrouter': 'k-router'});
  });

  testWidgets('an http address to a remote server shows why under the field', (
    tester,
  ) async {
    final settings = await _pump(tester);
    await _choosePreset(tester, 'OpenAI');
    await tester.enterText(_field('Server address'), 'http://example.com/v1');
    await tester.enterText(_field('Model'), 'm');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(_field('Server address'));
    expect(field.decoration?.errorText, contains('https://'));
    expect(find.byType(SnackBar), findsNothing);
    expect(settings.getAssistantSettings().presetId, isNot('openai'));
    await tester.enterText(_field('Server address'), 'https://example.com/v1');
    await tester.pump();
    expect(
      tester.widget<TextField>(_field('Server address')).decoration?.errorText,
      isNull,
    );
  });

  testWidgets('an address without a server name shows why under the field', (
    tester,
  ) async {
    await _pump(tester, initial: const AssistantSettings(model: 'qwen3'));
    await tester.enterText(_field('Server address'), 'localhost');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(_field('Server address')).decoration?.errorText,
      'Start the address with http:// or https:// and include the server '
      'name.',
    );
  });

  testWidgets('a context window under 1024 shows why under the field', (
    tester,
  ) async {
    await _pump(tester, initial: const AssistantSettings(model: 'qwen3'));
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Context window (tokens)'), '100');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Use at least 1024 tokens.'), findsOneWidget);
  });

  testWidgets('Save is disabled again once the change is saved', (
    tester,
  ) async {
    await _pump(tester, initial: const AssistantSettings(model: 'qwen3'));
    FilledButton save() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
    await tester.enterText(_field('Model'), 'llama3');
    await tester.pump();
    expect(save().onPressed, isNotNull);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(save().onPressed, isNull);
  });

  testWidgets('Save is disabled after saving an address that gets cleaned up', (
    tester,
  ) async {
    await _pump(
      tester,
      initial: const AssistantSettings(
        baseUrl: 'http://localhost:11434/v1',
        model: 'qwen3',
      ),
    );
    FilledButton save() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
    // Only a trailing slash differs: saving would store the same address.
    await tester.enterText(
      _field('Server address'),
      'http://localhost:11434/v1/',
    );
    await tester.pump();
    expect(save().onPressed, isNull);
    await tester.enterText(_field('Server address'), 'http://localhost:1/v1//');
    await tester.pump();
    expect(save().onPressed, isNotNull);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('http://localhost:1/v1'), findsOneWidget);
    expect(save().onPressed, isNull);
  });
}
