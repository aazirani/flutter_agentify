import 'dart:async';

import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:test/test.dart';

import '../actions/fake_action.dart';
import 'loop_fixtures.dart';

void main() {
  test(
    'a text-only reply emits deltas then Done and stores both messages',
    () async {
      final f = LoopFixture([ScriptedStep.text('Hello there')]);
      final events = await f.send('Hi');
      expect(
        events.whereType<TextDelta>().map((e) => e.text).join(),
        'Hello there',
      );
      expect(events.last, isA<Done>());
      final stored = await f.stored();
      expect(stored, hasLength(2));
      expect((stored[0].message as UserMessage).text, 'Hi');
      expect((stored[1].message as AssistantMessage).text, 'Hello there');
    },
  );

  test('the user message carries the current-screen block as context; the '
      'system text does not contain it', () async {
    final f = LoopFixture([ScriptedStep.text('ok')]);
    await f.send('Hi');
    final request = f.provider.requests.single;
    final user = request.messages.single as UserMessage;
    expect(user.text, 'Hi');
    expect(user.context, startsWith('<current-screen>'));
    expect(user.context, contains('"items":2'));
    expect(request.system, isNot(contains('<current-screen>\n')));
    expect(request.system, contains('Test app.'));
  });

  test('the system text is identical across two turns', () async {
    final f = LoopFixture([ScriptedStep.text('one'), ScriptedStep.text('two')]);
    await f.send('First');
    await f.send('Second');
    expect(f.provider.requests, hasLength(2));
    expect(f.provider.requests[0].system, f.provider.requests[1].system);
    expect(f.provider.requests[1].messages, hasLength(3));
  });

  test('a tool call runs, its result is sent back, and the next reply ends '
      'the run', () async {
    final f = LoopFixture([
      ScriptedStep.toolCalls([
        call('c1', 'add_note', {'text': 'Milk'}),
      ]),
      ScriptedStep.text('Added.'),
    ]);
    final events = await f.send('Add milk');
    expect(events.map((e) => e.runtimeType), [
      ToolStarted,
      ToolFinished,
      ChangeReceipt,
      TextDelta,
      Done,
    ]);
    final finished = events.whereType<ToolFinished>().single;
    expect(finished.isError, isFalse);
    expect(finished.content, '{"id":"n1"}');
    final second = f.provider.requests[1].messages;
    expect(second.last, isA<ToolResultMessage>());
    expect((second.last as ToolResultMessage).callId, 'c1');
    expect(
      f.provider.requests[0].tools.map((t) => t.name),
      contains('add_note'),
    );
  });

  test('a failure after a partial write still shows its receipt', () async {
    final f = LoopFixture(
      [
        ScriptedStep.toolCalls([
          call('c1', 'half', {'text': 'x'}),
        ]),
        ScriptedStep.text('One saved.'),
      ],
      actions: [
        FakeAction(
          'half',
          run: (_, context) async {
            context.receipt(resource: 'notes', ids: ['n1'], summary: 'Saved 1');
            throw const ActionFailure('partial', 'Saved 1 of 2.');
          },
        ),
      ],
    );
    final events = await f.send('Save both');
    expect(events.whereType<ToolFinished>().single.isError, isTrue);
    expect(events.whereType<ChangeReceipt>().single.receipt.summary, 'Saved 1');
  });

  test('two tool calls in one step run in order', () async {
    final f = LoopFixture([
      ScriptedStep.toolCalls([
        call('c1', 'echo', {'text': 'a'}),
        call('c2', 'echo', {'text': 'b'}),
      ]),
      ScriptedStep.text('ok'),
    ]);
    final events = await f.send('Go');
    expect(events.whereType<ToolStarted>().map((e) => e.callId), ['c1', 'c2']);
    expect(events.whereType<ToolFinished>().map((e) => e.content), [
      '"a"',
      '"b"',
    ]);
    await f.expectThreadValid();
  });

  test('receipts are stored on the last assistant message', () async {
    final f = LoopFixture([
      ScriptedStep.toolCalls([
        call('c1', 'add_note', {'text': 'Milk'}),
      ]),
      ScriptedStep.text('Added.'),
    ]);
    await f.send('Add milk');
    final last = (await f.stored()).last;
    expect((last.message as AssistantMessage).text, 'Added.');
    expect(last.receipts.single.summary, 'Added "Milk"');
  });

  group('bad tool calls (review focus 1)', () {
    Future<(ToolFinished, List<AgentEvent>)> runWith(ToolCall bad) async {
      final f = LoopFixture([
        ScriptedStep.toolCalls([bad]),
        ScriptedStep.text('Sorry.'),
      ]);
      final events = await f.send('Go');
      expect(events.last, isA<Done>());
      await f.expectThreadValid();
      return (events.whereType<ToolFinished>().single, events);
    }

    test('malformed arguments produce an invalid_input result and the run '
        'continues', () async {
      final (finished, _) = await runWith(
        ToolCall(id: 'c1', name: 'echo', rawArguments: '{"text":'),
      );
      expect(finished.isError, isTrue);
      expect(finished.errorCode, 'invalid_input');
      expect(finished.content, contains('"error":"invalid_input"'));
    });

    test(
      'wrong-typed arguments produce invalid_input with the field path',
      () async {
        final (finished, _) = await runWith(call('c1', 'echo', {'text': 3}));
        expect(finished.errorCode, 'invalid_input');
        expect(finished.content, contains(r'$.text'));
      },
    );

    test(
      'an unknown tool name produces unknown_action and the run continues',
      () async {
        final (finished, _) = await runWith(call('c1', 'nope', {}));
        expect(finished.errorCode, 'unknown_action');
      },
    );

    test('a value the action cannot parse goes back to the model', () async {
      final f = LoopFixture(
        [
          ScriptedStep.toolCalls([
            call('c1', 'book', {'date': 'soon'}),
          ]),
          ScriptedStep.text('Which date?'),
        ],
        actions: [BookAction()],
      );
      final events = await f.send('Book it');
      expect(
        events.whereType<ToolFinished>().single.errorCode,
        'invalid_input',
      );
      expect(events.last, isA<Done>());
      await f.expectThreadValid();
    });

    test(
      'an action that throws produces internal_error and the run continues',
      () async {
        final (finished, _) = await runWith(call('c1', 'boom', {'text': 'x'}));
        expect(finished.errorCode, 'internal_error');
        expect(finished.content, isNot(contains('#0')));
      },
    );
  });

  group('stop conditions', () {
    test('stops with LoopLimit(maxSteps) after maxSteps tool rounds', () async {
      final f = LoopFixture([
        for (var i = 0; i < 5; i++)
          ScriptedStep.toolCalls([
            call('c$i', 'echo', {'text': '$i'}),
          ]),
      ], config: const AgentConfig(maxSteps: 2));
      final events = await f.send('Go');
      expect((events.last as LoopLimit).reason, LoopLimitReason.maxSteps);
      expect(f.provider.requests, hasLength(2));
      await f.expectThreadValid();
    });

    test(
      'stops with LoopLimit(tokenBudget) when this run passes the budget',
      () async {
        final f = LoopFixture([
          ScriptedStep.toolCalls([
            call('c1', 'echo', {'text': 'a'}),
          ], usage: const Usage(inputTokens: 80, outputTokens: 30)),
          ScriptedStep.toolCalls([
            call('c2', 'echo', {'text': 'b'}),
          ], usage: const Usage(inputTokens: 200, outputTokens: 30)),
          ScriptedStep.text('never sent'),
        ], config: const AgentConfig(tokenBudget: 100));
        final events = await f.send('Go');
        expect((events.last as LoopLimit).reason, LoopLimitReason.tokenBudget);
        expect(f.provider.requests, hasLength(2));
        await f.expectThreadValid();
      },
    );

    test('a history above the budget still lets a tool round finish and '
        'reply', () async {
      final f = LoopFixture([
        ScriptedStep.toolCalls([
          call('c1', 'echo', {'text': 'a'}),
        ], usage: const Usage(inputTokens: 5000, outputTokens: 20)),
        ScriptedStep.text(
          'done',
          usage: const Usage(inputTokens: 5100, outputTokens: 10),
        ),
      ], config: const AgentConfig(tokenBudget: 1000));
      final events = await f.send('Go');
      expect(events.last, isA<Done>());
    });

    test(
      'calls left open by a loop limit end with the loop_limit code',
      () async {
        final f = LoopFixture([
          for (var i = 0; i < 2; i++)
            ScriptedStep.toolCalls([
              call('a$i', 'echo', {'text': 'same'}),
              call('b$i', 'echo', {'text': 'same'}),
            ]),
        ], config: const AgentConfig(repeatLimit: 2));
        final events = await f.send('Go');
        expect((events.last as LoopLimit).reason, LoopLimitReason.repeatedCall);
        expect(events.whereType<ToolFinished>().last.errorCode, 'loop_limit');
        await f.expectThreadValid();
      },
    );

    test('stops with LoopLimit(repeatedCall) when the same call repeats 3 '
        'times', () async {
      final f = LoopFixture([
        for (var i = 0; i < 5; i++)
          ScriptedStep.toolCalls([
            call('c$i', 'echo', {'text': 'same'}),
          ]),
      ]);
      final events = await f.send('Go');
      expect((events.last as LoopLimit).reason, LoopLimitReason.repeatedCall);
      expect(
        events.whereType<ToolFinished>().where((e) => !e.isError),
        hasLength(2),
      );
      expect(f.provider.requests, hasLength(3));
      await f.expectThreadValid();
    });
  });

  group('cut-off replies', () {
    test('a cut-off reply ends with the output limit', () async {
      final f = LoopFixture([
        ScriptedStep.text('Half an ans', truncated: true),
      ]);
      final events = await f.send('Go');
      expect(
        events.last,
        isA<LoopLimit>().having(
          (l) => l.reason,
          'reason',
          LoopLimitReason.outputLimit,
        ),
      );
      final storedMessages = await f.stored();
      expect(
        storedMessages.last.message,
        isA<AssistantMessage>().having((m) => m.text, 'text', 'Half an ans'),
      );
    });

    test('tool calls of a cut-off reply are not run', () async {
      var actionRan = false;
      final f = LoopFixture(
        [
          ScriptedStep.toolCalls(
            [
              call('c1', 'spy', {'text': 'a'}),
            ],
            text: 'Let me',
            truncated: true,
          ),
        ],
        actions: [
          FakeAction(
            'spy',
            readOnly: true,
            resources: const [],
            run: (text, _) async {
              actionRan = true;
              return text;
            },
          ),
        ],
      );
      final events = await f.send('Go');
      expect(actionRan, isFalse);
      expect((events.last as LoopLimit).reason, LoopLimitReason.outputLimit);
      final message = (await f.stored()).last.message as AssistantMessage;
      expect(message.text, 'Let me');
      expect(message.toolCalls, isEmpty);
      await f.expectThreadValid();
    });
  });

  group('ending a run (review focus 2)', () {
    test('cancel during the model stream ends with Cancelled', () async {
      final f = LoopFixture([ScriptedStep.hang()]);
      final stream = f.session.send(await f.threadId, 'Hi');
      Timer(const Duration(milliseconds: 20), f.session.cancel);
      final events = await listen(stream, (_) {});
      expect(events.last, isA<Cancelled>());
      expect(events.where(_isFinal), hasLength(1));
      expect(f.session.isRunning, isFalse);
      await f.expectThreadValid();
    });

    test('cancel while a tool runs ends with Cancelled and the thread stays '
        'valid', () async {
      final release = Completer<void>();
      final f = LoopFixture(
        [
          ScriptedStep.toolCalls([
            call('c1', 'slow', {'text': 'x'}),
            call('c2', 'slow', {'text': 'y'}),
          ]),
          ScriptedStep.text('never'),
        ],
        actions: [
          FakeAction(
            'slow',
            readOnly: true,
            resources: const [],
            run: (_, _) async {
              await release.future;
              return 'late';
            },
          ),
        ],
      );
      final events = await listen(f.session.send(await f.threadId, 'Go'), (e) {
        if (e is ToolStarted) f.session.cancel();
      });
      release.complete();
      expect(events.last, isA<Cancelled>());
      expect(events.where(_isFinal), hasLength(1));
      expect(f.provider.requests, hasLength(1));
      await f.expectThreadValid();
      final results = (await f.stored())
          .map((m) => m.message)
          .whereType<ToolResultMessage>();
      expect(
        results.map((r) => r.content),
        everyElement('{"error":"cancelled"}'),
      );
    });

    test('a non-retryable provider error ends with AgentError and the thread '
        'stays valid', () async {
      final f = LoopFixture([
        ScriptedStep.toolCalls([
          call('c1', 'echo', {'text': 'a'}),
        ]),
        ScriptedStep.error(const LlmError('Bad key', status: 401)),
      ]);
      final events = await f.send('Go');
      final error = events.last as AgentError;
      expect(error.retryable, isFalse);
      expect(error.message, contains('Bad key'));
      expect(error.kind, LlmErrorKind.auth);
      expect(f.delays, isEmpty);
      await f.expectThreadValid();
    });

    test('sending the same text after a failed run stores it once', () async {
      final f = LoopFixture([
        ScriptedStep.error(const LlmError('Bad key', status: 401)),
        ScriptedStep.text('ok'),
      ]);
      await f.send('hi');
      final events2 = await f.send('hi');
      final stored = await f.stored();
      expect(stored.where((m) => m.message is UserMessage), hasLength(1));
      expect(events2.last, isA<Done>());
    });

    test('the same text after a reply is stored again', () async {
      final f = LoopFixture([ScriptedStep.text('a'), ScriptedStep.text('b')]);
      await f.send('hi');
      await f.send('hi');
      final stored = await f.stored();
      expect(stored.where((m) => m.message is UserMessage), hasLength(2));
    });

    test('a storage failure at the end still ends the stream with one final '
        'event', () async {
      final f = LoopFixture([
        ScriptedStep.toolCalls([
          call('c1', 'add_note', {'text': 'Milk'}),
        ]),
        ScriptedStep.text('Added.'),
      ], threads: _FailsAfterReply());
      final events = await f.send('Add milk');
      expect(events.last, isA<AgentError>());
      expect(events.where(_isFinal), hasLength(1));
    });

    test('error text is redacted', () async {
      final key = 'sk-' + 'c' * 30;
      final f = LoopFixture([ScriptedStep.error(LlmError('bad key $key'))]);
      final events = await f.send('Hi');
      final message = (events.last as AgentError).message;
      expect(message, contains('[redacted]'));
      expect(message, isNot(contains(key)));
    });

    test('a retryable error is retried, then succeeds', () async {
      final f = LoopFixture([
        ScriptedStep.error(
          const LlmError('Busy', status: 503, retryable: true),
        ),
        ScriptedStep.text('ok'),
      ]);
      final events = await f.send('Hi');
      expect(events.last, isA<Done>());
      expect(f.delays, [const Duration(seconds: 1)]);
    });

    test('a retryable error honors retryAfter', () async {
      final f = LoopFixture([
        ScriptedStep.error(
          const LlmError(
            'Slow down',
            status: 429,
            retryable: true,
            retryAfter: Duration(seconds: 7),
          ),
        ),
        ScriptedStep.text('ok'),
      ]);
      await f.send('Hi');
      expect(f.delays, [const Duration(seconds: 7)]);
    });

    test('a retryable error after maxRetries ends with AgentError(retryable '
        'true)', () async {
      const busy = LlmError('Busy', status: 503, retryable: true);
      final f = LoopFixture([
        ScriptedStep.error(busy),
        ScriptedStep.error(busy),
        ScriptedStep.error(busy),
      ]);
      final events = await f.send('Hi');
      expect((events.last as AgentError).retryable, isTrue);
      expect(f.delays, [
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]);
      expect(f.provider.requests, hasLength(3));
    });

    test('a timeout is not retried silently but stays retryable', () async {
      const stalled = LlmError(
        'The model server stopped responding.',
        kind: LlmErrorKind.timeout,
        retryable: true,
      );
      final f = LoopFixture([
        ScriptedStep.error(stalled),
        ScriptedStep.text('never asked'),
      ]);
      final events = await f.send('Hi');
      final error = events.last as AgentError;
      expect(error.kind, LlmErrorKind.timeout);
      expect(error.retryable, isTrue);
      expect(f.delays, isEmpty);
      expect(f.provider.requests, hasLength(1));
    });
  });

  group('review fixes', () {
    test(
      'cancel while a tool runs finishes its row with a cancelled result',
      () async {
        final release = Completer<void>();
        final f = LoopFixture(
          [
            ScriptedStep.toolCalls([
              call('c1', 'slow', {'text': 'x'}),
            ]),
          ],
          actions: [
            FakeAction(
              'slow',
              readOnly: true,
              resources: const [],
              run: (_, _) async {
                await release.future;
                return 'late';
              },
            ),
          ],
        );
        final events = await listen(f.session.send(await f.threadId, 'Go'), (
          e,
        ) {
          if (e is ToolStarted) f.session.cancel();
        });
        release.complete();
        final finished = events.whereType<ToolFinished>().single;
        expect(finished.callId, 'c1');
        expect(finished.errorCode, 'cancelled');
        expect(events.indexOf(finished), lessThan(events.length - 1));
        expect(events.last, isA<Cancelled>());
      },
    );

    test('stopping during a write still records what changed', () async {
      final release = Completer<void>();
      final f = LoopFixture(
        [
          ScriptedStep.toolCalls([
            call('c1', 'add_note', {'text': 'Milk'}),
          ]),
          ScriptedStep.text('never'),
        ],
        actions: [
          FakeAction(
            'add_note',
            run: (text, context) async {
              await release.future;
              context.receipt(
                resource: 'notes',
                ids: ['n1'],
                summary: 'Added "$text"',
              );
              return {'id': 'n1'};
            },
          ),
        ],
      );
      final events = await listen(f.session.send(await f.threadId, 'Go'), (e) {
        if (e is ToolStarted) {
          f.session.cancel();
          release.complete();
        }
      });
      final finished = events.whereType<ToolFinished>().single;
      expect(finished.isError, isFalse);
      expect(events.whereType<ChangeReceipt>(), hasLength(1));
      expect(events.last, isA<Cancelled>());
      expect(f.provider.requests, hasLength(1));
      await f.expectThreadValid();
      final stored = await f.stored();
      final result = stored
          .map((m) => m.message)
          .whereType<ToolResultMessage>()
          .single;
      expect(result.content, isNot(contains('cancelled')));
      expect(stored.last.receipts, hasLength(1));
    });

    test('a reply that ends without its end marker is retried, not shown as '
        'cancelled', () async {
      final provider = _ClosesOnceProvider();
      final threads = InMemoryThreadStore();
      final session = AgentSession(
        registry: ActionRegistry([echo()]),
        appContext: AppContext(screens: const {}),
        provider: provider,
        model: const ModelConfig(model: 'm'),
        threads: threads,
        memories: InMemoryMemoryStore(),
        delay: (_) async {},
      );
      final thread = await threads.createThread();
      final events = await session.send(thread.id, 'Hi').toList();
      expect(events.last, isA<Done>());
      expect(provider.calls, 2);
    });

    test(
      'the token budget counts new tokens, not the whole history again',
      () async {
        const big = Usage(inputTokens: 60000, outputTokens: 100);
        final f = LoopFixture([
          ScriptedStep.toolCalls([
            call('c1', 'echo', {'text': 'a'}),
          ], usage: big),
          ScriptedStep.toolCalls([
            call('c2', 'echo', {'text': 'b'}),
          ], usage: big),
          ScriptedStep.text('ok', usage: big),
        ]);
        final events = await f.send('Go');
        expect(events.last, isA<Done>());
      },
    );

    test(
      'the same call only counts as repeated when it comes in a row',
      () async {
        final f = LoopFixture([
          for (var i = 0; i < 6; i++)
            ScriptedStep.toolCalls([
              call('c$i', 'echo', {'text': i.isEven ? 'a' : 'b'}),
            ]),
          ScriptedStep.text('ok'),
        ]);
        final events = await f.send('Go');
        expect(events.last, isA<Done>());
      },
    );

    test('a long Retry-After is capped at 30 seconds', () async {
      final f = LoopFixture([
        ScriptedStep.error(
          const LlmError(
            'Slow down',
            status: 429,
            retryable: true,
            retryAfter: Duration(minutes: 10),
          ),
        ),
        ScriptedStep.text('ok'),
      ]);
      await f.send('Hi');
      expect(f.delays, [const Duration(seconds: 30)]);
    });

    test('Stop during a retry wait ends the run at once', () async {
      final f = LoopFixture([
        ScriptedStep.error(
          const LlmError('Busy', status: 503, retryable: true),
        ),
        ScriptedStep.text('never'),
      ], delay: (_) => Completer<void>().future);
      final stream = f.session.send(await f.threadId, 'Hi');
      Future<void>.delayed(const Duration(milliseconds: 20), f.session.cancel);
      final events = await stream.toList().timeout(const Duration(seconds: 2));
      expect(events.last, isA<Cancelled>());
      expect(f.provider.requests, hasLength(1));
    });

    test(
      'a failure message with a key is redacted before the model sees it',
      () async {
        final key = 'sk-' + 'k' * 30;
        final f = LoopFixture(
          [
            ScriptedStep.toolCalls([
              call('c1', 'leak', {'text': 'x'}),
            ]),
            ScriptedStep.text('ok'),
          ],
          actions: [
            FakeAction(
              'leak',
              run: (_, _) async => throw ActionFailure(
                'bad',
                'used $key',
                details: {'key': key},
              ),
            ),
          ],
        );
        final events = await f.send('Go');
        final finished = events.whereType<ToolFinished>().single;
        expect(finished.content, isNot(contains(key)));
        expect(finished.content, contains('[redacted]'));
        final sent = f.provider.requests[1].messages.last as ToolResultMessage;
        expect(sent.content, isNot(contains(key)));
      },
    );
  });

  group('history', () {
    test(
      'stopping while history is summarized keeps the old messages',
      () async {
        final f = LoopFixture(
          [ScriptedStep.hang(), ScriptedStep.text('never')],
          model: const ModelConfig(
            model: 'm',
            contextWindow: 3000,
            maxOutputTokens: 500,
          ),
        );
        final id = await f.threadId;
        for (var i = 0; i < 16; i++) {
          await f.threads.append(
            id,
            StoredMessage(
              i.isEven
                  ? UserMessage('q$i ${'x' * 1000}')
                  : AssistantMessage('a$i ${'y' * 1000}'),
            ),
          );
        }
        final stream = f.session.send(await f.threadId, 'Next');
        Future<void>.delayed(
          const Duration(milliseconds: 20),
          f.session.cancel,
        );
        final events = await stream.toList();
        expect(events.last, isA<Cancelled>());
        expect(
          f.provider.requests,
          hasLength(1),
          reason: 'no request after Stop',
        );
        expect((await f.stored()).length, 17, reason: 'nothing dropped');
        expect((await f.threads.thread(await f.threadId))?.summary, isNull);
      },
    );
  });

  group('sending (review focus 4)', () {
    test('blank text throws ArgumentError and makes no request', () async {
      final f = LoopFixture([ScriptedStep.text('ok')]);
      final id = await f.threadId;
      expect(() => f.session.send(id, '   \n'), throwsArgumentError);
      expect(() => f.session.send(id, ''), throwsArgumentError);
      expect(f.provider.requests, isEmpty);
      expect(await f.stored(), isEmpty);
    });

    test('send while running throws StateError', () async {
      final f = LoopFixture([ScriptedStep.hang()]);
      final id = await f.threadId;
      final first = f.session.send(id, 'One');
      expect(f.session.isRunning, isTrue);
      expect(() => f.session.send(id, 'Two'), throwsStateError);
      f.session.cancel();
      expect((await first.toList()).last, isA<Cancelled>());
    });
  });

  test(
    'the system text stays the same within a run when a memory is saved',
    () async {
      final memories = InMemoryMemoryStore();
      final approvals = InMemoryApprovalPrefs();
      await approvals.setAlwaysAllowed('save_memory', true);
      final f = LoopFixture(
        approvals: approvals,
        [
          ScriptedStep.toolCalls([
            call('c1', 'save_memory', {'text': 'Likes tea'}),
          ]),
          ScriptedStep.text('Noted.'),
          ScriptedStep.text('Next run.'),
        ],
        actions: [SaveMemoryAction(memories)],
        memories: memories,
      );
      await f.send('Remember I like tea');
      await f.send('Hi');
      final systems = f.provider.requests.map((r) => r.system).toList();
      expect(systems[0], systems[1], reason: 'same run');
      expect(
        systems[2],
        isNot(systems[1]),
        reason: 'the next run sees the memory',
      );
    },
  );

  test(
    'provider content of a reply is stored on its assistant message',
    () async {
      const content = ProviderContent(
        format: 'anthropic',
        blocks: [
          {'type': 'text', 'text': 'Hi.'},
        ],
      );
      final f = LoopFixture([
        ScriptedStep.text('Hi.', providerContent: content),
      ]);
      await f.send('Hello');
      final reply = (await f.stored()).last.message as AssistantMessage;
      expect(reply.providerContent?.blocks, content.blocks);
    },
  );

  test(
    'debugSnapshot holds the last system text, tool names and calls',
    () async {
      final f = LoopFixture([
        ScriptedStep.toolCalls([
          call('c1', 'echo', {'text': 'a'}),
        ], usage: const Usage(inputTokens: 3, outputTokens: 4)),
        ScriptedStep.text(
          'ok',
          usage: const Usage(inputTokens: 5, outputTokens: 6),
        ),
      ]);
      expect(f.session.debugSnapshot, isNull);
      await f.send('Go');
      final snapshot = f.session.debugSnapshot;
      expect(snapshot?.system, f.provider.requests.last.system);
      expect(snapshot?.activeTools, containsAll(['echo', 'add_note', 'boom']));
      expect(snapshot?.lastCalls.map((c) => c.name), ['echo']);
      expect(snapshot?.lastUsage?.outputTokens, 6);
    },
  );
  test(
    'a thread left with an unanswered tool call still gets a reply',
    () async {
      final f = LoopFixture([ScriptedStep.text('Hi again')]);
      final id = await f.threadId;
      await f.threads.append(id, StoredMessage(UserMessage('delete it')));
      await f.threads.append(
        id,
        StoredMessage(
          AssistantMessage('', toolCalls: [call('c1', 'add_note', {})]),
        ),
      );
      final events = await f.send('hello');
      expect(events.last, isA<Done>());
      final lastRequestMessages = f.provider.requests.last.messages;
      expect(
        lastRequestMessages.whereType<ToolResultMessage>().single.callId,
        'c1',
      );
    },
  );

  test('tool schemas count against the history budget', () async {
    final f = LoopFixture(
      [ScriptedStep.text('Earlier talk.'), ScriptedStep.text('reply')],
      model: const ModelConfig(
        model: 'm',
        contextWindow: 2000,
        maxOutputTokens: 500,
      ),
      config: const AgentConfig(toolSearchShare: 10),
      actions: [FakeAction('big', readOnly: true, description: 'd' * 4000)],
    );
    final id = await f.threadId;
    for (var i = 0; i < 10; i++) {
      await f.threads.append(
        id,
        StoredMessage(
          i.isEven ? UserMessage('x' * 300) : AssistantMessage('y' * 300),
        ),
      );
    }
    final events = await f.send('Next');
    expect(events.last, isA<Done>());
    expect(f.provider.requests, hasLength(2));
    expect(f.provider.requests.first.tools, isEmpty, reason: 'the summary');
    expect((await f.threads.thread(id))?.summary, 'Earlier talk.');
  });

  test(
    'the summary request fits the window however long the messages are',
    () async {
      final f = LoopFixture(
        [ScriptedStep.text('Earlier talk.'), ScriptedStep.text('reply')],
        model: const ModelConfig(
          model: 'm',
          contextWindow: 2000,
          maxOutputTokens: 500,
        ),
      );
      final id = await f.threadId;
      for (var i = 0; i < 24; i++) {
        await f.threads.append(
          id,
          StoredMessage(
            i.isEven ? UserMessage('x' * 5000) : AssistantMessage('y' * 5000),
          ),
        );
      }
      final events = await f.send('Next');
      expect(events.last, isA<Done>());
      final asked = f.provider.requests.first.messages.single as UserMessage;
      expect(estimateTokens(asked.text), lessThanOrEqualTo(2000 * 6 ~/ 10));
      expect((await f.threads.thread(id))?.summary, 'Earlier talk.');
    },
  );
}

bool _isFinal(AgentEvent e) =>
    e is Done || e is Cancelled || e is LoopLimit || e is AgentError;

/// Closes its first stream without [LlmDone], then answers normally.
class _ClosesOnceProvider implements LlmProvider {
  var calls = 0;

  @override
  void close() {}

  @override
  Stream<LlmEvent> stream({
    required String system,
    required List<ChatMessage> messages,
    List<ToolSpec> tools = const [],
    required ModelConfig config,
    CancelToken? cancel,
  }) async* {
    if (++calls == 1) return;
    yield LlmTextDelta('Complete.');
    yield LlmDone();
  }
}

/// Fails every write from the model's final reply on.
class _FailsAfterReply extends InMemoryThreadStore {
  var _failing = false;

  @override
  Future<void> append(String threadId, StoredMessage message) {
    if (message.message case AssistantMessage(toolCalls: [])) _failing = true;
    if (_failing) throw StateError('disk full');
    return super.append(threadId, message);
  }
}
