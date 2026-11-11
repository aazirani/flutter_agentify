import 'package:flutter/material.dart';
import 'package:flutter_agentify/data/repositories/in_memory_settings_repository.dart';
import 'package:flutter_agentify/domain/entities/language/supported_languages.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

Future<String?> _bodyFont(WidgetTester tester, String locale) async {
  final settings = InMemorySettingsRepository();
  await settings.setLocale(locale);
  await pumpFullApp(tester, settings: settings);
  final context = tester.element(find.byType(Text).first);
  return Theme.of(context).textTheme.bodyMedium?.fontFamily;
}

void main() {
  for (final language in kSupportedLanguages) {
    testWidgets('${language.englishName} uses ${language.fontFamily}', (
      tester,
    ) async {
      expect(await _bodyFont(tester, language.locale), language.fontFamily);
    });
  }
}
