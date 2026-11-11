import 'package:flutter_agentify/domain/entities/language/supported_languages.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/actions_harness.dart';

void main() {
  test('stores the locale; the receipt uses the English name', () async {
    final h = ActionsHarness();
    final language = kSupportedLanguages.last;
    final result = await h.call('set_language', {'locale': language.locale});
    expect(h.settings.getLocale(), language.locale);
    expect(
      result.receipts.single.summary,
      'Language set to ${language.englishName}',
    );
  });

  test('a typed call with an unsupported locale is invalid_input', () async {
    final h = ActionsHarness();
    await expectLater(
      h.registry.run(h.actions.setLanguage, 'xx'),
      failsWith('invalid_input'),
    );
    expect(h.settings.getLocale(), isNull);
  });

  test('an unsupported locale is invalid_input', () async {
    final h = ActionsHarness();
    await expectLater(
      h.call('set_language', {'locale': 'xx'}),
      failsWith('invalid_input'),
    );
    expect(h.settings.getLocale(), isNull);
  });
}
