import 'package:flutter/material.dart';
import 'package:flutter_agentify/domain/entities/language/supported_languages.dart';
import 'package:flutter_agentify/utils/routes/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

void main() {
  testWidgets('the welcome screen shows the intro and both buttons', (
    tester,
  ) async {
    await pumpTestApp(tester, locale: english);
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.textContaining("your app's first screen"), findsOneWidget);
    expect(find.text('Assistant'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('Settings opens the settings route', (tester) async {
    await pumpFullApp(tester, locale: english);
    await tester.tap(find.widgetWithText(TextButton, 'Settings'));
    await tester.pumpAndSettle();
    expect(AppRouter.router.state.uri.path, '/settings');
  });

  for (final language in kSupportedLanguages) {
    testWidgets('at 320 wide in ${language.englishName} nothing overflows', (
      tester,
    ) async {
      await pumpTestApp(
        tester,
        size: const Size(320, 640),
        locale: Locale(language.locale),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
