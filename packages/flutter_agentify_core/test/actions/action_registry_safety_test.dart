import 'dart:async';

import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:test/test.dart';

import 'fake_action.dart';

Matcher _failure(String code) =>
    throwsA(isA<ActionFailure>().having((f) => f.code, 'code', code));

class _Throwing extends FakeAction {
  _Throwing() : super('risky');

  @override
  bool needsApproval(String input) => throw StateError('boom');
}

void main() {
  test('a slow action sees its token cancelled after the timeout', () async {
    CancelToken? seen;
    final release = Completer<void>();
    final r = ActionRegistry([
      FakeAction(
        'slow',
        timeout: const Duration(milliseconds: 20),
        run: (_, context) async {
          seen = context.cancel;
          await release.future;
          return 'late';
        },
      ),
    ]);
    await expectLater(
      r.call('slow', {'text': 'x'}, caller: Caller.cli),
      _failure('timeout'),
    );
    expect(seen!.isCancelled, isTrue);
    release.complete();
  });

  test("the caller's cancel reaches the action's token", () async {
    final caller = CancelToken();
    final started = Completer<CancelToken>();
    final release = Completer<void>();
    final r = ActionRegistry([
      FakeAction(
        'slow',
        run: (_, context) async {
          started.complete(context.cancel);
          await release.future;
          return 'x';
        },
      ),
    ]);
    final call = r.call(
      'slow',
      {'text': 'x'},
      caller: Caller.cli,
      cancel: caller,
    );
    final token = await started.future;
    expect(token.isCancelled, isFalse);
    caller.cancel();
    await pumpEventQueue();
    expect(token.isCancelled, isTrue);
    release.complete();
    await call;
  });

  test('a failure after a partial write carries the receipts', () async {
    final r = ActionRegistry([
      FakeAction(
        'half',
        run: (_, context) async {
          context.receipt(resource: 'notes', ids: ['a'], summary: 'Saved a');
          throw const ActionFailure('partial', '1 of 2 saved');
        },
      ),
    ]);
    await expectLater(
      r.call('half', {'text': 'x'}, caller: Caller.cli),
      throwsA(
        isA<ActionFailure>().having((f) => f.code, 'code', 'partial').having(
          (f) => f.receipts.single.ids,
          'ids',
          ['a'],
        ),
      ),
    );
  });

  test('a thrown ActionFailure is redacted and cut', () async {
    final key = 'sk-${'a' * 30}';
    final r = ActionRegistry([
      FakeAction(
        'leaky',
        run: (_, _) async => throw ActionFailure(
          'bad',
          'key $key ${'z' * 5000}',
          details: {'value': key, 'n': 1},
        ),
      ),
    ]);
    try {
      await r.call('leaky', {'text': 'x'}, caller: Caller.cli);
      fail('should throw');
    } on ActionFailure catch (f) {
      expect(f.message, isNot(contains(key)));
      expect(f.message.length, lessThan(1100));
      expect(f.details!['value'], isNot(contains(key)));
      expect(f.details!['n'], 1);
    }
  });

  test('a throwing needsApproval fails closed', () async {
    final r = ActionRegistry([_Throwing()]);
    expect(r.requiresApproval('risky', {'text': 'x'}), isTrue);
    expect(r.requiresApproval('risky', {'nope': 1}), isFalse);
    await expectLater(
      r.call('risky', {'text': 'x'}, caller: Caller.assistant),
      _failure('approval_required'),
    );
  });

  test('run refuses the assistant for a UI-only action', () async {
    final action = FakeAction('ui_only', agentTool: false);
    final r = ActionRegistry([action]);
    await expectLater(
      r.run(action, 'x', caller: Caller.assistant),
      _failure('unknown_action'),
    );
    expect(await r.run(action, 'x'), 'x');
  });

  test('dispose closes the change stream', () async {
    final r = ActionRegistry([echo()]);
    final done = r.changes.isEmpty;
    await r.dispose();
    expect(await done, isTrue);
  });
}
