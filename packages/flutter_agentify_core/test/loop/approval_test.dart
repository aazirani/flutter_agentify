import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:test/test.dart';

import '../actions/fake_action.dart';
import 'loop_fixtures.dart';

void main() {
  late List<String> wiped;

  LoopFixture fixture(List<ScriptedStep> steps, {ApprovalPrefs? approvals}) {
    wiped = [];
    return LoopFixture(
      steps,
      approvals: approvals,
      actions: [
        echo(),
        FakeAction(
          'wipe',
          approval: true,
          run: (text, _) async {
            wiped.add(text);
            return 'wiped $text';
          },
        ),
      ],
    );
  }

  /// Runs [f] and answers each approval request with [decide].
  Future<List<AgentEvent>> runAnswering(
    LoopFixture f,
    ApprovalDecision? Function(ApprovalRequired request) decide,
  ) async => listen(f.session.send(await f.threadId, 'Go'), (e) {
    if (e is ApprovalRequired) {
      final decision = decide(e);
      if (decision != null) {
        expect(f.session.resolveApproval(e.callId, decision), isNull);
      }
    }
  });

  test(
    'a needsApproval call pauses with ApprovalRequired and does not run',
    () async {
      final f = fixture([
        ScriptedStep.toolCalls([
          call('c1', 'wipe', {'text': 'all'}),
        ]),
        ScriptedStep.text('ok'),
      ]);
      ApprovalRequired? seen;
      final events = await runAnswering(f, (request) {
        seen = request;
        expect(wiped, isEmpty);
        expect(f.session.isRunning, isTrue);
        return const Reject();
      });
      expect(seen?.callId, 'c1');
      expect(seen?.action, 'wipe');
      expect(seen?.args, {'text': 'all'});
      expect(events.last, isA<Done>());
    },
  );

  test('Approve runs the action and the run continues to Done', () async {
    final f = fixture([
      ScriptedStep.toolCalls([
        call('c1', 'wipe', {'text': 'all'}),
      ]),
      ScriptedStep.text('Wiped.'),
    ]);
    final events = await runAnswering(f, (_) => const Approve());
    expect(wiped, ['all']);
    final finished = events.whereType<ToolFinished>().single;
    expect(finished.isError, isFalse);
    expect(finished.content, '"wiped all"');
    expect(events.last, isA<Done>());
  });

  test(
    'Reject sends a declined result to the model and the action never runs',
    () async {
      final f = fixture([
        ScriptedStep.toolCalls([
          call('c1', 'wipe', {'text': 'all'}),
        ]),
        ScriptedStep.text('Okay, I left it.'),
      ]);
      final events = await runAnswering(f, (_) => const Reject());
      expect(wiped, isEmpty);
      final finished = events.whereType<ToolFinished>().single;
      expect(finished.isError, isTrue);
      expect(finished.errorCode, 'declined');
      expect(
        finished.content,
        '{"error":"declined","message":"The user declined this action."}',
      );
      final sent = f.provider.requests[1].messages.last as ToolResultMessage;
      expect(sent.content, contains('declined'));
      expect(events.last, isA<Done>());
    },
  );

  test('Edit runs the action with the edited arguments', () async {
    final f = fixture([
      ScriptedStep.toolCalls([
        call('c1', 'wipe', {'text': 'all'}),
      ]),
      ScriptedStep.text('ok'),
    ]);
    await runAnswering(f, (_) => const Edit({'text': 'drafts'}));
    expect(wiped, ['drafts']);
  });

  test(
    'Edit with invalid arguments returns a message and stays pending',
    () async {
      final f = fixture([
        ScriptedStep.toolCalls([
          call('c1', 'wipe', {'text': 'all'}),
        ]),
        ScriptedStep.text('ok'),
      ]);
      final events = await listen(f.session.send(await f.threadId, 'Go'), (e) {
        if (e is ApprovalRequired) {
          final message = f.session.resolveApproval(
            e.callId,
            const Edit({'text': 3}),
          );
          expect(message, contains(r'$.text'));
          expect(wiped, isEmpty);
          expect(f.session.resolveApproval(e.callId, const Approve()), isNull);
        }
      });
      expect(wiped, ['all']);
      expect(events.last, isA<Done>());
    },
  );

  test('Edit with a value the action cannot parse returns a message and '
      'stays pending', () async {
    final f = LoopFixture(
      [
        ScriptedStep.toolCalls([
          call('c1', 'book', {'date': '2026-01-01'}),
        ]),
        ScriptedStep.text('ok'),
      ],
      actions: [BookAction()],
    );
    final events = await listen(f.session.send(await f.threadId, 'Go'), (e) {
      if (e is ApprovalRequired) {
        const edit = Edit({'date': 'soon'});
        expect(f.session.resolveApproval(e.callId, edit), isNotNull);
        expect(f.session.resolveApproval(e.callId, const Approve()), isNull);
      }
    });
    expect(events.last, isA<Done>());
  });

  test('Approve(always: true) saves the preference; the next call does not '
      'pause', () async {
    final prefs = InMemoryApprovalPrefs();
    final f = fixture([
      ScriptedStep.toolCalls([
        call('c1', 'wipe', {'text': 'a'}),
      ]),
      ScriptedStep.toolCalls([
        call('c2', 'wipe', {'text': 'b'}),
      ]),
      ScriptedStep.text('ok'),
    ], approvals: prefs);
    var asked = 0;
    await runAnswering(f, (_) {
      asked++;
      return const Approve(always: true);
    });
    expect(asked, 1);
    expect(prefs.isAlwaysAllowed('wipe'), isTrue);
    expect(wiped, ['a', 'b']);
  });

  test('an always-allowed action does not pause', () async {
    final prefs = InMemoryApprovalPrefs();
    await prefs.setAlwaysAllowed('wipe', true);
    final f = fixture([
      ScriptedStep.toolCalls([
        call('c1', 'wipe', {'text': 'a'}),
      ]),
      ScriptedStep.text('ok'),
    ], approvals: prefs);
    final events = await f.send('Go');
    expect(events.whereType<ApprovalRequired>(), isEmpty);
    expect(wiped, ['a']);
  });

  test(
    'answering the same approval twice does nothing the second time',
    () async {
      final f = fixture([
        ScriptedStep.toolCalls([
          call('c1', 'wipe', {'text': 'all'}),
        ]),
        ScriptedStep.text('ok'),
      ]);
      final events = await runAnswering(f, (e) {
        expect(f.session.resolveApproval(e.callId, const Approve()), isNull);
        return const Approve();
      });
      expect(events.last, isA<Done>());
      expect(wiped, ['all']);
    },
  );

  test('resolveApproval with an unknown callId does nothing', () {
    final f = fixture([]);
    expect(f.session.resolveApproval('nope', const Approve()), isNull);
  });

  test('cancel while an approval is pending ends with Cancelled and the '
      'thread stays valid', () async {
    final f = fixture([
      ScriptedStep.toolCalls([
        call('c1', 'wipe', {'text': 'all'}),
      ]),
      ScriptedStep.text('never'),
    ]);
    final events = await runAnswering(f, (_) {
      f.session.cancel();
      return null;
    });
    expect(events.last, isA<Cancelled>());
    expect(wiped, isEmpty);
    await f.expectThreadValid();
    expect(f.session.resolveApproval('c1', const Approve()), isNull);
  });

  test('stopping while the approval card shows runs nothing', () async {
    final f = fixture([
      ScriptedStep.toolCalls([
        call('c1', 'wipe', {'text': 'all'}),
      ]),
      ScriptedStep.text('ok'),
    ]);
    final events = await runAnswering(f, (_) {
      f.session.cancel();
      return null;
    });
    final actionRan = wiped.isNotEmpty;
    expect(actionRan, isFalse);
    expect(events.last, isA<Cancelled>());
    expect((await f.send('Again')).last, isA<Done>());
  });

  test('stopping while the approval card loads shows no card', () async {
    late LoopFixture f;
    wiped = [];
    f = LoopFixture(
      [
        ScriptedStep.toolCalls([
          call('c1', 'wipe', {'text': 'all'}),
        ]),
        ScriptedStep.text('never'),
      ],
      actions: [
        FakeAction(
          'wipe',
          approval: true,
          summary: (_) async {
            f.session.cancel();
            return 'all';
          },
          run: (text, _) async {
            wiped.add(text);
            return 'wiped $text';
          },
        ),
      ],
    );
    final events = await f.send('Go');
    expect(events.whereType<ApprovalRequired>(), isEmpty);
    expect(events.last, isA<Cancelled>());
    expect(wiped, isEmpty);
    expect((await f.send('Again')).last, isA<Done>());
  });

  test('a second tool call in the same step waits until the first approval '
      'is resolved', () async {
    final f = fixture([
      ScriptedStep.toolCalls([
        call('c1', 'wipe', {'text': 'a'}),
        call('c2', 'echo', {'text': 'b'}),
      ]),
      ScriptedStep.text('ok'),
    ]);
    final order = <String>[];
    final events = await listen(f.session.send(await f.threadId, 'Go'), (e) {
      switch (e) {
        case ApprovalRequired():
          order.add('approval ${e.callId}');
          Future<void>.delayed(const Duration(milliseconds: 20), () {
            order.add('approve');
            f.session.resolveApproval(e.callId, const Approve());
          });
        case ToolStarted():
          order.add('start ${e.callId}');
        default:
      }
    });
    expect(order, ['approval c1', 'approve', 'start c1', 'start c2']);
    expect(events.last, isA<Done>());
  });

  group('an action that does not allow always-allow', () {
    LoopFixture strict(List<ScriptedStep> steps, ApprovalPrefs prefs) {
      wiped = [];
      return LoopFixture(
        steps,
        approvals: prefs,
        actions: [
          FakeAction(
            'wipe',
            approval: true,
            allowAlways: false,
            summary: (text) async => 'Wipe "$text"',
            run: (text, _) async {
              wiped.add(text);
              return 'wiped $text';
            },
          ),
        ],
      );
    }

    test(
      'always allow is ignored for an action that does not allow it',
      () async {
        final prefs = InMemoryApprovalPrefs();
        final f = strict([
          ScriptedStep.toolCalls([
            call('c1', 'wipe', {'text': 'a'}),
          ]),
          ScriptedStep.toolCalls([
            call('c2', 'wipe', {'text': 'b'}),
          ]),
          ScriptedStep.text('ok'),
        ], prefs);
        final events = await runAnswering(
          f,
          (_) => const Approve(always: true),
        );
        expect(prefs.isAlwaysAllowed('wipe'), isFalse);
        expect(events.whereType<ApprovalRequired>(), hasLength(2));
        expect(wiped, ['a', 'b']);
      },
    );

    test('a stored always-allow is ignored for such an action', () async {
      final prefs = InMemoryApprovalPrefs();
      await prefs.setAlwaysAllowed('wipe', true);
      final f = strict([
        ScriptedStep.toolCalls([
          call('c1', 'wipe', {'text': 'a'}),
        ]),
        ScriptedStep.text('ok'),
      ], prefs);
      final events = await runAnswering(f, (_) => const Approve());
      expect(events.whereType<ApprovalRequired>(), hasLength(1));
    });

    test('the request carries the summary and the allowAlways flag', () async {
      final f = strict([
        ScriptedStep.toolCalls([
          call('c1', 'wipe', {'text': 'Milk'}),
        ]),
        ScriptedStep.text('ok'),
      ], InMemoryApprovalPrefs());
      final events = await runAnswering(f, (_) => const Reject());
      final request = events.whereType<ApprovalRequired>().single;
      expect(request.summary, 'Wipe "Milk"');
      expect(request.allowAlways, isFalse);
    });
  });

  test('the request has no summary and allows always by default', () async {
    final f = fixture([
      ScriptedStep.toolCalls([
        call('c1', 'wipe', {'text': 'all'}),
      ]),
      ScriptedStep.text('ok'),
    ]);
    final events = await runAnswering(f, (_) => const Reject());
    final request = events.whereType<ApprovalRequired>().single;
    expect(request.summary, isNull);
    expect(request.allowAlways, isTrue);
  });

  test('clear forgets every always-allow', () async {
    final prefs = InMemoryApprovalPrefs();
    await prefs.setAlwaysAllowed('a', true);
    await prefs.clear();
    expect(prefs.isAlwaysAllowed('a'), isFalse);
  });

  group('approvalInfo', () {
    final registry = ActionRegistry([
      FakeAction('plain', approval: true),
      FakeAction(
        'strict',
        approval: true,
        allowAlways: false,
        summary: (text) async => 'About $text',
      ),
      FakeAction(
        'broken',
        approval: true,
        summary: (_) async => throw StateError('no'),
      ),
    ]);

    test('gives the action\'s flag and summary', () async {
      final info = await registry.approvalInfo('strict', {'text': 'x'});
      expect(info.allowAlways, isFalse);
      expect(info.summary, 'About x');
      final plain = await registry.approvalInfo('plain', {'text': 'x'});
      expect(plain.allowAlways, isTrue);
      expect(plain.summary, isNull);
    });

    test('never throws', () async {
      for (final (name, input) in [
        ('missing', {'text': 'x'}),
        ('plain', {'text': 3}),
        ('broken', {'text': 'x'}),
      ]) {
        final info = await registry.approvalInfo(name, input);
        expect(info.allowAlways, isFalse, reason: name);
        expect(info.summary, isNull, reason: name);
      }
    });
  });
}
