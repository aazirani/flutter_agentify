import 'dart:convert';

import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:test/test.dart';

import 'loop_fixtures.dart';

StoredMessage _user(String text) => StoredMessage(UserMessage(text));
StoredMessage _reply(String text) => StoredMessage(AssistantMessage(text));

/// A model with room for roughly [tokens] tokens of history.
ModelConfig _model(int contextWindow) =>
    ModelConfig(model: 'm', contextWindow: contextWindow, maxOutputTokens: 500);

Future<void> _prefill(LoopFixture f, int count, {int chars = 1000}) async {
  final id = await f.threadId;
  for (var i = 0; i < count; i++) {
    await f.threads.append(
      id,
      i.isEven ? _user('q$i ${'x' * chars}') : _reply('a$i ${'y' * chars}'),
    );
  }
}

void main() {
  test('estimateTokens counts non-ASCII text at a higher rate', () {
    expect(estimateTokens('a' * 40), 10);
    expect(estimateTokens('س' * 40), greaterThanOrEqualTo(26));
  });

  group('historyCutIndex', () {
    final messages = [
      for (var i = 0; i < 10; i++)
        i.isEven ? _user('x' * 400) : _reply('y' * 400),
    ];

    test('keeps everything that fits', () {
      expect(historyCutIndex(messages, budgetTokens: 100000, keepRecent: 2), 0);
    });

    test('cuts what does not fit', () {
      final cut = historyCutIndex(messages, budgetTokens: 400, keepRecent: 1);
      expect(cut, greaterThan(0));
      final kept = messages.sublist(cut);
      final tokens = kept.fold(
        0,
        (s, m) => s + estimateTokens(jsonEncode(m.toJson())),
      );
      expect(tokens, lessThanOrEqualTo(400));
    });

    test('historyCutIndex keeps at least keepRecent messages', () {
      expect(historyCutIndex(messages, budgetTokens: 1, keepRecent: 4), 6);
    });

    test('historyCutIndex never separates a tool call from its results', () {
      final withTools = [
        _user('x' * 400),
        StoredMessage(
          AssistantMessage(
            '',
            toolCalls: [
              ToolCall(id: 'c1', name: 'a', rawArguments: '{}'),
              ToolCall(id: 'c2', name: 'b', rawArguments: '{}'),
            ],
          ),
        ),
        StoredMessage(
          ToolResultMessage(callId: 'c1', name: 'a', content: 'x' * 400),
        ),
        StoredMessage(
          ToolResultMessage(callId: 'c2', name: 'b', content: 'x' * 400),
        ),
        _reply('done'),
      ];
      for (var keep = 1; keep <= 5; keep++) {
        final cut = historyCutIndex(
          withTools,
          budgetTokens: 1,
          keepRecent: keep,
        );
        expect(
          withTools[cut].message,
          isNot(isA<ToolResultMessage>()),
          reason: 'keep $keep',
        );
      }
    });

    test('the kept history always starts with a person message', () {
      final mixed = [
        _user('x' * 400),
        _reply('y' * 400),
        _user('x' * 400),
        StoredMessage(
          AssistantMessage(
            '',
            toolCalls: [ToolCall(id: 'c1', name: 'a', rawArguments: '{}')],
          ),
        ),
        StoredMessage(
          ToolResultMessage(callId: 'c1', name: 'a', content: 'x' * 400),
        ),
        _reply('y' * 400),
      ];
      for (var keep = 1; keep <= 6; keep++) {
        for (final budget in [1, 150, 300, 600]) {
          final cut = historyCutIndex(
            mixed,
            budgetTokens: budget,
            keepRecent: keep,
          );
          expect(
            mixed[cut].message,
            isA<UserMessage>(),
            reason: 'keep $keep budget $budget',
          );
        }
      }
    });

    test(
      'keepRecent 0 with an oversized newest message keeps that message',
      () {
        final threeMessagesEndingInUser = [
          _user('x' * 400),
          _reply('y' * 400),
          _user('x' * 400),
        ];
        expect(
          historyCutIndex(
            threeMessagesEndingInUser,
            budgetTokens: 1,
            keepRecent: 0,
          ),
          2,
        );
      },
    );

    test('estimateTokens is characters / 4, rounded up', () {
      expect(estimateTokens(''), 0);
      expect(estimateTokens('abcde'), 2);
    });
  });

  group('withToolResults', () {
    ToolCall call(String id) => ToolCall(id: id, name: 'x', rawArguments: '{}');

    test('withToolResults adds a cancelled result for an unanswered call', () {
      final fixed = withToolResults([
        UserMessage('hi'),
        AssistantMessage('', toolCalls: [call('c1'), call('c2')]),
        ToolResultMessage(callId: 'c1', name: 'x', content: '{}'),
        UserMessage('again'),
      ]);
      expect(fixed.map((m) => m.runtimeType), [
        UserMessage,
        AssistantMessage,
        ToolResultMessage,
        ToolResultMessage,
        UserMessage,
      ]);
      final added = fixed[3] as ToolResultMessage;
      expect(added.callId, 'c2');
      expect(added.name, 'x');
      expect(added.content, '{"error":"cancelled"}');
      expect(added.isError, isTrue);
    });

    test('withToolResults leaves a complete history unchanged', () {
      final complete = <ChatMessage>[
        UserMessage('hi'),
        AssistantMessage('', toolCalls: [call('c1')]),
        ToolResultMessage(callId: 'c1', name: 'x', content: '{}'),
        AssistantMessage('done'),
      ];
      final copy = List.of(complete);
      final fixed = withToolResults(complete);
      expect(fixed, hasLength(complete.length));
      for (final (i, m) in fixed.indexed) {
        expect(m, same(complete[i]));
      }
      expect(complete, copy, reason: 'the input list is not changed');
    });
  });

  test('a history over budget is summarized before the step', () async {
    final f = LoopFixture([
      ScriptedStep.text('They asked about q0 to q15.'),
      ScriptedStep.text('reply'),
    ], model: _model(3000));
    await _prefill(f, 16);
    final events = await f.send('Next');
    expect(events.last, isA<Done>());
    expect(events.whereType<TextDelta>().map((e) => e.text), [
      'reply',
    ], reason: 'the summary is not shown');
    expect(f.provider.requests, hasLength(2));
    expect(f.provider.requests[0].tools, isEmpty);
    expect(
      (await f.threads.thread(await f.threadId))?.summary,
      'They asked about q0 to q15.',
    );
    expect(
      f.provider.requests[1].system,
      contains('They asked about q0 to q15.'),
    );
    final stored = await f.stored();
    expect(stored.length, lessThan(18));
    expect(stored.length, greaterThanOrEqualTo(8));
  });

  test('when summarizing fails, old messages are dropped', () async {
    final f = LoopFixture([
      ScriptedStep.error(const LlmError('Model crashed')),
      ScriptedStep.text('reply'),
    ], model: _model(3000));
    await _prefill(f, 16);
    final events = await f.send('Next');
    expect(events.last, isA<Done>());
    expect((await f.stored()).length, lessThan(18));
  });

  test('contextOverflow triggers one summarize-and-retry', () async {
    final f = LoopFixture([
      ScriptedStep.error(
        const LlmError('Too long', status: 400, contextOverflow: true),
      ),
      ScriptedStep.text('Short summary.'),
      ScriptedStep.text('reply'),
    ]);
    await _prefill(f, 12, chars: 50);
    final events = await f.send('Next');
    expect(events.last, isA<Done>());
    expect(f.provider.requests, hasLength(3));
    expect(
      (await f.threads.thread(await f.threadId))?.summary,
      'Short summary.',
    );
  });

  test('a second contextOverflow ends the run with AgentError', () async {
    const overflow = LlmError('Too long', status: 400, contextOverflow: true);
    final f = LoopFixture([
      ScriptedStep.error(overflow),
      ScriptedStep.text('Short summary.'),
      ScriptedStep.error(overflow),
    ]);
    await _prefill(f, 12, chars: 50);
    final events = await f.send('Next');
    expect(events.last, isA<AgentError>());
  });

  test('a small context window uses the compact rules', () async {
    final small = LoopFixture([ScriptedStep.text('ok')], model: _model(8000));
    final large = LoopFixture([ScriptedStep.text('ok')], model: _model(128000));
    await small.send('Hi');
    await large.send('Hi');
    expect(
      small.provider.requests.single.system.length,
      lessThan(large.provider.requests.single.system.length),
    );
  });
}
