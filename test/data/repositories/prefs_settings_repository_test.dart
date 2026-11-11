import 'package:flutter_agentify/data/repositories/prefs_settings_repository.dart';
import 'package:flutter_agentify/domain/entities/app_theme_mode.dart';
import 'package:flutter_agentify/domain/entities/assistant_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<PrefsSettingsRepository> _repo([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return PrefsSettingsRepository(await SharedPreferences.getInstance());
}

void main() {
  test('theme mode defaults to system and round-trips', () async {
    final repo = await _repo();
    expect(repo.getThemeMode(), AppThemeMode.system);
    await repo.setThemeMode(AppThemeMode.dark);
    expect(repo.getThemeMode(), AppThemeMode.dark);
    expect((await _repoFromCurrent()).getThemeMode(), AppThemeMode.dark);
  });

  test('an unknown stored theme value reads as system', () async {
    expect(
      (await _repo({'theme_mode': 'purple'})).getThemeMode(),
      AppThemeMode.system,
    );
  });

  // @on-device:begin
  test('the in-app model is in use until turned off, and stays off', () async {
    final repo = await _repo();
    expect(repo.getUseOnDeviceModel(), isTrue);
    await repo.setUseOnDeviceModel(false);
    expect((await _repoFromCurrent()).getUseOnDeviceModel(), isFalse);
  });

  // @on-device:end
  test('locale is null until set', () async {
    final repo = await _repo();
    expect(repo.getLocale(), isNull);
    await repo.setLocale('fa');
    expect(repo.getLocale(), 'fa');
  });

  test('reads a saved theme mode and locale', () async {
    final repo = await _repo({'theme_mode': 'dark', 'locale': 'fa'});
    expect(repo.getThemeMode(), AppThemeMode.dark);
    expect(repo.getLocale(), 'fa');
  });

  test(
    'assistant settings default to the ollama preset and round-trip',
    () async {
      final repo = await _repo();
      final defaults = repo.getAssistantSettings();
      expect(defaults.presetId, 'ollama');
      expect(defaults.baseUrl, 'http://localhost:11434/v1');
      expect(defaults.model, '');
      expect(defaults.toolCalling, isNull);
      expect(defaults.contextWindow, isNull);

      const saved = AssistantSettings(
        presetId: 'openai',
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-x',
        toolCalling: false,
        contextWindow: 32000,
      );
      await repo.setAssistantSettings(saved);
      final read = (await _repoFromCurrent()).getAssistantSettings();
      expect(read.presetId, 'openai');
      expect(read.baseUrl, 'https://api.openai.com/v1');
      expect(read.model, 'gpt-x');
      expect(read.toolCalling, isFalse);
      expect(read.contextWindow, 32000);

      await repo.setAssistantSettings(const AssistantSettings(model: 'm'));
      final cleared = repo.getAssistantSettings();
      expect(cleared.toolCalling, isNull);
      expect(cleared.contextWindow, isNull);
    },
  );

  test('isConfigured is false until base URL and model are both set', () {
    expect(const AssistantSettings().isConfigured, isFalse);
    expect(const AssistantSettings(model: 'm').isConfigured, isTrue);
    expect(
      const AssistantSettings(baseUrl: ' ', model: 'm').isConfigured,
      isFalse,
    );
    expect(const AssistantSettings(model: '  ').isConfigured, isFalse);
  });
}

Future<PrefsSettingsRepository> _repoFromCurrent() async =>
    PrefsSettingsRepository(await SharedPreferences.getInstance());
