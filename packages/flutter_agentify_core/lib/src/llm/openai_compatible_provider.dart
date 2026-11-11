import 'dart:convert';

import 'package:http/http.dart' as http;

import '../cancel_token.dart';
import 'llm_errors.dart';
import 'llm_provider.dart';
import 'llm_types.dart';
import 'sse.dart';

final _overflowText = RegExp(
  r'context (length|window)|maximum context|too many tokens|token limit|'
  r'prompt is too long',
  caseSensitive: false,
);
final _noToolsText = RegExp(
  r'does not support tools|tools? (is|are) not supported',
  caseSensitive: false,
);

final _refusedTypes = RegExp(
  r'auth|permission|invalid_request|invalid_api_key|not_found|billing|quota',
  caseSensitive: false,
);

const _onlyReasoning = LlmError(
  'The model thought but gave no answer.',
  kind: LlmErrorKind.badReply,
  retryable: true,
);

/// Any server speaking the OpenAI chat completions format: OpenAI,
/// OpenRouter, Ollama (`/v1`), LM Studio, llama.cpp, Gemini's compatible
/// endpoint, or the app's own proxy.
class OpenAiCompatibleProvider implements LlmProvider {
  OpenAiCompatibleProvider({
    required String baseUrl,
    this.apiKey,
    this.headers = const {},
    this.maxTokensField = 'max_tokens',
    this.idleTimeout = llmIdleTimeout,
    http.Client? client,
  }) : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  final String baseUrl;
  final String? apiKey;
  final Map<String, String> headers;

  /// The body field for the output limit. OpenAI's own API wants
  /// `max_completion_tokens`; most compatible servers take `max_tokens`.
  final String maxTokensField;

  /// How long to wait for the server's first or next bytes.
  final Duration idleTimeout;
  final http.Client _client;
  final bool _ownsClient;

  @override
  void close() {
    if (_ownsClient) _client.close();
  }

  @override
  Stream<LlmEvent> stream({
    required String system,
    required List<ChatMessage> messages,
    List<ToolSpec> tools = const [],
    required ModelConfig config,
    CancelToken? cancel,
  }) async* {
    final idle = IdleWatch(idleTimeout);
    final request =
        http.AbortableRequest(
            'POST',
            Uri.parse('$baseUrl/chat/completions'),
            abortTrigger: Future.any([?cancel?.whenCancelled, idle.trigger]),
          )
          ..headers.addAll({
            'content-type': 'application/json',
            if (apiKey case final key?) 'authorization': 'Bearer $key',
            ...headers,
          })
          ..body = jsonEncode(_body(system, messages, tools, config));

    try {
      final response = await _client.send(request);
      idle.touch();
      final body = http.ByteStream(
        response.stream.map((bytes) {
          idle.touch();
          return bytes;
        }),
      );
      if (response.statusCode >= 400) {
        final text = await body.bytesToString();
        throw _error(response.statusCode, text, response.headers);
      }
      // `await for`, not `yield*`: errors of a yielded stream skip this try.
      final events = config.streaming
          ? _streamed(body)
          : _whole(await body.bytesToString());
      await for (final event in events) {
        yield event;
      }
    } on LlmError {
      rethrow;
    } catch (e) {
      if (cancel?.isCancelled ?? false) return;
      if (idle.fired) throw timeoutError();
      if (e is http.RequestAbortedException) return;
      throw connectionError(e);
    } finally {
      idle.stop();
    }
  }

  Map<String, Object?> _body(
    String system,
    List<ChatMessage> messages,
    List<ToolSpec> tools,
    ModelConfig config,
  ) => {
    'model': config.model,
    'messages': [
      {'role': 'system', 'content': system},
      for (final message in messages) _message(message),
    ],
    maxTokensField: config.maxOutputTokens,
    'stream': config.streaming,
    if (config.streaming) 'stream_options': {'include_usage': true},
    if (tools.isNotEmpty)
      'tools': [
        for (final tool in tools)
          {
            'type': 'function',
            'function': {
              'name': tool.name,
              'description': tool.description,
              'parameters': tool.parameters,
            },
          },
      ],
  };

  Map<String, Object?> _message(ChatMessage message) => switch (message) {
    UserMessage() => {'role': 'user', 'content': message.content},
    AssistantMessage(:final text, :final toolCalls) => {
      'role': 'assistant',
      'content': text.isEmpty && toolCalls.isNotEmpty ? null : text,
      if (toolCalls.isNotEmpty)
        'tool_calls': [
          for (final call in toolCalls)
            {
              'id': call.id,
              'type': 'function',
              'function': {
                'name': call.name,
                // A model API rejects arguments that are not JSON.
                'arguments': call.arguments == null ? '{}' : call.rawArguments,
              },
            },
        ],
    },
    ToolResultMessage(:final callId, :final content) => {
      'role': 'tool',
      'tool_call_id': callId,
      'content': content,
    },
  };

  Stream<LlmEvent> _streamed(Stream<List<int>> bytes) async* {
    final calls = <int, ({String id, String name, StringBuffer args})>{};
    final reasoning = StringBuffer();
    var sawText = false;
    Usage? usage;
    var finished = false;
    var truncated = false;
    await for (final data in sseData(bytes)) {
      final chunk = jsonDecode(data);
      if (chunk is! Map<String, Object?>) continue;
      if (chunk['error'] case final Object error) {
        final message = _messageOf(error);
        final overflow = _overflowText.hasMatch(message);
        // A server's own failure may pass later; a refused key or a bad
        // request will not.
        final type = error is Map<String, Object?> ? '${error['type']}' : '';
        final refused = _refusedTypes.hasMatch(type);
        throw LlmError(
          message,
          kind: refused ? LlmErrorKind.request : null,
          retryable: !overflow && !refused,
          contextOverflow: overflow,
        );
      }
      usage = _usage(chunk['usage']) ?? usage;
      final choices = chunk['choices'];
      if (choices is! List || choices.isEmpty) continue;
      final choice = choices.first as Map<String, Object?>;
      if (choice['finish_reason'] case final Object reason) {
        finished = true;
        truncated = reason == 'length';
      }
      final delta = choice['delta'];
      if (delta is! Map<String, Object?>) continue;
      if (delta['content'] case final String text when text.isNotEmpty) {
        sawText = true;
        yield LlmTextDelta(text);
      }
      // Reasoning models may send their thinking apart from the reply.
      for (final key in const ['reasoning_content', 'reasoning']) {
        if (delta[key] case final String thought) reasoning.write(thought);
      }
      for (final part in delta['tool_calls'] as List<Object?>? ?? const []) {
        if (part is! Map<String, Object?>) continue;
        final id = part['id'];
        final hasId = id is String && id.isNotEmpty;
        // A chunk without an index starts a call when it has an id, else it
        // continues the last one.
        final index =
            part['index'] as int? ??
            (hasId || calls.isEmpty ? calls.length : calls.keys.last);
        final function = part['function'] as Map<String, Object?>? ?? const {};
        final call = calls.putIfAbsent(
          index,
          () => (
            id: hasId ? id : fallbackCallId(),
            name: function['name'] as String? ?? '',
            args: StringBuffer(),
          ),
        );
        call.args.write(function['arguments'] as String? ?? '');
      }
    }
    if (!finished) {
      throw const LlmError(
        'The reply was cut off.',
        kind: LlmErrorKind.badReply,
        retryable: true,
      );
    }
    if (!truncated && !sawText && calls.isEmpty && reasoning.isNotEmpty) {
      throw _onlyReasoning;
    }
    for (final index in calls.keys.toList()..sort()) {
      final call = calls[index];
      if (call == null) continue;
      yield LlmToolCall(
        ToolCall(id: call.id, name: call.name, rawArguments: '${call.args}'),
      );
    }
    yield LlmDone(usage, null, truncated);
  }

  Stream<LlmEvent> _whole(String text) async* {
    final body = jsonDecode(text) as Map<String, Object?>;
    final choices = body['choices'] as List<Object?>? ?? const [];
    final choice = choices.isEmpty
        ? const <String, Object?>{}
        : choices.first as Map<String, Object?>;
    final message = choice['message'] as Map<String, Object?>? ?? const {};
    final thought = message['reasoning_content'] ?? message['reasoning'];
    final reasoned = thought is String && thought.isNotEmpty;
    if (message['content'] case final String content when content.isNotEmpty) {
      yield LlmTextDelta(content);
    } else if (reasoned &&
        (message['tool_calls'] as List<Object?>? ?? const []).isEmpty &&
        choice['finish_reason'] != 'length') {
      throw _onlyReasoning;
    }
    for (final call in message['tool_calls'] as List<Object?>? ?? const []) {
      final map = call as Map<String, Object?>;
      final function = map['function'] as Map<String, Object?>? ?? const {};
      final id = map['id'];
      yield LlmToolCall(
        ToolCall(
          id: id is String && id.isNotEmpty ? id : fallbackCallId(),
          name: function['name'] as String? ?? '',
          rawArguments: function['arguments'] as String? ?? '',
        ),
      );
    }
    yield LlmDone(
      _usage(body['usage']),
      null,
      choice['finish_reason'] == 'length',
    );
  }

  static Usage? _usage(Object? json) => json is Map<String, Object?>
      ? Usage(
          inputTokens: json['prompt_tokens'] as int? ?? 0,
          outputTokens: json['completion_tokens'] as int? ?? 0,
        )
      : null;

  static String _messageOf(Object? error) => switch (error) {
    {'message': final String message} => shortBody(message),
    final String message => shortBody(message),
    _ => shortBody('$error'),
  };

  static LlmError _error(int status, String body, Map<String, String> headers) {
    Object? error;
    try {
      final json = jsonDecode(body);
      error = json is Map<String, Object?> ? json['error'] ?? json : json;
    } on FormatException {
      error = shortBody(body);
    }
    final message = _messageOf(error);
    final code = error is Map<String, Object?> ? error['code'] : null;
    return LlmError(
      message,
      status: status,
      retryable: status == 408 || status == 429 || status >= 500,
      retryAfter: parseRetryAfter(headers['retry-after']),
      contextOverflow:
          code == 'context_length_exceeded' || _overflowText.hasMatch(message),
      toolsUnsupported: status == 400 && _noToolsText.hasMatch(message),
    );
  }
}
