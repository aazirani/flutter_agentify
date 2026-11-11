import 'package:flutter/material.dart';
import 'package:flutter_agentify/data/repositories/prefs_settings_repository.dart';
import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/domain/actions/app_actions.dart';
import 'package:flutter_agentify/domain/entities/app_theme_mode.dart';
import 'package:flutter_agentify/domain/entities/assistant_settings.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_agentify_ui/flutter_agentify_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

ToolCall _call(String name, String json) =>
    ToolCall(id: 'c_$name', name: name, rawArguments: json);

void main() {
  testWidgets('set_theme_mode from the chat switches the app to dark', (
    tester,
  ) async {
    await pumpFullApp(
      tester,
      locale: english,
      provider: ScriptedProvider([
        ScriptedStep.toolCalls([_call('set_theme_mode', '{"mode":"dark"}')]),
        ScriptedStep.text('Dark it is.'),
      ]),
    );
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
    await openAssistant(tester);
    await sendToAssistant(tester, 'Dark mode please');
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });

  testWidgets(
    'switching the theme from the chat keeps the reply going with saved settings',
    (tester) async {
      SharedPreferences.setMockInitialValues({'assistant_model': 'test'});
      final settings = PrefsSettingsRepository(
        await SharedPreferences.getInstance(),
      );
      await pumpFullApp(
        tester,
        locale: english,
        settings: settings,
        provider: ScriptedProvider([
          ScriptedStep.toolCalls([_call('set_theme_mode', '{"mode":"dark"}')]),
          ScriptedStep.text('Dark it is.'),
        ]),
      );
      await openAssistant(tester);
      await sendToAssistant(tester, 'Dark mode please');
      expect(settings.getThemeMode(), AppThemeMode.dark);
      expect(find.text('Dark it is.'), findsOneWidget);
    },
  );

  testWidgets('saving another model mid-reply stops that reply cleanly', (
    tester,
  ) async {
    final provider = ScriptedProvider([ScriptedStep.hang()]);
    await pumpFullApp(tester, locale: english, provider: provider);
    await openAssistant(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(AssistantChat),
        matching: find.byType(TextField),
      ),
      'Hi',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    final getIt = ServiceLocator.getIt;
    await getIt<ActionRegistry>().run(
      getIt<AppActions>().setAssistantProvider,
      const AssistantSettings(model: 'other'),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an unreachable server shows an error and the composer still works',
    (tester) async {
      await pumpFullApp(
        tester,
        locale: english,
        provider: ScriptedProvider([
          ScriptedStep.error(
            const LlmError(
              'The connection failed: Connection refused',
              kind: LlmErrorKind.connection,
            ),
          ),
          ScriptedStep.text('Back online.'),
        ]),
      );
      const message =
          "Can't reach the model server. Check that it is running and that "
          'its address in Settings is right.';
      await openAssistant(tester);
      await sendToAssistant(tester, 'Hello?');
      expect(find.text(message), findsOneWidget);
      expect(find.textContaining('Connection refused'), findsNothing);
      await sendToAssistant(tester, 'Hello again');
      expect(find.text('Back online.'), findsOneWidget);
      expect(find.text(message), findsNothing);
    },
  );

  testWidgets('the chat keeps its messages after going to settings and back', (
    tester,
  ) async {
    await pumpFullApp(
      tester,
      locale: english,
      provider: ScriptedProvider([ScriptedStep.text('Hello there.')]),
    );
    await openAssistant(tester);
    await sendToAssistant(tester, 'Hi');
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Hello there.'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Hello there.'), findsOneWidget);
  });

  testWidgets('save_memory waits for approval; approving stores the memory', (
    tester,
  ) async {
    await pumpFullApp(
      tester,
      locale: english,
      provider: ScriptedProvider([
        ScriptedStep.toolCalls([
          _call('save_memory', '{"text":"Prefers dark mode"}'),
        ]),
        ScriptedStep.text('Noted.'),
      ]),
    );
    final memories = ServiceLocator.getIt<MemoryStore>();
    await openAssistant(tester);
    await sendToAssistant(tester, 'Remember I prefer dark mode');
    expect(find.text('Approve this action?'), findsOneWidget);
    expect(await memories.all(), isEmpty);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect((await memories.all()).single.text, 'Prefers dark mode');
    expect(
      find.widgetWithText(Chip, 'Remembered: Prefers dark mode'),
      findsOneWidget,
    );
  });
}
