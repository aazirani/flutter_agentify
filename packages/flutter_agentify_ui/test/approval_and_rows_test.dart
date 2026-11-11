import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_agentify_ui/flutter_agentify_ui.dart';
import 'package:flutter_agentify_ui/src/widgets/approval_card.dart';
import 'package:flutter_agentify_ui/src/widgets/tool_row.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('a long argument is clamped and the buttons stay visible', (
    tester,
  ) async {
    var approved = 0;
    await tester.pumpWidget(
      _app(
        ApprovalCard(
          approval: PendingApproval(
            callId: 'c1',
            action: 'wipe',
            args: {'description': List.filled(3000, 'word').join(' ')},
          ),
          strings: const AssistantStrings(),
          onApprove: () => approved++,
          onAlwaysAllow: () {},
          onReject: () {},
        ),
      ),
    );
    expect(tester.getSize(find.byType(Card)).height, lessThan(300));
    await tester.tap(find.text('Approve'));
    expect(approved, 1);
  });

  testWidgets('null callbacks disable the buttons', (tester) async {
    await tester.pumpWidget(
      _app(
        const ApprovalCard(
          approval: PendingApproval(callId: 'c1', action: 'wipe', args: {}),
          strings: AssistantStrings(),
          onApprove: null,
          onAlwaysAllow: null,
          onReject: null,
        ),
      ),
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
  });

  testWidgets('a long tool label does not hide the failure', (tester) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 200,
          child: ToolRow(
            tool: ToolRowData(
              callId: 'c1',
              name: List.filled(40, 'archive').join('_'),
              isError: true,
            ),
            strings: const AssistantStrings(),
          ),
        ),
      ),
    );
    expect(find.textContaining('Failed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a loop-limit tool reads Stopped, not Failed', (tester) async {
    await tester.pumpWidget(
      _app(
        const ToolRow(
          tool: ToolRowData(
            callId: 'c1',
            name: 'wipe',
            isError: true,
            errorCode: 'loop_limit',
          ),
          strings: AssistantStrings(),
        ),
      ),
    );
    expect(find.text(' · Stopped'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('download progress ticks are not re-announced', (tester) async {
    final handle = tester.ensureSemantics();
    ModelStatus status(int received) => ModelStatus(
      answeredBy: AnsweredBy.none,
      state: ModelDownloading(received, 1000),
    );
    Future<void> pump(int received) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModelStatusView(
            status: status(received),
            strings: const AssistantStrings(),
          ),
        ),
      ),
    );
    String announced() {
      final node = tester.getSemantics(find.byType(ModelStatusView));
      final label = StringBuffer();
      void walk(SemanticsNode n) {
        if (n.getSemanticsData().flagsCollection.isLiveRegion) {
          label.write(n.label);
        }
        n.visitChildren((c) {
          walk(c);
          return true;
        });
      }

      walk(node);
      return label.toString();
    }

    await pump(100);
    final first = announced();
    await pump(500);
    expect(first, isNotEmpty);
    expect(announced(), first);
    handle.dispose();
  });

  test('a second tap on a resolved approval is ignored', () async {
    final f = ChatFixture([
      ScriptedStep.toolCalls([call('c1', 'wipe', '{"folder":"drafts"}')]),
      ScriptedStep.text('Emptied.'),
    ]);
    await f.controller.open();
    var answered = false;
    f.controller.addListener(() {
      final approval = f.controller.pendingApproval;
      if (approval == null || answered) return;
      answered = true;
      scheduleMicrotask(() {
        expect(f.controller.approve(approval.callId), isNull);
        // The double tap, and a card for a call that never existed.
        expect(f.controller.approve(approval.callId), isNull);
        f.controller.reject('nope');
      });
    });
    await f.controller.send('Empty drafts');
    expect(f.wipe.wiped, ['drafts']);
  });
}
