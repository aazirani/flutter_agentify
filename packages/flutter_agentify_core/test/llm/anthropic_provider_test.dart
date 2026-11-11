import 'dart:convert';
import 'dart:io';

import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:test/test.dart';

import 'conformance.dart';
import 'fake_llm_server.dart';

String _event(String type, Map<String, Object?> data) =>
    jsonEncode({'type': type, ...data});

String _start(int inputTokens) => _event('message_start', {
  'message': {
    'id': 'msg_1',
    'type': 'message',
    'role': 'assistant',
    'content': <Object?>[],
    'usage': {
      'input_tokens': inputTokens,
      'cache_creation_input_tokens': 0,
      'cache_read_input_tokens': 0,
      'output_tokens': 1,
    },
  },
});

String _blockStart(int index, Map<String, Object?> block) =>
    _event('content_block_start', {'index': index, 'content_block': block});

String _delta(int index, Map<String, Object?> delta) =>
    _event('content_block_delta', {'index': index, 'delta': delta});

String _stop(int index) => _event('content_block_stop', {'index': index});

String _end(String reason, int outputTokens) => _event('message_delta', {
  'delta': {'stop_reason': reason},
  'usage': {'output_tokens': outputTokens},
});

final _messageStop = _event('message_stop', {});

class AnthropicHarness implements ProviderHarness {
  final server = FakeLlmServer();
  late final AnthropicProvider _provider = AnthropicProvider(
    apiKey: 'test-key',
    baseUrl: '${server.url}',
    // Short, so the silent-server test runs fast.
    idleTimeout: const Duration(seconds: 2),
  );

  @override
  LlmProvider get provider => _provider;

  @override
  ModelConfig get config => const ModelConfig(model: 'test-model');

  @override
  Future<void> start() => server.start();

  @override
  Future<void> stop() => server.stop();

  bool get _streaming => server.lastBody['stream'] == true;

  /// Streams [blocks] (text, thinking or tool_use) the way the API does.
  void replyBlocks(
    List<Map<String, Object?>> blocks, {
    String stopReason = 'end_turn',
    int inputTokens = 10,
    int outputTokens = 5,
    int splitInto = 3,
  }) {
    server.enqueue((request) async {
      final Reply reply;
      if (_streaming) {
        reply = FakeLlmServer.sseReply([
          _start(inputTokens),
          for (final (i, block) in blocks.indexed) ...[
            ..._streamBlock(i, block, splitInto),
            _stop(i),
          ],
          _end(stopReason, outputTokens),
          _messageStop,
        ]);
      } else {
        reply = FakeLlmServer.jsonReply(200, {
          'id': 'msg_1',
          'type': 'message',
          'role': 'assistant',
          'content': [
            for (final block in blocks)
              if (block['type'] == 'text')
                {'type': 'text', 'text': (block['chunks'] as List).join()}
              else if (block['type'] == 'tool_use')
                {
                  'type': 'tool_use',
                  'id': block['id'],
                  'name': block['name'],
                  'input': jsonDecode(block['raw'] as String),
                }
              else
                block,
          ],
          'stop_reason': stopReason,
          'usage': {'input_tokens': inputTokens, 'output_tokens': outputTokens},
        });
      }
      await reply(request);
    });
  }

  static List<String> _streamBlock(
    int i,
    Map<String, Object?> block,
    int split,
  ) => switch (block['type']) {
    'text' => [
      _blockStart(i, {'type': 'text', 'text': ''}),
      for (final chunk in block['chunks'] as List<String>)
        _delta(i, {'type': 'text_delta', 'text': chunk}),
    ],
    'thinking' => [
      _blockStart(i, {'type': 'thinking', 'thinking': '', 'signature': ''}),
      _delta(i, {'type': 'thinking_delta', 'thinking': block['thinking']}),
      _delta(i, {'type': 'signature_delta', 'signature': block['signature']}),
    ],
    _ => [
      _blockStart(i, {
        'type': 'tool_use',
        'id': block['id'],
        'name': block['name'],
        'input': <String, Object?>{},
      }),
      for (final piece in splitInto(block['raw'] as String, split))
        _delta(i, {'type': 'input_json_delta', 'partial_json': piece}),
    ],
  };

  @override
  void replyText(
    List<String> chunks, {
    int inputTokens = 10,
    int outputTokens = 5,
    bool cutOff = false,
  }) => replyBlocks(
    [
      {'type': 'text', 'chunks': chunks},
    ],
    stopReason: cutOff ? 'max_tokens' : 'end_turn',
    inputTokens: inputTokens,
    outputTokens: outputTokens,
  );

  @override
  void replyToolCalls(List<ToolCall> calls, {int splitArgumentsInto = 3}) =>
      replyBlocks(
        [
          for (final call in calls)
            {
              'type': 'tool_use',
              'id': call.id,
              'name': call.name,
              'raw': call.rawArguments,
            },
        ],
        stopReason: 'tool_use',
        splitInto: splitArgumentsInto,
      );

  @override
  void replyError(
    int status,
    String message, {
    Map<String, String> headers = const {},
  }) => server.json(status, {
    'type': 'error',
    'error': {
      'type': switch (status) {
        429 => 'rate_limit_error',
        401 => 'authentication_error',
        529 => 'overloaded_error',
        >= 500 => 'api_error',
        _ => 'invalid_request_error',
      },
      'message': message,
    },
  }, headers: headers);

  List<String> _openText(String chunk) => [
    _start(10),
    _blockStart(0, {'type': 'text', 'text': ''}),
    _delta(0, {'type': 'text_delta', 'text': chunk}),
  ];

  @override
  void replyTextThenDropConnection(String chunk) =>
      server.sseThenDrop(_openText(chunk));

  @override
  void replyTextThenHang(String chunk) => server.sseThenHang(_openText(chunk));

  @override
  void replyContextOverflow() =>
      replyError(400, 'prompt is too long: 250000 tokens > 200000 maximum');

  @override
  void replyMalformed() => server.sse(['not json']);

  @override
  void replyDropConnection() => server.drop();

  @override
  Map<String, Object?> get lastRequestBody => server.lastBody;

  @override
  Map<String, String> get lastRequestHeaders => server.lastHeaders;
}

void main() {
  runConformance('anthropic', AnthropicHarness.new);

  group('anthropic', () {
    late AnthropicHarness h;
    setUp(() async {
      h = AnthropicHarness();
      await h.start();
    });
    tearDown(() => h.stop());

    Future<List<LlmEvent>> send(
      List<ChatMessage> messages, {
      String system = 'System.',
    }) => h.provider
        .stream(system: system, messages: messages, config: h.config)
        .toList();

    List<Map<String, Object?>> sentMessages() => [
      for (final m in h.lastRequestBody['messages'] as List)
        m as Map<String, Object?>,
    ];

    test('sends x-api-key and anthropic-version headers', () async {
      h.replyText(['ok']);
      await send([UserMessage('Hi')]);
      expect(h.server.lastPath, '/v1/messages');
      expect(h.lastRequestHeaders['x-api-key'], 'test-key');
      expect(h.lastRequestHeaders['anthropic-version'], '2026-10-21');
      expect(h.lastRequestHeaders.containsKey('authorization'), isFalse);
      expect(h.lastRequestBody['max_tokens'], 2048);
      expect(h.lastRequestBody.containsKey('temperature'), isFalse);
    });

    test(
      'the system text is sent as a cached block, not as a message',
      () async {
        h.replyText(['ok']);
        await send([UserMessage('Hi')], system: 'Be brief.');
        expect(h.lastRequestBody['system'], [
          {
            'type': 'text',
            'text': 'Be brief.',
            'cache_control': {'type': 'ephemeral'},
          },
        ]);
        expect(sentMessages().map((m) => m['role']), ['user']);
      },
    );

    test('tools are sent with input_schema', () async {
      h.replyText(['ok']);
      await h.provider
          .stream(
            system: 's',
            messages: [UserMessage('Hi')],
            tools: const [
              ToolSpec(
                name: 'add',
                description: 'Adds.',
                parameters: {'type': 'object'},
              ),
            ],
            config: h.config,
          )
          .toList();
      expect(h.lastRequestBody['tools'], [
        {
          'name': 'add',
          'description': 'Adds.',
          'input_schema': {'type': 'object'},
        },
      ]);
    });

    test(
      'consecutive tool results are grouped into one user message',
      () async {
        h.replyText(['ok']);
        await send([
          UserMessage('Go'),
          AssistantMessage(
            'Working.',
            toolCalls: [
              ToolCall(id: 't1', name: 'a', rawArguments: '{"n":1}'),
              ToolCall(id: 't2', name: 'b', rawArguments: '{}'),
            ],
          ),
          ToolResultMessage(callId: 't1', name: 'a', content: 'one'),
          ToolResultMessage(
            callId: 't2',
            name: 'b',
            content: 'bad',
            isError: true,
          ),
          UserMessage('And?'),
        ]);
        final messages = sentMessages();
        expect(messages.map((m) => m['role']), ['user', 'assistant', 'user']);
        expect(messages[1]['content'], [
          {'type': 'text', 'text': 'Working.'},
          {
            'type': 'tool_use',
            'id': 't1',
            'name': 'a',
            'input': {'n': 1},
          },
          {
            'type': 'tool_use',
            'id': 't2',
            'name': 'b',
            'input': <String, Object?>{},
          },
        ]);
        expect(messages[2]['content'], [
          {'type': 'tool_result', 'tool_use_id': 't1', 'content': 'one'},
          {
            'type': 'tool_result',
            'tool_use_id': 't2',
            'content': 'bad',
            'is_error': true,
          },
          {'type': 'text', 'text': 'And?'},
        ]);
      },
    );

    test('an error event in the stream becomes an LlmError', () async {
      h.server.sse([
        _start(10),
        _event('error', {
          'error': {'type': 'overloaded_error', 'message': 'Overloaded'},
        }),
      ]);
      await expectLater(
        send([UserMessage('Hi')]),
        throwsA(
          isA<LlmError>()
              .having((e) => e.retryable, 'retryable', isTrue)
              .having((e) => e.message, 'message', 'Overloaded'),
        ),
      );
    });

    test(
      'a tool call without an id in a non-streamed reply gets tool_<index>',
      () async {
        h.server.json(200, {
          'content': [
            {'type': 'tool_use', 'name': 'add', 'input': <String, Object?>{}},
          ],
          'stop_reason': 'tool_use',
        });
        final events = await h.provider
            .stream(
              system: 's',
              messages: [UserMessage('Hi')],
              config: h.config.copyWith(streaming: false),
            )
            .toList();
        final call = events.whereType<LlmToolCall>().single.call;
        expect(call.id, startsWith('call_'));
      },
    );

    test('refusal and context-window stop reasons become errors', () async {
      for (final (reason, overflow) in [
        ('refusal', false),
        ('model_context_window_exceeded', true),
      ]) {
        h.server.json(200, {
          'content': [
            {'type': 'text', 'text': 'x'},
          ],
          'stop_reason': reason,
        });
        await expectLater(
          h.provider
              .stream(
                system: 's',
                messages: [UserMessage('Hi')],
                config: h.config.copyWith(streaming: false),
              )
              .toList(),
          throwsA(
            isA<LlmError>()
                .having((e) => e.contextOverflow, reason, overflow)
                .having((e) => e.retryable, 'retryable', isFalse),
          ),
        );
      }
    });

    test('long streamed text arrives whole', () async {
      h.replyBlocks([
        {'type': 'text', 'chunks': List.filled(2000, 'ab')},
      ]);
      final done = (await send([UserMessage('Hi')])).last as LlmDone;
      expect((done.content!.blocks.single['text'] as String).length, 4000);
    });

    test('529 overloaded is retryable', () async {
      h.replyError(529, 'Overloaded');
      await expectLater(
        send([UserMessage('Hi')]),
        throwsA(
          isA<LlmError>().having((e) => e.retryable, 'retryable', isTrue),
        ),
      );
    });

    test('usage counts cached input tokens', () async {
      h.server.sse([
        _event('message_start', {
          'message': {
            'usage': {
              'input_tokens': 5,
              'cache_creation_input_tokens': 100,
              'cache_read_input_tokens': 900,
            },
          },
        }),
        _end('end_turn', 7),
        _messageStop,
      ]);
      final done = (await send([UserMessage('Hi')])).last as LlmDone;
      expect(done.usage?.inputTokens, 1005);
      expect(done.usage?.outputTokens, 7);
    });

    test(
      'a reply keeps its raw blocks, thinking included, for replay',
      () async {
        h.replyBlocks([
          {'type': 'thinking', 'thinking': 'Plan.', 'signature': 'sig1'},
          {'type': 'tool_use', 'id': 't1', 'name': 'add', 'raw': '{"n":1}'},
        ], stopReason: 'tool_use');
        final events = await send([UserMessage('Hi')]);
        expect(events.whereType<LlmTextDelta>(), isEmpty);
        final content = (events.last as LlmDone).content;
        expect(content?.format, 'anthropic');
        expect(content?.blocks, [
          {'type': 'thinking', 'thinking': 'Plan.', 'signature': 'sig1'},
          {
            'type': 'tool_use',
            'id': 't1',
            'name': 'add',
            'input': {'n': 1},
          },
        ]);
      },
    );

    test('thinking is replayed for the current run only', () async {
      const earlier = ProviderContent(
        format: 'anthropic',
        blocks: [
          {'type': 'thinking', 'thinking': '', 'signature': 'old'},
          {'type': 'text', 'text': 'Hello.'},
        ],
      );
      const current = ProviderContent(
        format: 'anthropic',
        blocks: [
          {'type': 'thinking', 'thinking': '', 'signature': 'new'},
          {
            'type': 'tool_use',
            'id': 't1',
            'name': 'add',
            'input': {'n': 1},
          },
        ],
      );
      h.replyText(['ok']);
      await send([
        UserMessage('Hi'),
        AssistantMessage('Hello.', providerContent: earlier),
        UserMessage('Add one'),
        AssistantMessage(
          '',
          toolCalls: [ToolCall(id: 't1', name: 'add', rawArguments: '{"n":1}')],
          providerContent: current,
        ),
        ToolResultMessage(callId: 't1', name: 'add', content: '2'),
      ]);
      final messages = sentMessages();
      expect(messages[1]['content'], [
        {'type': 'text', 'text': 'Hello.'},
      ]);
      expect(messages[3]['content'], current.blocks);
    });

    test(
      'a stream that ends without message_stop is a retryable error',
      () async {
        h.server.sse([
          _start(10),
          _blockStart(0, {'type': 'text', 'text': ''}),
          _delta(0, {'type': 'text_delta', 'text': 'Hel'}),
        ]);
        await expectLater(
          send([UserMessage('Hi')]),
          throwsA(
            isA<LlmError>().having((e) => e.retryable, 'retryable', isTrue),
          ),
        );
      },
    );

    test('empty text blocks are not replayed', () async {
      h.replyText(['ok']);
      await send([
        UserMessage('Go'),
        AssistantMessage(
          '',
          toolCalls: [ToolCall(id: 't1', name: 'a', rawArguments: '{}')],
          providerContent: const ProviderContent(
            format: 'anthropic',
            blocks: [
              {'type': 'text', 'text': ''},
              {
                'type': 'tool_use',
                'id': 't1',
                'name': 'a',
                'input': <String, Object?>{},
              },
            ],
          ),
        ),
        ToolResultMessage(callId: 't1', name: 'a', content: 'ok'),
      ]);
      expect(sentMessages()[1]['content'], [
        {
          'type': 'tool_use',
          'id': 't1',
          'name': 'a',
          'input': <String, Object?>{},
        },
      ]);
    });

    test('content from another provider is not replayed', () async {
      h.replyText(['ok']);
      await send([
        UserMessage('Hi'),
        AssistantMessage(
          'Hello.',
          providerContent: const ProviderContent(
            format: 'other',
            blocks: [
              {'type': 'mystery'},
            ],
          ),
        ),
        UserMessage('Again'),
      ]);
      expect(sentMessages()[1]['content'], [
        {'type': 'text', 'text': 'Hello.'},
      ]);
    });
  });

  group('live anthropic', () {
    final env = Platform.environment;
    final key = env['FLUTTER_AGENTIFY_LIVE_ANTHROPIC_KEY'];
    final model = env['FLUTTER_AGENTIFY_LIVE_ANTHROPIC_MODEL'];
    final skip = key == null || model == null
        ? 'set FLUTTER_AGENTIFY_LIVE_ANTHROPIC_KEY and _MODEL to run'
        : null;
    LlmProvider provider() => AnthropicProvider(apiKey: key ?? '');
    final config = ModelConfig(model: model ?? '', maxOutputTokens: 4096);

    test('plain text', () async {
      final events = await provider()
          .stream(
            system: 'Reply with one word.',
            messages: [UserMessage('Hello')],
            config: config,
          )
          .toList();
      expect(events.whereType<LlmTextDelta>(), isNotEmpty);
      expect(events.last, isA<LlmDone>());
    }, skip: skip);

    test('one tool call', () async {
      final events = await provider()
          .stream(
            system: 'Use the tool.',
            messages: [UserMessage('Add milk to the list.')],
            tools: const [
              ToolSpec(
                name: 'add_item',
                description: 'Adds an item to the shopping list.',
                parameters: {
                  'type': 'object',
                  'properties': {
                    'title': {'type': 'string', 'description': 'The item.'},
                  },
                  'required': ['title'],
                },
              ),
            ],
            config: config,
          )
          .toList();
      expect(events.whereType<LlmToolCall>().first.call.name, 'add_item');
    }, skip: skip);
  });
}
