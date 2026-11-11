import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_agentify/ai/assistant_providers.dart';
import 'package:flutter_agentify/domain/entities/language/supported_languages.dart';
import 'package:flutter_agentify/presentation/assistant/assistant_toggle_button.dart';
import 'package:flutter_agentify/utils/routes/app_router.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_agentify_ui/flutter_agentify_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_app.dart';

/// The non-empty strings in `assets/lang/<code>.json`.
List<String> _strings(String code) => [
  for (final value in (jsonDecode(
    File('assets/lang/$code.json').readAsStringSync(),
  ) as Map<String, Object?>).values)
    if (value is String && value.isNotEmpty) value,
];

void main() {
  testWidgets('at 1000 wide the chat is a side panel', (tester) async {
    await pumpFullApp(
      tester,
      locale: english,
      size: const Size(1000, 800),
      provider: ScriptedProvider([]),
    );
    expect(find.byType(AssistantChat), findsNothing);
    await openAssistant(tester);
    expect(find.byType(AssistantChat), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      tester.getSize(find.byType(AssistantChat)).width,
      lessThanOrEqualTo(380),
    );
  });

  testWidgets('at 320 wide the chat opens as a sheet without overflow', (
    tester,
  ) async {
    await pumpFullApp(
      tester,
      locale: english,
      size: const Size(320, 640),
      provider: ScriptedProvider([
        ScriptedStep.text(
          'A reply that is long enough to wrap over several lines on a small phone.',
        ),
      ]),
    );
    await openAssistant(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(AssistantChat), findsOneWidget);
    await sendToAssistant(tester, 'Tell me something long');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sheet becomes the side panel when the window grows', (
    tester,
  ) async {
    await pumpFullApp(
      tester,
      locale: english,
      size: const Size(400, 800),
      provider: ScriptedProvider([]),
    );
    await openAssistant(tester);
    expect(find.byType(BottomSheet), findsOneWidget);

    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(AssistantChat), findsOneWidget);
    // The page under the sheet is still there.
    expect(find.byType(AssistantToggleButton), findsWidgets);
  });

  testWidgets('with the panel already open, widening shows one chat', (
    tester,
  ) async {
    final container = await pumpFullApp(
      tester,
      locale: english,
      size: const Size(400, 800),
      provider: ScriptedProvider([]),
    );
    container.read(assistantPanelOpenProvider.notifier).toggle();
    await openAssistant(tester);
    expect(find.byType(BottomSheet), findsOneWidget);

    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(AssistantChat), findsOneWidget);
    expect(container.read(assistantPanelOpenProvider), isTrue);
  });

  testWidgets('the sheet has a drag handle, a title and a close button', (
    tester,
  ) async {
    await pumpFullApp(
      tester,
      locale: english,
      size: const Size(320, 640),
      provider: ScriptedProvider([]),
    );
    await openAssistant(tester);
    expect(
      tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
      isTrue,
    );
    expect(
      find.descendant(
        of: find.byType(AssistantChat),
        matching: find.text('Assistant'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('the panel closes from its own close button', (tester) async {
    await pumpFullApp(
      tester,
      locale: english,
      size: const Size(1000, 800),
      provider: ScriptedProvider([]),
    );
    await openAssistant(tester);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantChat), findsNothing);
  });

  testWidgets('the toggle shows a badge while an approval waits out of sight', (
    tester,
  ) async {
    await pumpFullApp(
      tester,
      locale: english,
      size: const Size(320, 640),
      provider: ScriptedProvider([
        ScriptedStep.toolCalls([
          ToolCall(
            id: 'c1',
            name: 'save_memory',
            rawArguments: '{"text":"Likes tea"}',
          ),
        ]),
        ScriptedStep.text('Saved.'),
      ]),
    );
    bool badge() => tester
        .widget<Badge>(
          find.descendant(
            of: find.byType(AssistantToggleButton),
            matching: find.byType(Badge),
          ),
        )
        .isLabelVisible;
    String? tooltip() => tester
        .widget<IconButton>(
          find.descendant(
            of: find.byType(AssistantToggleButton),
            matching: find.byType(IconButton),
          ),
        )
        .tooltip;
    await openAssistant(tester);
    await sendToAssistant(tester, 'Remember that I like tea');
    expect(find.text('Approve this action?'), findsOneWidget);
    expect(find.text('Remember a note'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(badge(), isTrue);
    expect(tooltip(), 'Assistant: an action waits for your approval');
    await openAssistant(tester);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(badge(), isFalse);
    expect(tooltip(), 'Assistant');
  });

  testWidgets('a model error offers Open settings, which goes to Settings', (
    tester,
  ) async {
    await pumpFullApp(
      tester,
      locale: english,
      size: const Size(320, 640),
      provider: ScriptedProvider([
        ScriptedStep.error(const LlmError('Unauthorized', status: 401)),
      ]),
    );
    await openAssistant(tester);
    await sendToAssistant(tester, 'Hi');
    expect(
      find.text(
        'The model server refused the API key. Check the key in Settings.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(AppRouter.router.state.uri.path, '/settings');
  });

  for (final language in kSupportedLanguages) {
    final code = language.locale;
    final rtl = rtlLanguageCodes.contains(code);
    testWidgets('in ${language.englishName} the layout is '
        '${rtl ? 'right-to-left' : 'left-to-right'} without overflow', (
      tester,
    ) async {
      final strings = _strings(code);
      await pumpFullApp(
        tester,
        size: const Size(320, 640),
        locale: Locale(code),
        provider: ScriptedProvider([
          // The language's longest string, so the reply wraps.
          ScriptedStep.text(
            strings.reduce((a, b) => a.length >= b.length ? a : b),
          ),
        ]),
      );
      expect(
        Directionality.of(tester.element(find.byType(Scaffold).first)),
        rtl ? TextDirection.rtl : TextDirection.ltr,
      );
      await openAssistant(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(AssistantChat),
          matching: find.byType(TextField),
        ),
        strings.first,
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('without a configured model the panel shows the setup message', (
    tester,
  ) async {
    await pumpFullApp(
      tester,
      locale: english,
      size: const Size(1000, 800),
      setup: const AssistantSetup(mode: ModelMode.server),
    );
    await openAssistant(tester);
    expect(find.text('Set up a model'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(AppRouter.router.state.uri.path, '/settings');
  });
}
