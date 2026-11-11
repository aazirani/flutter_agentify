import 'dart:async';

import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_agentify_ui/flutter_agentify_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  test('open loads stored messages as items', () async {
    final f = ChatFixture([]);
    final thread = await f.threads.createThread();
    const receipt = Receipt(
      resource: 'notes',
      ids: ['a'],
      summary: 'Emptied a',
    );
    for (final message in [
      StoredMessage(
        UserMessage(
          'Empty a',
          context: '<current-screen>\n{}\n</current-screen>',
        ),
      ),
      StoredMessage(
        AssistantMessage(
          'On it.',
          toolCalls: [call('c1', 'wipe', '{"folder":"a"}')],
        ),
      ),
      StoredMessage(
        ToolResultMessage(callId: 'c1', name: 'wipe', content: '"done"'),
      ),
      StoredMessage(AssistantMessage('Emptied.'), receipts: const [receipt]),
    ]) {
      await f.threads.append(thread.id, message);
    }
    await f.controller.open(threadId: thread.id);
    final items = f.controller.items;
    expect(items, hasLength(2));
    expect((items[0] as UserItem).text, 'Empty a');
    final reply = items[1] as AssistantItem;
    expect(reply.text, 'On it.\n\nEmptied.');
    expect(reply.tools.single.name, 'wipe');
    expect(reply.tools.single.running, isFalse);
    expect(reply.receipts.single.summary, 'Emptied a');
  });

  test('open without an id uses the newest thread, or creates one', () async {
    final f = ChatFixture([]);
    await f.controller.open();
    expect(await f.threads.threads(), hasLength(1));
    await f.controller.open();
    expect(await f.threads.threads(), hasLength(1));
  });

  test(
    'send adds a user item, streams assistant text, ends not running',
    () async {
      final f = ChatFixture([ScriptedStep.text('Hello!')]);
      await f.controller.open();
      final running = <bool>[];
      f.controller.addListener(() => running.add(f.controller.isRunning));
      await f.controller.send('Hi');
      expect(running, contains(true));
      expect(f.controller.isRunning, isFalse);
      expect((f.controller.items[0] as UserItem).text, 'Hi');
      expect(f.lastAssistant.text, 'Hello!');
    },
  );

  test(
    'a tool call shows a running row, then a finished row, then a receipt',
    () async {
      final f = ChatFixture([
        ScriptedStep.toolCalls([call('c1', 'echo', '{"text":"x"}')]),
        ScriptedStep.text('ok'),
      ]);
      await f.controller.open();
      final rows = <String>[];
      f.controller.addListener(() {
        final items = f.controller.items.whereType<AssistantItem>();
        if (items.isEmpty || items.last.tools.isEmpty) return;
        rows.add(items.last.tools.single.running ? 'running' : 'finished');
      });
      await f.controller.send('Go');
      expect(rows.first, 'running');
      expect(rows.last, 'finished');
      expect(f.lastAssistant.tools.single.isError, isFalse);
    },
  );

  test(
    'ApprovalRequired sets approval on the assistant item; approve clears it',
    () async {
      final f = ChatFixture([
        ScriptedStep.toolCalls([call('c1', 'wipe', '{"folder":"drafts"}')]),
        ScriptedStep.text('Emptied.'),
      ]);
      await f.controller.open();
      PendingApproval? seen;
      f.controller.addListener(() {
        final approval = f.controller.items
            .whereType<AssistantItem>()
            .lastOrNull
            ?.approval;
        if (approval != null && seen == null) {
          seen = approval;
          scheduleMicrotask(
            () => expect(f.controller.approve(approval.callId), isNull),
          );
        }
      });
      await f.controller.send('Empty drafts');
      expect(seen?.action, 'wipe');
      expect(seen?.args, {'folder': 'drafts'});
      expect(f.lastAssistant.approval, isNull);
      expect(f.wipe.wiped, ['drafts']);
      expect(f.lastAssistant.receipts.single.summary, 'Emptied drafts');
    },
  );

  test('reject clears the approval and the run continues', () async {
    final f = ChatFixture([
      ScriptedStep.toolCalls([call('c1', 'wipe', '{"folder":"drafts"}')]),
      ScriptedStep.text('Left it.'),
    ]);
    await f.controller.open();
    f.controller.addListener(() {
      final approval = f.controller.items
          .whereType<AssistantItem>()
          .lastOrNull
          ?.approval;
      if (approval != null)
        scheduleMicrotask(() => f.controller.reject(approval.callId));
    });
    await f.controller.send('Empty drafts');
    expect(f.wipe.wiped, isEmpty);
    expect(f.lastAssistant.approval, isNull);
    expect(f.lastAssistant.text, 'Left it.');
    expect(f.lastAssistant.tools.single.isError, isTrue);
  });

  test('approve with invalid edited arguments returns the message and keeps the card', () async {
    final f = ChatFixture([
      ScriptedStep.toolCalls([call('c1', 'wipe', '{"folder":"drafts"}')]),
      ScriptedStep.text('ok'),
    ]);
    await f.controller.open();
    var answered = false;
    f.controller.addListener(() {
      final approval = f.controller.items
          .whereType<AssistantItem>()
          .lastOrNull
          ?.approval;
      if (approval == null || answered) return;
      answered = true;
      scheduleMicrotask(() {
        final message = f.controller.approve(
          approval.callId,
          editedArgs: {'folder': 3},
        );
        expect(message, contains(r'$.folder'));
        expect(f.lastAssistant.approval, isNotNull);
        f.controller.approve(approval.callId, editedArgs: {'folder': 'old'});
      });
    });
    await f.controller.send('Empty drafts');
    expect(f.wipe.wiped, ['old']);
  });

  test('stop cancels the run', () async {
    final f = ChatFixture([ScriptedStep.hang()]);
    await f.controller.open();
    final run = f.controller.send('Hi');
    await Future<void>.delayed(Duration.zero);
    expect(f.controller.isRunning, isTrue);
    f.controller.stop();
    await run;
    expect(f.controller.isRunning, isFalse);
    expect(f.lastAssistant.cancelled, isTrue);
  });

  test('stop while a tool runs leaves no spinning row', () async {
    final f = ChatFixture([
      ScriptedStep.toolCalls([call('c1', 'wipe', '{"folder":"a"}')]),
    ]);
    await f.controller.open();
    f.controller.addListener(() {
      final approval = f.controller.items
          .whereType<AssistantItem>()
          .lastOrNull
          ?.approval;
      if (approval != null) scheduleMicrotask(f.controller.stop);
    });
    await f.controller.send('Empty a');
    expect(f.controller.isRunning, isFalse);
    expect(f.lastAssistant.tools.where((t) => t.running), isEmpty);
  });

  test('AgentError sets error; the next send clears it', () async {
    final f = ChatFixture([
      ScriptedStep.error(const LlmError('Bad key', status: 401)),
      ScriptedStep.text('ok'),
    ]);
    await f.controller.open();
    await f.controller.send('Hi');
    expect(f.controller.error, 'Bad key');
    expect(f.controller.lastUserText, 'Hi');
    await f.controller.send('Again');
    expect(f.controller.error, isNull);
  });

  test('retry shows the message once', () async {
    final f = ChatFixture([
      ScriptedStep.error(const LlmError('Bad key', status: 401)),
      ScriptedStep.text('ok'),
    ]);
    await f.controller.send('hi');
    expect(f.controller.error, isNotNull);
    await f.controller.send('hi');
    expect(f.controller.error, isNull);
    expect(f.controller.items.whereType<UserItem>(), hasLength(1));
  });

  test('a store that fails to load sets the error', () async {
    final f = ChatFixture([ScriptedStep.text('ok')]);
    final controller = AssistantController(
      session: f.session,
      threads: _BrokenStore(),
    );
    await controller.open();
    expect(controller.error, isNotNull);
    await controller.send('hi');
    expect(controller.isRunning, isFalse);
  });

  test('a later successful open clears the load error', () async {
    final f = ChatFixture([ScriptedStep.text('ok')]);
    final store = _FlakyStore();
    final controller = AssistantController(session: f.session, threads: store);
    await controller.open();
    expect(controller.error, isNotNull);
    store.broken = false;
    await controller.open();
    expect(controller.error, isNull);
  });

  test('the same text after a reply is shown twice', () async {
    final f = ChatFixture([ScriptedStep.text('a'), ScriptedStep.text('b')]);
    await f.controller.send('hi');
    await f.controller.send('hi');
    expect(f.controller.items.whereType<UserItem>(), hasLength(2));
  });

  test('two opens at once create one thread', () async {
    final f = ChatFixture([ScriptedStep.text('ok')]);
    await Future.wait([f.controller.open(), f.controller.open()]);
    expect(await f.threads.threads(), hasLength(1));
  });

  test('LoopLimit sets limit', () async {
    final f = ChatFixture([
      ScriptedStep.toolCalls([call('c1', 'echo', '{"text":"a"}')]),
      ScriptedStep.toolCalls([call('c2', 'echo', '{"text":"b"}')]),
    ], config: const AgentConfig(maxSteps: 1));
    await f.controller.open();
    await f.controller.send('Go');
    expect(f.controller.limit, LoopLimitReason.maxSteps);
  });

  test('AnswerOnly sets answerOnly', () async {
    final f = ChatFixture([
      ScriptedStep.text('From the screen: 3 items.'),
    ], model: const ModelConfig(model: 'tiny', toolCalling: false));
    await f.controller.open();
    await f.controller.send('How many?');
    expect(f.controller.answerOnly, isTrue);
  });

  test('the user item never contains the current-screen block', () async {
    final f = ChatFixture([ScriptedStep.text('ok')]);
    await f.controller.open();
    await f.controller.send('Hi');
    expect((f.controller.items.first as UserItem).text, 'Hi');
    await f.controller.open(threadId: f.controller.threadId);
    expect((f.controller.items.first as UserItem).text, 'Hi');
  });

  test('newThread starts an empty conversation', () async {
    final f = ChatFixture([ScriptedStep.text('ok')]);
    await f.controller.open();
    await f.controller.send('Hi');
    final first = f.controller.threadId;
    await f.controller.newThread();
    expect(f.controller.items, isEmpty);
    expect(f.controller.threadId, isNot(first));
  });

  group('waiting', () {
    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test(
      'is true from the send until the first text, and false at the end',
      () async {
        final f = ChatFixture([ScriptedStep.hang()]);
        await f.controller.open();
        final sending = f.controller.send('Hi');
        expect(f.controller.isWaiting, isTrue);
        await settle();
        expect(f.controller.isWaiting, isTrue);
        f.controller.stop();
        await sending;
        expect(f.controller.isWaiting, isFalse);
      },
    );

    test('turns on again after a tool finishes', () async {
      final f = ChatFixture([
        ScriptedStep.toolCalls([
          call('c1', 'echo', '{"text":"a"}'),
        ], text: 'Let me check.'),
        ScriptedStep.hang(),
      ]);
      await f.controller.open();
      final sending = f.controller.send('Go');
      await settle();
      expect(f.lastAssistant.tools.single.running, isFalse);
      expect(f.controller.isWaiting, isTrue);
      f.controller.stop();
      await sending;
    });

    test('is off while an approval waits and on again once answered', () async {
      final f = ChatFixture([
        ScriptedStep.toolCalls([call('c1', 'wipe', '{"folder":"a"}')]),
        ScriptedStep.hang(),
      ]);
      await f.controller.open();
      final sending = f.controller.send('Go');
      await settle();
      expect(f.controller.pendingApproval, isNotNull);
      expect(f.controller.isWaiting, isFalse);
      f.controller.approve('c1');
      expect(f.controller.isWaiting, isTrue);
      await settle();
      expect(f.controller.isWaiting, isTrue);
      f.controller.stop();
      await sending;
      expect(f.controller.isWaiting, isFalse);
    });

    test('is off after an error', () async {
      final f = ChatFixture([
        ScriptedStep.error(const LlmError('Bad key', status: 401)),
      ]);
      await f.controller.send('Hi');
      expect(f.controller.isWaiting, isFalse);
    });
  });

  test('waiting turns off as soon as Stop is pressed', () async {
    final f = ChatFixture([ScriptedStep.hang()]);
    await f.controller.open();
    final sending = f.controller.send('Hi');
    expect(f.controller.isWaiting, isTrue);
    f.controller.stop();
    expect(f.controller.isWaiting, isFalse);
    await sending;
  });

  test('the newest open wins, and open is ignored during a run', () async {
    final f = ChatFixture([ScriptedStep.hang()]);
    final a = await f.threads.createThread();
    await f.threads.append(a.id, StoredMessage(UserMessage('A')));
    final b = await f.threads.createThread();
    await f.threads.append(b.id, StoredMessage(UserMessage('B')));
    await Future.wait([
      f.controller.open(threadId: a.id),
      f.controller.open(threadId: b.id),
    ]);
    expect(f.controller.threadId, b.id);
    expect((f.controller.items.single as UserItem).text, 'B');

    final sending = f.controller.send('Hi');
    await f.controller.open(threadId: a.id);
    expect(f.controller.threadId, b.id);
    f.controller.stop();
    await sending;
  });

  test('a thread title is its first message, read once', () async {
    final f = ChatFixture([]);
    final store = _CountingStore();
    final controller = AssistantController(session: f.session, threads: store);
    final t = await store.createThread();
    await store.append(t.id, StoredMessage(UserMessage('First  line\nnext')));
    expect(await controller.threadTitle(t), 'First line next');
    expect(await controller.threadTitle(t), 'First line next');
    expect(store.reads, 1);
  });

  test('stop marks the run as stopping until it ends', () async {
    final f = ChatFixture([ScriptedStep.hang()]);
    await f.controller.open();
    final sending = f.controller.send('Hi');
    f.controller.stop();
    expect(f.controller.isStopping, isTrue);
    await sending;
    expect(f.controller.isStopping, isFalse);
  });

  test('errors carry their kind and whether a retry may help', () async {
    final f = ChatFixture([
      ScriptedStep.error(const LlmError('Bad key', status: 401)),
      ScriptedStep.error(const LlmError('Busy', status: 503, retryable: true)),
    ], config: const AgentConfig(maxRetries: 0));
    await f.controller.send('Hi');
    expect(f.controller.errorKind, LlmErrorKind.auth);
    expect(f.controller.canRetry, isFalse);
    await f.controller.send('Again');
    expect(f.controller.errorKind, LlmErrorKind.server);
    expect(f.controller.canRetry, isTrue);
  });

  test('text after a tool starts a new paragraph, live and reloaded', () async {
    final f = ChatFixture([
      ScriptedStep.toolCalls([
        call('c1', 'echo', '{"text":"x"}'),
      ], text: 'Let me check.'),
      ScriptedStep.text('All done.'),
    ]);
    await f.controller.send('Go');
    expect(f.lastAssistant.text, 'Let me check.\n\nAll done.');
    await f.controller.open(threadId: f.controller.threadId);
    expect(f.lastAssistant.text, 'Let me check.\n\nAll done.');
  });

  test('a rejected tool keeps its declined code, live and reloaded', () async {
    final f = ChatFixture([
      ScriptedStep.toolCalls([call('c1', 'wipe', '{"folder":"a"}')]),
      ScriptedStep.text('Ok.'),
    ]);
    await f.controller.open();
    final sending = f.controller.send('Go');
    while (f.controller.pendingApproval == null) {
      await Future<void>.delayed(Duration.zero);
    }
    f.controller.reject('c1');
    await sending;
    expect(f.lastAssistant.tools.single.errorCode, 'declined');
    await f.controller.open(threadId: f.controller.threadId);
    expect(f.lastAssistant.tools.single.errorCode, 'declined');
  });

  test('new chat on an empty chat keeps the one empty thread', () async {
    final f = ChatFixture([]);
    await f.controller.open();
    await f.controller.newThread();
    await f.controller.newThread();
    expect(await f.threads.threads(), hasLength(1));
  });

  test('a failed new chat sets a retryable error; retry loads again', () async {
    final f = ChatFixture([ScriptedStep.text('ok')]);
    final store = _FlakyCreate();
    final controller = AssistantController(session: f.session, threads: store);
    await controller.newThread();
    expect(controller.error, isNotNull);
    expect(controller.canRetry, isTrue);
    store.broken = false;
    await controller.retry();
    expect(controller.error, isNull);
    expect(controller.threadId, isNotNull);
  });

  test('a failed load offers retry, which opens again', () async {
    final f = ChatFixture([ScriptedStep.text('ok')]);
    final store = _FlakyStore();
    final controller = AssistantController(session: f.session, threads: store);
    await controller.open();
    expect(controller.canRetry, isTrue);
    store.broken = false;
    await controller.retry();
    expect(controller.error, isNull);
  });

  test(
    'a reply cancelled after dispose ends without touching the controller',
    () async {
      final f = ChatFixture([ScriptedStep.hang()]);
      await f.controller.open();
      final sending = f.controller.send('Hi');
      while (!f.session.isRunning) {
        await Future<void>.delayed(Duration.zero);
      }
      f.controller.dispose();
      f.session.cancel();
      await sending;
    },
  );
}

class _BrokenStore extends InMemoryThreadStore {
  @override
  Future<List<StoredMessage>> messages(String threadId) async =>
      throw StateError('disk gone');
}

class _FlakyStore extends InMemoryThreadStore {
  bool broken = true;

  @override
  Future<List<StoredMessage>> messages(String threadId) async =>
      broken ? throw StateError('disk gone') : super.messages(threadId);
}

class _FlakyCreate extends InMemoryThreadStore {
  bool broken = true;

  @override
  Future<AssistantThread> createThread({String? title}) async =>
      broken ? throw StateError('disk full') : super.createThread(title: title);
}

class _CountingStore extends InMemoryThreadStore {
  var reads = 0;

  @override
  Future<List<StoredMessage>> messages(String threadId) {
    reads++;
    return super.messages(threadId);
  }
}
