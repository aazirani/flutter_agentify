import 'dart:convert';
import 'dart:io';

import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'conformance.dart';
import 'fake_llm_server.dart';

class OpenAiHarness implements ProviderHarness {
  OpenAiHarness({
    this.apiKey = 'test-key',
    this.basePath = '/v1',
    this.maxTokensField = 'max_tokens',
  });

  final String maxTokensField;

  final String? apiKey;
  final String basePath;
  final server = FakeLlmServer();
  late final OpenAiCompatibleProvider _provider = OpenAiCompatibleProvider(
    baseUrl: '${server.url}$basePath',
    apiKey: apiKey,
    maxTokensField: maxTokensField,
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

  bool get _streaming => server.lastBody['stream'] != false;

  @override
  void replyText(
    List<String> chunks, {
    int inputTokens = 10,
    int outputTokens = 5,
    bool cutOff = false,
  }) {
    final finishReason = cutOff ? 'length' : 'stop';
    final usage = {
      'prompt_tokens': inputTokens,
      'completion_tokens': outputTokens,
    };
    // Decided per request, once its body is read: streaming and plain differ.
    server.enqueue((request) async {
      final Reply reply;
      if (_streaming) {
        reply = FakeLlmServer.sseReply([
          for (final chunk in chunks)
            jsonEncode({
              'choices': [
                {
                  'index': 0,
                  'delta': {'content': chunk},
                },
              ],
            }),
          jsonEncode({
            'choices': [
              {
                'index': 0,
                'delta': <String, Object?>{},
                'finish_reason': finishReason,
              },
            ],
          }),
          jsonEncode({'choices': <Object?>[], 'usage': usage}),
          '[DONE]',
        ]);
      } else {
        reply = FakeLlmServer.jsonReply(200, {
          'choices': [
            {
              'index': 0,
              'message': {'role': 'assistant', 'content': chunks.join()},
              'finish_reason': finishReason,
            },
          ],
          'usage': usage,
        });
      }
      await reply(request);
    });
  }

  @override
  void replyToolCalls(List<ToolCall> calls, {int splitArgumentsInto = 3}) {
    server.enqueue((request) async {
      final Reply reply;
      if (_streaming) {
        reply = FakeLlmServer.sseReply([
          for (final (i, call) in calls.indexed) ...[
            jsonEncode({
              'choices': [
                {
                  'index': 0,
                  'delta': {
                    'tool_calls': [
                      {
                        'index': i,
                        'id': call.id,
                        'type': 'function',
                        'function': {'name': call.name, 'arguments': ''},
                      },
                    ],
                  },
                },
              ],
            }),
            for (final piece in splitInto(
              call.rawArguments,
              splitArgumentsInto,
            ))
              jsonEncode({
                'choices': [
                  {
                    'index': 0,
                    'delta': {
                      'tool_calls': [
                        {
                          'index': i,
                          'function': {'arguments': piece},
                        },
                      ],
                    },
                  },
                ],
              }),
          ],
          jsonEncode({
            'choices': [
              {
                'index': 0,
                'delta': <String, Object?>{},
                'finish_reason': 'tool_calls',
              },
            ],
          }),
          '[DONE]',
        ]);
      } else {
        reply = FakeLlmServer.jsonReply(200, {
          'choices': [
            {
              'index': 0,
              'message': {
                'role': 'assistant',
                'content': null,
                'tool_calls': [
                  for (final call in calls)
                    {
                      'id': call.id,
                      'type': 'function',
                      'function': {
                        'name': call.name,
                        'arguments': call.rawArguments,
                      },
                    },
                ],
              },
            },
          ],
        });
      }
      await reply(request);
    });
  }

  @override
  void replyError(
    int status,
    String message, {
    Map<String, String> headers = const {},
  }) => server.json(status, {
    'error': {'message': message, 'type': 'test_error'},
  }, headers: headers);

  @override
  void replyTextThenDropConnection(String chunk) => server.sseThenDrop([
    jsonEncode({
      'choices': [
        {
          'index': 0,
          'delta': {'content': chunk},
        },
      ],
    }),
  ]);

  @override
  void replyTextThenHang(String chunk) => server.sseThenHang([
    jsonEncode({
      'choices': [
        {
          'index': 0,
          'delta': {'content': chunk},
        },
      ],
    }),
  ]);

  @override
  void replyContextOverflow() => server.json(400, {
    'error': {
      'message': "This model's maximum context length is 8192 tokens.",
      'type': 'invalid_request_error',
      'code': 'context_length_exceeded',
    },
  });

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
  runConformance('openai-compatible', OpenAiHarness.new);

  test('close leaves a client passed in open', () async {
    final h = OpenAiHarness();
    await h.start();
    addTearDown(h.stop);
    final client = http.Client();
    addTearDown(client.close);
    final provider = OpenAiCompatibleProvider(
      baseUrl: '${h.server.url}/v1',
      client: client,
    );
    h.replyText(['Hi']);
    provider.close();
    final events = await provider
        .stream(system: 's', messages: [UserMessage('Hi')], config: h.config)
        .toList();
    expect(events.last, isA<LlmDone>());
  });

  group('openai-compatible', () {
    late OpenAiHarness h;
    Future<void> use(OpenAiHarness harness) async {
      h = harness;
      await h.start();
      addTearDown(h.stop);
    }

    Future<List<LlmEvent>> send({
      List<ChatMessage>? messages,
      List<ToolSpec> tools = const [],
    }) => h.provider
        .stream(
          system: 'System.',
          messages: messages ?? [UserMessage('Hi')],
          tools: tools,
          config: h.config,
        )
        .toList();

    test('a trailing slash in baseUrl is ignored', () async {
      await use(OpenAiHarness(basePath: '/v1//'));
      h.replyText(['ok']);
      await send();
      expect(h.server.lastPath, '/v1/chat/completions');
      expect(h.lastRequestHeaders['authorization'], 'Bearer test-key');
    });

    test('no Authorization header without a key', () async {
      await use(OpenAiHarness(apiKey: null));
      h.replyText(['ok']);
      await send();
      expect(h.lastRequestHeaders.containsKey('authorization'), isFalse);
    });

    test('tools are omitted from the body when the list is empty', () async {
      await use(OpenAiHarness());
      h.replyText(['ok']);
      await send();
      expect(h.lastRequestBody.containsKey('tools'), isFalse);
      expect(h.lastRequestBody['stream_options'], {'include_usage': true});
      expect(h.lastRequestBody['max_tokens'], 2048);
      expect((h.lastRequestBody['messages'] as List).first, {
        'role': 'system',
        'content': 'System.',
      });
    });

    test('"does not support tools" maps to toolsUnsupported', () async {
      await use(OpenAiHarness());
      h.replyError(
        400,
        'registry.ollama.ai/library/gemma:2b does not support tools',
      );
      await expectLater(
        send(),
        throwsA(
          isA<LlmError>().having((e) => e.toolsUnsupported, 'tools', isTrue),
        ),
      );
    });

    test(
      'a stream that ends without finish_reason is a retryable error',
      () async {
        await use(OpenAiHarness());
        h.server.sse([
          jsonEncode({
            'choices': [
              {
                'index': 0,
                'delta': {'content': 'Hel'},
              },
            ],
          }),
        ]);
        await expectLater(
          send(),
          throwsA(
            isA<LlmError>().having((e) => e.retryable, 'retryable', isTrue),
          ),
        );
      },
    );

    test('a context-overflow error inside the stream is flagged', () async {
      await use(OpenAiHarness());
      h.server.sse([
        jsonEncode({
          'error': {
            'message': "This model's maximum context length is 8192 tokens.",
          },
        }),
      ]);
      await expectLater(
        send(),
        throwsA(
          isA<LlmError>()
              .having((e) => e.contextOverflow, 'overflow', isTrue)
              .having((e) => e.retryable, 'retryable', isFalse),
        ),
      );
    });

    String ids(List<LlmEvent> events) =>
        events.whereType<LlmToolCall>().map((e) => e.call.id).join(',');

    String chunk(Map<String, Object?> delta, {String? finish}) => jsonEncode({
      'choices': [
        {'delta': delta, 'finish_reason': finish},
      ],
    });

    test('tool-call chunks without an index continue the last call, and an '
        'empty id gets a fresh unique one', () async {
      await use(OpenAiHarness());
      for (var i = 0; i < 2; i++) {
        h.server.sse([
          chunk({
            'tool_calls': [
              {
                'id': '',
                'function': {'name': 'add', 'arguments': '{"a":'},
              },
            ],
          }),
          chunk({
            'tool_calls': [
              {
                'function': {'arguments': '1}'},
              },
            ],
          }),
          chunk({}, finish: 'tool_calls'),
        ]);
      }
      final first = await send();
      final second = await send();
      final call = first.whereType<LlmToolCall>().single.call;
      expect(call.arguments, {'a': 1});
      expect(call.id, isNotEmpty);
      expect(ids(first) == ids(second), isFalse);
    });

    test('a mid-stream auth error is not retryable', () async {
      await use(OpenAiHarness());
      h.server.sse([
        jsonEncode({
          'error': {'message': 'Bad key.', 'type': 'invalid_request_error'},
        }),
      ]);
      await expectLater(
        send(),
        throwsA(isA<LlmError>().having((e) => e.retryable, 'retryable', false)),
      );
    });

    test(
      'a reply with only reasoning is an error, not an empty answer',
      () async {
        await use(OpenAiHarness());
        h.server.sse([
          chunk({'reasoning_content': 'Hmm.'}),
          chunk({}, finish: 'stop'),
        ]);
        await expectLater(
          send(),
          throwsA(
            isA<LlmError>().having(
              (e) => e.kind,
              'kind',
              LlmErrorKind.badReply,
            ),
          ),
        );
      },
    );

    test(
      'an HTML error page is cut short and a Retry-After date is read',
      () async {
        await use(OpenAiHarness());
        h.server.enqueue((request) async {
          final response = request.response
            ..statusCode = 502
            ..headers.set(
              'retry-after',
              HttpDate.format(DateTime.now().add(const Duration(minutes: 5))),
            )
            ..headers.contentType = ContentType.html;
          response.write('<html>${'x' * 5000}</html>');
          await response.close();
        });
        await expectLater(
          send(),
          throwsA(
            isA<LlmError>()
                .having((e) => e.message.length, 'length', lessThan(400))
                .having(
                  (e) => e.retryAfter,
                  'retryAfter',
                  greaterThan(const Duration(minutes: 4)),
                ),
          ),
        );
      },
    );

    test('maxTokensField names the output limit field', () async {
      await use(OpenAiHarness(maxTokensField: 'max_completion_tokens'));
      h.replyText(['ok']);
      await send();
      expect(h.lastRequestBody['max_completion_tokens'], 2048);
      expect(h.lastRequestBody.containsKey('max_tokens'), isFalse);
    });

    test('the user message context is appended after a blank line', () async {
      await use(OpenAiHarness());
      h.replyText(['ok']);
      await send(
        messages: [
          UserMessage('Hi', context: '<current-screen>\n{}\n</current-screen>'),
        ],
      );
      expect((h.lastRequestBody['messages'] as List)[1], {
        'role': 'user',
        'content': 'Hi\n\n<current-screen>\n{}\n</current-screen>',
      });
    });

    test('invalid stored arguments are replayed as {}', () async {
      await use(OpenAiHarness());
      h.replyText(['ok']);
      await send(
        messages: [
          UserMessage('Hi'),
          AssistantMessage(
            '',
            toolCalls: [ToolCall(id: 'c1', name: 'a', rawArguments: '{"a":')],
          ),
          ToolResultMessage(callId: 'c1', name: 'a', content: '{}'),
        ],
      );
      final assistant = (h.lastRequestBody['messages'] as List)[2] as Map;
      final calls = assistant['tool_calls'] as List;
      expect(((calls[0] as Map)['function'] as Map)['arguments'], '{}');
    });
  });

  group('live openai-compatible', () {
    final env = Platform.environment;
    final baseUrl = env['FLUTTER_AGENTIFY_LIVE_OPENAI_BASE_URL'];
    final model = env['FLUTTER_AGENTIFY_LIVE_OPENAI_MODEL'];
    final skip = baseUrl == null || model == null
        ? 'set FLUTTER_AGENTIFY_LIVE_OPENAI_BASE_URL and _MODEL to run'
        : null;
    LlmProvider provider() => OpenAiCompatibleProvider(
      baseUrl: baseUrl ?? '',
      apiKey: env['FLUTTER_AGENTIFY_LIVE_OPENAI_KEY'],
    );
    final config = ModelConfig(model: model ?? '');

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
