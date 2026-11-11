import 'package:flutter/material.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_agentify_ui/flutter_agentify_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets(
    'shows the system text, tool names and last calls from the snapshot',
    (tester) async {
      final f = ChatFixture([
        ScriptedStep.toolCalls([call('c1', 'echo', '{"text":"ping"}')]),
        ScriptedStep.text('ok'),
      ]);
      await f.controller.open();
      await f.controller.send('Go');
      await tester.pumpWidget(_app(AssistantInspector(session: f.session)));
      expect(find.text('System text'), findsOneWidget);
      expect(find.textContaining('<current-screen> block'), findsOneWidget);
      expect(find.text('Active tools'), findsOneWidget);
      expect(find.textContaining('wipe'), findsWidgets);
      expect(find.text('Last tool calls'), findsOneWidget);
      expect(find.textContaining('"ping"'), findsOneWidget);
    },
  );

  testWidgets('shows a placeholder before the first run', (tester) async {
    final f = ChatFixture([]);
    await tester.pumpWidget(_app(AssistantInspector(session: f.session)));
    expect(
      find.text('Nothing to show yet. Send a message first.'),
      findsOneWidget,
    );
    expect(find.text('System text'), findsNothing);
  });

  testWidgets('the chat shows the inspector button only when inspect is set', (
    tester,
  ) async {
    final f = ChatFixture([]);
    await f.controller.open();
    await tester.pumpWidget(_app(AssistantChat(controller: f.controller)));
    expect(find.byTooltip('Open the inspector'), findsNothing);

    await tester.pumpWidget(
      _app(AssistantChat(controller: f.controller, inspect: f.session)),
    );
    expect(find.byTooltip('Open the inspector'), findsOneWidget);
    await tester.tap(find.byTooltip('Open the inspector'));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantInspector), findsOneWidget);
  });
}
