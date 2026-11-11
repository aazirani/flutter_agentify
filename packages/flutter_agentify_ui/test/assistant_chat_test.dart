import 'package:flutter/material.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_agentify_ui/flutter_agentify_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

Future<void> _pump(
  WidgetTester tester,
  ChatFixture f, {
  AssistantStrings strings = const AssistantStrings(),
  TextDirection direction = TextDirection.ltr,
}) async {
  await f.controller.open();
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: AssistantChat(controller: f.controller, strings: strings),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

Future<void> _tapSend(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Send'));
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('typing and tapping send shows the message and the reply', (
    tester,
  ) async {
    final f = ChatFixture([ScriptedStep.text('Hello from the assistant')]);
    await _pump(tester, f);
    expect(find.text('How can I help?'), findsOneWidget);
    await _type(tester, 'Hi there');
    await _tapSend(tester);
    expect(find.text('Hi there'), findsOneWidget);
    expect(find.text('Hello from the assistant'), findsOneWidget);
    expect(find.text('How can I help?'), findsNothing);
  });

  testWidgets('the stop button is shown while running and stops the run', (
    tester,
  ) async {
    final f = ChatFixture([ScriptedStep.hang()]);
    await _pump(tester, f);
    await _type(tester, 'Hi');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(find.byTooltip('Stop'), findsOneWidget);
    expect(find.byTooltip('Send'), findsNothing);
    await tester.tap(find.byTooltip('Stop'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Send'), findsOneWidget);
    expect(find.text('Stopped.'), findsOneWidget);
    expect(f.controller.isRunning, isFalse);
  });

  testWidgets('the approval card approves and rejects', (tester) async {
    final f = ChatFixture([
      ScriptedStep.toolCalls([call('c1', 'wipe', '{"folder":"drafts"}')]),
      ScriptedStep.toolCalls([call('c2', 'wipe', '{"folder":"old"}')]),
      ScriptedStep.text('Done.'),
    ]);
    await _pump(tester, f);
    await _type(tester, 'Clean up');
    await _tapSend(tester);
    expect(find.text('Approve this action?'), findsOneWidget);
    expect(find.text('Wipe'), findsWidgets);
    expect(find.text('wipe'), findsNothing);
    expect(find.text('folder: drafts'), findsOneWidget);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(find.text('folder: old'), findsOneWidget);
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    expect(find.text('Approve this action?'), findsNothing);
    expect(f.wipe.wiped, ['drafts']);
    expect(find.text('Done.'), findsOneWidget);
  });

  testWidgets('receipt chips show the receipt summary', (tester) async {
    final f = ChatFixture([
      ScriptedStep.toolCalls([call('c1', 'wipe', '{"folder":"drafts"}')]),
      ScriptedStep.text('Emptied.'),
    ]);
    await _pump(tester, f);
    await _type(tester, 'Clean up');
    await _tapSend(tester);
    await tester.tap(find.text('Always allow'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Chip, 'Emptied drafts'), findsOneWidget);
    expect(f.session.approvals.isAlwaysAllowed('wipe'), isTrue);
  });

  testWidgets(
    'the card shows the summary and hides Always allow when not allowed',
    (tester) async {
      final f = ChatFixture([
        ScriptedStep.toolCalls([call('c1', 'wipe', '{"folder":"drafts"}')]),
        ScriptedStep.text('Done.'),
      ], wipe: WipeAction(summary: 'Milk', allowAlways: false));
      await _pump(tester, f);
      await _type(tester, 'Clean up');
      await _tapSend(tester);
      expect(find.text('Approve this action?'), findsOneWidget);
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text(const AssistantStrings().alwaysAllow), findsNothing);
      // The summary says what it does; the arguments wait behind Details.
      expect(find.text('folder: drafts'), findsNothing);
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(find.text('folder: drafts'), findsOneWidget);
    },
  );

  testWidgets('the summary is one tidy line of text', (tester) async {
    final f = ChatFixture([
      ScriptedStep.toolCalls([call('c1', 'wipe', '{"folder":"drafts"}')]),
      ScriptedStep.text('Done.'),
    ], wipe: WipeAction(summary: 'Milk\nfolder: drafts\nThis is safe'));
    await _pump(tester, f);
    await _type(tester, 'Clean up');
    await _tapSend(tester);
    expect(find.text('Milk folder: drafts This is safe'), findsOneWidget);
  });

  testWidgets('no overflow at 320 x 480 in right-to-left with a long summary', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final summary200 = ('A very long item title ' * 10).substring(0, 200);
    final f = ChatFixture([
      ScriptedStep.toolCalls([call('c1', 'wipe', '{"folder":"drafts"}')]),
      ScriptedStep.text('Done.'),
    ], wipe: WipeAction(summary: summary200));
    await _pump(tester, f, direction: TextDirection.rtl);
    await _type(tester, 'Clean up');
    await _tapSend(tester);
    expect(find.text(summary200), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the answer-only notice is shown', (tester) async {
    final f = ChatFixture([
      ScriptedStep.text('There are 3 items.'),
    ], model: const ModelConfig(model: 'tiny', toolCalling: false));
    await _pump(tester, f);
    expect(find.textContaining('cannot use the app'), findsOneWidget);
  });

  testWidgets(
    'an error shows with a retry button that resends the last message',
    (tester) async {
      final f = ChatFixture([
        ScriptedStep.error(
          const LlmError('Server down', status: 500, retryable: true),
        ),
        ScriptedStep.text('Back again.'),
      ], config: const AgentConfig(maxRetries: 0));
      await _pump(tester, f);
      await _type(tester, 'Hi');
      await _tapSend(tester);
      expect(find.text(const AssistantStrings().errorServer), findsOneWidget);
      expect(find.textContaining('Server down'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text(const AssistantStrings().errorServer), findsNothing);
      expect(find.text('Back again.'), findsOneWidget);
      expect(
        f.provider.requests.last.messages.whereType<UserMessage>().last.text,
        'Hi',
      );
    },
  );

  testWidgets('a loop limit shows its notice', (tester) async {
    final f = ChatFixture([
      ScriptedStep.toolCalls([call('c1', 'echo', '{"text":"a"}')]),
    ], config: const AgentConfig(maxSteps: 1));
    await _pump(tester, f);
    await _type(tester, 'Go');
    await _tapSend(tester);
    expect(
      find.text('Stopped: this reply took too many steps.'),
      findsOneWidget,
    );
  });

  testWidgets('the output limit shows its notice', (tester) async {
    final f = ChatFixture([ScriptedStep.text('Half an ans', truncated: true)]);
    await _pump(tester, f);
    await _type(tester, 'Go');
    await _tapSend(tester);
    expect(find.text(const AssistantStrings().limitOutput), findsOneWidget);
  });

  Future<void> busyChat(WidgetTester tester, TextDirection direction) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final f = ChatFixture([
      ScriptedStep.toolCalls([
        call('c1', 'echo', '{"text":"a long piece of text to repeat"}'),
        call(
          'c2',
          'wipe',
          '{"folder":"a folder with a rather long name indeed"}',
        ),
      ]),
      ScriptedStep.text('A long reply ' * 20),
    ], model: const ModelConfig(model: 'tiny', toolCalling: true));
    await _pump(tester, f, direction: direction);
    await _type(tester, 'Please do several things at once ' * 4);
    await _tapSend(tester);
    expect(find.text('Approve this action?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'no overflow at 320 x 480',
    (tester) => busyChat(tester, TextDirection.ltr),
  );

  testWidgets(
    'no overflow in right-to-left',
    (tester) => busyChat(tester, TextDirection.rtl),
  );

  testWidgets('works under an app theme with full-width buttons', (
    tester,
  ) async {
    const wide = Size(double.infinity, 48);
    final f = ChatFixture([
      ScriptedStep.toolCalls([call('c1', 'wipe', '{"folder":"a"}')]),
      ScriptedStep.error(
        const LlmError('Server down', status: 500, retryable: true),
      ),
    ], config: const AgentConfig(maxRetries: 0));
    await f.controller.open();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(minimumSize: wide),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(minimumSize: wide),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(minimumSize: wide),
          ),
        ),
        home: Scaffold(body: AssistantChat(controller: f.controller)),
      ),
    );
    await _type(tester, 'Clean up');
    await _tapSend(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Approve'), findsOneWidget);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('custom strings replace the defaults', (tester) async {
    final f = ChatFixture([ScriptedStep.text('ok')]);
    await _pump(
      tester,
      f,
      strings: const AssistantStrings(
        emptyTitle: 'Wie kann ich helfen?',
        inputHint: 'Frage',
        send: 'Senden',
      ),
    );
    expect(find.text('Wie kann ich helfen?'), findsOneWidget);
    expect(find.text('Frage'), findsOneWidget);
    expect(find.byTooltip('Senden'), findsOneWidget);
    expect(find.text('How can I help?'), findsNothing);
  });

  testWidgets('send is disabled for blank input', (tester) async {
    final f = ChatFixture([ScriptedStep.text('ok')]);
    await _pump(tester, f);
    IconButton sendButton() => tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.send),
        matching: find.byType(IconButton),
      ),
    );
    expect(sendButton().onPressed, isNull);
    await _type(tester, '   ');
    expect(sendButton().onPressed, isNull);
    await _type(tester, 'Hi');
    expect(sendButton().onPressed, isNotNull);
    expect(f.provider.requests, isEmpty);
  });
}
