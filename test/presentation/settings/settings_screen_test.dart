import 'package:flutter/material.dart';
import 'package:flutter_agentify/data/repositories/in_memory_settings_repository.dart';
import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/domain/entities/app_theme_mode.dart';
import 'package:flutter_agentify/domain/entities/language/supported_languages.dart';
import 'package:flutter_agentify/presentation/providers/language_provider.dart';
import 'package:flutter_agentify/presentation/settings/settings_screen.dart';
import 'package:flutter_agentify/utils/routes/app_router.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

void main() {
  testWidgets('choosing dark runs set_theme_mode', (tester) async {
    final settings = InMemorySettingsRepository();
    await pumpTestApp(
      tester,
      locale: english,
      home: const SettingsScreen(),
      settings: settings,
    );
    await tester.tap(find.byIcon(Icons.dark_mode));
    await tester.pumpAndSettle();
    expect(settings.getThemeMode(), AppThemeMode.dark);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('choosing another language runs set_language', (tester) async {
    final settings = InMemorySettingsRepository();
    final container = await pumpTestApp(
      tester,
      locale: english,
      home: const SettingsScreen(),
      settings: settings,
    );
    final current = container.read(currentLocaleProvider);
    final other = kSupportedLanguages.firstWhere((l) => l.locale != current);
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(other.language));
    await tester.pumpAndSettle();
    expect(settings.getLocale(), other.locale);
  }, skip: kSupportedLanguages.length < 2);

  testWidgets('asking again before every action clears always-allow', (
    tester,
  ) async {
    await pumpTestApp(tester, locale: english, home: const SettingsScreen());
    final approvals = ServiceLocator.getIt<ApprovalPrefs>();
    await approvals.setAlwaysAllowed('save_memory', true);
    final reset = find.text('Ask again before every action');
    await tester.scrollUntilVisible(
      reset,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(approvals.isAlwaysAllowed('save_memory'), isFalse);
    expect(find.text('The assistant will ask again.'), findsOneWidget);
  });

  testWidgets('saved notes show what the assistant saved, and Forget '
      'deletes it', (tester) async {
    await pumpTestApp(tester, locale: english, home: const SettingsScreen());
    final notes = find.text('Saved notes');
    await tester.scrollUntilVisible(
      notes,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(notes);
    await tester.pumpAndSettle();
    expect(find.textContaining('No notes yet'), findsOneWidget);

    await ServiceLocator.getIt<ActionRegistry>().call(
      'save_memory',
      {'text': 'Prefers short titles'},
      caller: Caller.cli,
      approved: true,
    );
    await tester.pumpAndSettle();
    expect(find.text('Prefers short titles'), findsOneWidget);

    await tester.tap(find.byTooltip('Forget'));
    await tester.pumpAndSettle();
    expect(find.text('Prefers short titles'), findsNothing);
    expect(await ServiceLocator.getIt<MemoryStore>().all(), isEmpty);
  });

  testWidgets('the theme segments are labelled and keep their icons', (
    tester,
  ) async {
    await pumpTestApp(tester, locale: english, home: const SettingsScreen());
    for (final label in ['System', 'Light', 'Dark']) {
      expect(find.byTooltip(label), findsOneWidget, reason: label);
    }
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.byIcon(Icons.brightness_auto), findsOneWidget);
  });

  for (final language in kSupportedLanguages) {
    testWidgets('the language tile names ${language.englishName} in its own '
        'name', (tester) async {
      final settings = InMemorySettingsRepository();
      await settings.setLocale(language.locale);
      await pumpTestApp(
        tester,
        locale: Locale(language.locale),
        home: const SettingsScreen(),
        settings: settings,
      );
      expect(find.textContaining(language.language), findsOneWidget);
    });
  }

  testWidgets('the picker marks the current language', (tester) async {
    await pumpTestApp(tester, locale: english, home: const SettingsScreen());
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    final current = tester.widget<RadioListTile<String>>(
      find.ancestor(
        of: find.textContaining(languageFor(english.languageCode).language),
        matching: find.byType(RadioListTile<String>),
      ),
    );
    expect(current.selected, isTrue);
  });

  testWidgets('Settings sits on top of Home, so back returns there', (
    tester,
  ) async {
    await pumpFullApp(tester, locale: english);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(AppRouter.router.state.uri.path, '/settings');
    expect(AppRouter.router.canPop(), isTrue);
    final back = MaterialLocalizations.of(
      tester.element(find.byType(SettingsScreen)),
    ).backButtonTooltip;
    await tester.tap(find.byTooltip(back));
    await tester.pumpAndSettle();
    expect(AppRouter.router.state.uri.path, '/');
  });

  testWidgets('a direct link to Settings still has a way back', (tester) async {
    await pumpFullApp(tester, locale: english);
    AppRouter.router.go('/settings');
    await tester.pumpAndSettle();
    expect(AppRouter.router.canPop(), isTrue);
  });

  for (final language in kSupportedLanguages) {
    testWidgets('Settings fits at 320 wide in ${language.englishName}', (
      tester,
    ) async {
      await pumpFullApp(
        tester,
        size: const Size(320, 640),
        locale: Locale(language.locale),
      );
      AppRouter.router.go('/settings');
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
