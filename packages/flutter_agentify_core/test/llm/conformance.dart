import 'dart:async';
import 'dart:convert';

import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:test/test.dart';

/// A fake model server speaking one provider's wire format.
abstract class ProviderHarness {
  Future<void> start();
  Future<void> stop();
  LlmProvider get provider;
  ModelConfig get config;

  /// [cutOff]: the model stopped at its output limit.
  void replyText(
    List<String> chunks, {
    int inputTokens = 10,
    int outputTokens = 5,
    bool cutOff = false,
  });
  void replyToolCalls(List<ToolCall> calls, {int splitArgumentsInto = 3});
  void replyError(
    int status,
    String message, {
    Map<String, String> headers = const {},
  });
  void replyTextThenDropConnection(String chunk);
  void replyTextThenHang(String chunk);
  void replyContextOverflow();

  /// A 200 streamed response whose data line is not JSON.
  void replyMalformed();

  /// Closes the connection before any response.
  void replyDropConnection();
  Map<String, Object?> get lastRequestBody;
  Map<String, String> get lastRequestHeaders;
}

const _system = 'You help inside the app.';
final _messages = <ChatMessage>[UserMessage('Hi')];

/// The behavior every [LlmProvider] must share, run against [create]'s fake
/// server.
void runConformance(String name, ProviderHarness Function() create) {
  group('$name conformance', () {
    late ProviderHarness h;
    setUp(() async {
      h = create();
      await h.start();
    });
    tearDown(() => h.stop());

    Stream<LlmEvent> run({
      List<ChatMessage>? messages,
      List<ToolSpec> tools = const [],
      ModelConfig? config,
      CancelToken? cancel,
    }) => h.provider.stream(
      system: _system,
      messages: messages ?? _messages,
      tools: tools,
      config: config ?? h.config,
      cancel: cancel,
    );

    test('streams text deltas in order, then done with usage', () async {
      h.replyText(['Hel', 'lo']);
      final events = await run().toList();
      expect(events.whereType<LlmTextDelta>().map((e) => e.text), [
        'Hel',
        'lo',
      ]);
      expect(events.last, isA<LlmDone>());
      expect(events.whereType<LlmDone>(), hasLength(1));
      final usage = (events.last as LlmDone).usage;
      expect(usage?.inputTokens, 10);
      expect(usage?.outputTokens, 5);
    });

    test(
      'a tool call whose arguments arrive in pieces is emitted once, parsed',
      () async {
        h.replyToolCalls([
          ToolCall(
            id: 'c1',
            name: 'add_item',
            rawArguments: '{"title":"Milk"}',
          ),
        ]);
        final events = await run().toList();
        final calls = events
            .whereType<LlmToolCall>()
            .map((e) => e.call)
            .toList();
        expect(calls, hasLength(1));
        expect(calls.single.id, 'c1');
        expect(calls.single.name, 'add_item');
        expect(calls.single.arguments, {'title': 'Milk'});
        expect(events.last, isA<LlmDone>());
      },
    );

    test('two tool calls arrive in order', () async {
      h.replyToolCalls([
        ToolCall(id: 'c1', name: 'first', rawArguments: '{"n":1}'),
        ToolCall(id: 'c2', name: 'second', rawArguments: '{"n":2}'),
      ]);
      final calls = (await run().toList())
          .whereType<LlmToolCall>()
          .map((e) => e.call)
          .toList();
      expect(calls.map((c) => c.name), ['first', 'second']);
      expect(calls.map((c) => c.arguments), [
        {'n': 1},
        {'n': 2},
      ]);
    });

    test(
      'malformed arguments give arguments == null and keep rawArguments',
      () async {
        h.replyToolCalls([
          ToolCall(id: 'c1', name: 'add_item', rawArguments: '{"title":'),
        ]);
        final call = (await run().toList())
            .whereType<LlmToolCall>()
            .single
            .call;
        expect(call.arguments, isNull);
        expect(call.rawArguments, '{"title":');
      },
    );

    test('non-streaming mode produces the same events', () async {
      final config = h.config.copyWith(streaming: false);
      h.replyText(['Hel', 'lo']);
      final text = await run(config: config).toList();
      expect(text.whereType<LlmTextDelta>().map((e) => e.text).join(), 'Hello');
      expect((text.last as LlmDone).usage?.inputTokens, 10);

      h.replyToolCalls([
        ToolCall(id: 'c1', name: 'add_item', rawArguments: '{"title":"Milk"}'),
      ]);
      final calls = await run(config: config).toList();
      expect(calls.whereType<LlmToolCall>().single.call.arguments, {
        'title': 'Milk',
      });
      expect(calls.last, isA<LlmDone>());
    });

    test('a reply cut by the output limit is marked truncated', () async {
      for (final streaming in [true, false]) {
        h.replyText(['Half an ', 'ans'], cutOff: true);
        final events = await run(
          config: h.config.copyWith(streaming: streaming),
        ).toList();
        expect(events.whereType<LlmDone>().single.truncated, isTrue);
      }
    });

    test('a normal reply is not truncated', () async {
      for (final streaming in [true, false]) {
        h.replyText(['Hello']);
        final events = await run(
          config: h.config.copyWith(streaming: streaming),
        ).toList();
        expect(events.whereType<LlmDone>().single.truncated, isFalse);
      }
    });

    test('a malformed body is not retried', () async {
      h.replyMalformed();
      await expectLater(
        run().toList(),
        throwsA(
          isA<LlmError>().having((e) => e.retryable, 'retryable', isFalse),
        ),
      );
    });

    test('a dropped connection is retryable', () async {
      h.replyDropConnection();
      await expectLater(
        run().toList(),
        throwsA(
          isA<LlmError>()
              .having((e) => e.retryable, 'retryable', isTrue)
              .having((e) => e.kind, 'kind', LlmErrorKind.connection),
        ),
      );
    });

    test('a malformed body is a badReply', () async {
      h.replyMalformed();
      await expectLater(
        run().toList(),
        throwsA(
          isA<LlmError>().having((e) => e.kind, 'kind', LlmErrorKind.badReply),
        ),
      );
    });

    test('a server that goes silent ends with a retryable timeout', () async {
      h.replyTextThenHang('Hel');
      final events = <LlmEvent>[];
      await expectLater(
        run().forEach(events.add).timeout(const Duration(seconds: 10)),
        throwsA(
          isA<LlmError>()
              .having((e) => e.kind, 'kind', LlmErrorKind.timeout)
              .having((e) => e.retryable, 'retryable', isTrue),
        ),
      );
      expect(events.whereType<LlmTextDelta>().map((e) => e.text), ['Hel']);
    });

    test('each error status has its kind', () async {
      const kinds = {
        401: LlmErrorKind.auth,
        403: LlmErrorKind.auth,
        404: LlmErrorKind.notFound,
        429: LlmErrorKind.rateLimit,
        503: LlmErrorKind.server,
        422: LlmErrorKind.request,
      };
      for (final MapEntry(key: status, value: kind) in kinds.entries) {
        h.replyError(status, 'No');
        await expectLater(
          run().toList(),
          throwsA(isA<LlmError>().having((e) => e.kind, '$status', kind)),
        );
      }
    });

    test('408 is a retryable timeout', () async {
      h.replyError(408, 'Request Timeout');
      await expectLater(
        run().toList(),
        throwsA(
          isA<LlmError>()
              .having((e) => e.kind, 'kind', LlmErrorKind.timeout)
              .having((e) => e.retryable, 'retryable', isTrue),
        ),
      );
    });

    test('429 with Retry-After is retryable with retryAfter', () async {
      h.replyError(429, 'Slow down', headers: {'retry-after': '7'});
      await expectLater(
        run().toList(),
        throwsA(
          isA<LlmError>()
              .having((e) => e.status, 'status', 429)
              .having((e) => e.retryable, 'retryable', isTrue)
              .having(
                (e) => e.retryAfter,
                'retryAfter',
                const Duration(seconds: 7),
              ),
        ),
      );
    });

    test('500 is retryable; 401 is not', () async {
      h.replyError(500, 'Oops');
      await expectLater(
        run().toList(),
        throwsA(
          isA<LlmError>().having((e) => e.retryable, 'retryable', isTrue),
        ),
      );
      h.replyError(401, 'Bad key');
      await expectLater(
        run().toList(),
        throwsA(
          isA<LlmError>()
              .having((e) => e.retryable, 'retryable', isFalse)
              .having((e) => e.status, 'status', 401)
              .having((e) => e.message, 'message', contains('Bad key')),
        ),
      );
    });

    test('context overflow sets contextOverflow', () async {
      h.replyContextOverflow();
      await expectLater(
        run().toList(),
        throwsA(
          isA<LlmError>().having((e) => e.contextOverflow, 'overflow', isTrue),
        ),
      );
    });

    test('a dropped connection mid-stream is a retryable LlmError', () async {
      h.replyTextThenDropConnection('Hel');
      final events = <LlmEvent>[];
      await expectLater(
        run().forEach(events.add),
        throwsA(
          isA<LlmError>()
              .having((e) => e.retryable, 'retryable', isTrue)
              .having((e) => e.status, 'status', isNull),
        ),
      );
      expect(events.whereType<LlmDone>(), isEmpty);
    });

    test('cancel mid-stream closes the stream without done or error', () async {
      h.replyTextThenHang('Hel');
      final cancel = CancelToken();
      final events = <LlmEvent>[];
      final done = Completer<void>();
      run(cancel: cancel).listen(
        (e) {
          events.add(e);
          if (e is LlmTextDelta) cancel.cancel();
        },
        onError: done.completeError,
        onDone: done.complete,
      );
      await done.future.timeout(const Duration(seconds: 5));
      expect(events.whereType<LlmTextDelta>().map((e) => e.text), ['Hel']);
      expect(events.whereType<LlmDone>(), isEmpty);
    });

    test('the request carries the model, the system text, the tools and a tool '
        'result', () async {
      h.replyText(['ok']);
      await run(
        messages: [
          UserMessage('Add milk'),
          AssistantMessage(
            '',
            toolCalls: [
              ToolCall(
                id: 'c1',
                name: 'add_item',
                rawArguments: '{"title":"Milk"}',
              ),
            ],
          ),
          ToolResultMessage(
            callId: 'c1',
            name: 'add_item',
            content: '{"id":"7"}',
          ),
        ],
        tools: [
          const ToolSpec(
            name: 'add_item',
            description: 'Adds an item.',
            parameters: {'type': 'object', 'properties': {}},
          ),
        ],
      ).toList();
      final body = jsonEncode(h.lastRequestBody);
      expect(body, contains(h.config.model));
      expect(body, contains(_system));
      expect(body, contains('Adds an item.'));
      expect(body, contains('add_item'));
      expect(body, contains(r'{\"id\":\"7\"}'));
      expect(body, contains('c1'));
      expect(body, contains('Add milk'));
    });

    test('after close, requests fail without reaching the server', () async {
      h.replyText(['Hi']);
      h.provider.close();
      await expectLater(run().toList(), throwsA(isA<LlmError>()));
    });
  });
}
