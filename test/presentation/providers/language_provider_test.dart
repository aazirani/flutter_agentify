import 'package:flutter_agentify/data/repositories/in_memory_settings_repository.dart';
import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/domain/actions/app_actions.dart';
import 'package:flutter_agentify/domain/entities/language/supported_languages.dart';
import 'package:flutter_agentify/presentation/providers/language_provider.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

void main() {
  final defaultCode = kSupportedLanguages.first.locale;
  // Another supported language; the default itself when it is the only one.
  final other = kSupportedLanguages.last.locale;

  test('uses the saved locale when one is saved', () async {
    final settings = InMemorySettingsRepository();
    await settings.setLocale(other);
    final container = setUpTestServices(settings: settings);
    expect(container.read(currentLocaleProvider), other);
  });

  test('without a saved locale it follows a supported device language', () {
    final container = setUpTestServices(
      overrides: [deviceLanguageProvider.overrideWithValue(other)],
    );
    expect(container.read(currentLocaleProvider), other);
  });

  test('an unsupported device language falls back to the first language', () {
    final container = setUpTestServices(
      overrides: [deviceLanguageProvider.overrideWithValue('xx')],
    );
    expect(container.read(currentLocaleProvider), defaultCode);
  });

  test('a saved default language is kept on a device set to another', () async {
    final settings = InMemorySettingsRepository();
    await settings.setLocale(defaultCode);
    final container = setUpTestServices(
      settings: settings,
      overrides: [deviceLanguageProvider.overrideWithValue(other)],
    );
    expect(container.read(currentLocaleProvider), defaultCode);
  });

  test('follows set_language run through the registry', () async {
    final container = setUpTestServices(
      overrides: [deviceLanguageProvider.overrideWithValue('xx')],
    );
    expect(container.read(currentLocaleProvider), defaultCode);
    await ServiceLocator.getIt<ActionRegistry>().run(
      ServiceLocator.getIt<AppActions>().setLanguage,
      other,
    );
    expect(container.read(currentLocaleProvider), other);
  });

  test('a saved language the app no longer supports falls back', () async {
    final settings = InMemorySettingsRepository();
    await settings.setLocale('xx');
    final container = setUpTestServices(
      settings: settings,
      overrides: [deviceLanguageProvider.overrideWithValue(defaultCode)],
    );
    expect(container.read(currentLocaleProvider), defaultCode);
  });
}
