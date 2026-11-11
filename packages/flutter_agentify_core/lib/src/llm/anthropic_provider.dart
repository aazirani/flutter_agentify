import 'dart:convert';

import 'package:http/http.dart' as http;

import '../cancel_token.dart';
import 'llm_errors.dart';
import 'llm_provider.dart';
import 'llm_types.dart';
import 'sse.dart';

const _format = 'anthropic';
const _apiVersion = '2026-10-21';
const _retryableTypes = {'rate_limit_error', 'api_error', 'overloaded_error'};
final _tooLong = RegExp(
  r'prompt is too long|too many tokens',
  caseSensitive: false,
);

/// Claude through Anthropic's Messages API.
///
/// Claude's thinking blocks come back in [LlmDone.content] and are sent back
/// for the tool rounds of the current run; earlier turns are sent without
/// them, which the API allows.
class AnthropicProvider implements LlmProvider {
  AnthropicProvider({
    required this.apiKey,
    String baseUrl = 'https://api.anthropic.com',
    this.idleTimeout = llmIdleTimeout,
    http.Client? client,
  }) : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  final String apiKey;
  final String baseUrl;

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
            Uri.parse('$baseUrl/v1/messages'),
            abortTrigger: Future.any([?cancel?.whenCancelled, idle.trigger]),
          )
          ..headers.addAll({
            'content-type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': _apiVersion,
          })
          ..body = jsonEncode({
            'model': config.model,
            'max_tokens': config.maxOutputTokens,
            'stream': config.streaming,
            'system': [
              {
                'type': 'text',
                'text': system,
                'cache_control': {'type': 'ephemeral'},
              },
            ],
            'messages': _messages(messages),
            if (tools.isNotEmpty)
              'tools': [
                for (final tool in tools)
                  {
                    'name': tool.name,
                    'description': tool.description,
                    'input_schema': tool.parameters,
                  },
              ],
          });

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

  /// The conversation as alternating user and assistant messages. Thinking
  /// blocks are kept only after the last person message (the current run's
  /// tool rounds, where the API needs them); dropping the earlier, leading
  /// ones is allowed.
  static List<Map<String, Object?>> _messages(List<ChatMessage> messages) {
    final lastUser = messages.lastIndexWhere((m) => m is UserMessage);
    final result = <Map<String, Object?>>[];
    void add(String role, List<Map<String, Object?>> blocks) {
      if (blocks.isEmpty) return;
      if (result.isNotEmpty && result.last['role'] == role) {
        (result.last['content'] as List<Map<String, Object?>>).addAll(blocks);
      } else {
        result.add({'role': role, 'content': blocks});
      }
    }

    for (final (i, message) in messages.indexed) {
      switch (message) {
        case UserMessage():
          add('user', [
            {'type': 'text', 'text': message.content},
          ]);
        case ToolResultMessage(:final callId, :final content, :final isError):
          add('user', [
            {
              'type': 'tool_result',
              'tool_use_id': callId,
              'content': content,
              if (isError) 'is_error': true,
            },
          ]);
        case AssistantMessage():
          add(
            'assistant',
            _assistantBlocks(message, keepThinking: i > lastUser),
          );
      }
    }
    return result;
  }

  static List<Map<String, Object?>> _assistantBlocks(
    AssistantMessage message, {
    required bool keepThinking,
  }) {
    final raw = message.providerContent;
    if (raw != null && raw.format == _format) {
      return [
        for (final block in raw.blocks)
          if ((keepThinking ||
                  (block['type'] != 'thinking' &&
                      block['type'] != 'redacted_thinking')) &&
              !(block['type'] == 'text' && block['text'] == ''))
            block,
      ];
    }
    return [
      if (message.text.isNotEmpty) {'type': 'text', 'text': message.text},
      for (final call in message.toolCalls)
        {
          'type': 'tool_use',
          'id': call.id,
          'name': call.name,
          'input': call.arguments ?? const <String, Object?>{},
        },
    ];
  }

  Stream<LlmEvent> _streamed(Stream<List<int>> bytes) async* {
    final blocks = <int, Map<String, Object?>>{};
    final partialJson = <int, StringBuffer>{};
    // Text, thinking and signature per block, joined at content_block_stop.
    final strings = <int, Map<String, StringBuffer>>{};
    var inputTokens = 0;
    var outputTokens = 0;
    var sawUsage = false;
    var stopped = false;
    var truncated = false;
    String? stopReason;

    await for (final data in sseData(bytes)) {
      final event = jsonDecode(data);
      if (event is! Map<String, Object?>) continue;
      final index = event['index'] as int? ?? 0;
      switch (event['type']) {
        case 'message_start':
          final message = event['message'];
          if (message is Map<String, Object?>) {
            if (message['usage'] case final Map<String, Object?> usage) {
              sawUsage = true;
              inputTokens = _inputTokens(usage);
              outputTokens = usage['output_tokens'] as int? ?? 0;
            }
          }
        case 'content_block_start':
          blocks[index] = Map.of(
            event['content_block'] as Map<String, Object?>? ?? const {},
          );
        case 'content_block_delta':
          final block = blocks[index];
          final delta = event['delta'];
          if (block == null || delta is! Map<String, Object?>) continue;
          StringBuffer buffer(String field) => strings
              .putIfAbsent(index, () => {})
              .putIfAbsent(
                field,
                () => StringBuffer(block[field] as String? ?? ''),
              );
          switch (delta['type']) {
            case 'text_delta':
              final text = delta['text'] as String? ?? '';
              buffer('text').write(text);
              if (text.isNotEmpty) yield LlmTextDelta(text);
            case 'thinking_delta':
              buffer('thinking').write(delta['thinking'] as String? ?? '');
            case 'signature_delta':
              buffer('signature').write(delta['signature'] as String? ?? '');
            case 'input_json_delta':
              partialJson
                  .putIfAbsent(index, StringBuffer.new)
                  .write(delta['partial_json'] as String? ?? '');
          }
        case 'content_block_stop':
          final block = blocks[index];
          strings
              .remove(index)
              ?.forEach((field, text) => block?[field] = '$text');
          if (block != null && block['type'] == 'tool_use') {
            final raw = '${partialJson[index] ?? ''}';
            final call = ToolCall(
              id: _callId(block['id']),
              name: block['name'] as String? ?? '',
              rawArguments: raw,
            );
            block['input'] = call.arguments ?? const <String, Object?>{};
            yield LlmToolCall(call);
          }
        case 'message_delta':
          if (event['delta'] case {'stop_reason': final String reason}) {
            stopReason = reason;
            truncated = reason == 'max_tokens';
          }
          if (event['usage'] case final Map<String, Object?> usage) {
            sawUsage = true;
            outputTokens = usage['output_tokens'] as int? ?? outputTokens;
          }
        case 'message_stop':
          stopped = true;
        case 'error':
          throw _streamError(event['error']);
      }
    }
    if (!stopped) {
      throw const LlmError(
        'The reply was cut off.',
        kind: LlmErrorKind.badReply,
        retryable: true,
      );
    }
    _checkStop(stopReason);
    yield LlmDone(
      sawUsage
          ? Usage(inputTokens: inputTokens, outputTokens: outputTokens)
          : null,
      ProviderContent(
        format: _format,
        blocks: [
          for (final index in blocks.keys.toList()..sort()) ?blocks[index],
        ],
      ),
      truncated,
    );
  }

  Stream<LlmEvent> _whole(String text) async* {
    final body = jsonDecode(text) as Map<String, Object?>;
    final content = [
      for (final block in body['content'] as List<Object?>? ?? const [])
        block as Map<String, Object?>,
    ];
    for (final block in content) {
      switch (block['type']) {
        case 'text':
          if (block['text'] case final String text when text.isNotEmpty) {
            yield LlmTextDelta(text);
          }
        case 'tool_use':
          yield LlmToolCall(
            ToolCall(
              id: _callId(block['id']),
              name: block['name'] as String? ?? '',
              rawArguments: jsonEncode(block['input'] ?? const {}),
            ),
          );
      }
    }
    final usage = body['usage'];
    final stop = body['stop_reason'];
    _checkStop(stop is String ? stop : null);
    yield LlmDone(
      usage is Map<String, Object?>
          ? Usage(
              inputTokens: _inputTokens(usage),
              outputTokens: usage['output_tokens'] as int? ?? 0,
            )
          : null,
      ProviderContent(format: _format, blocks: content),
      body['stop_reason'] == 'max_tokens',
    );
  }

  /// A tool call id; the server's, or one of ours when it sent none.
  static String _callId(Object? id) =>
      id is String && id.isNotEmpty ? id : fallbackCallId();

  /// Turns the stop reasons that are not a normal end into errors.
  static void _checkStop(String? reason) {
    switch (reason) {
      case 'refusal':
        throw const LlmError(
          'The model declined to answer this request.',
          kind: LlmErrorKind.request,
        );
      case 'model_context_window_exceeded':
        throw const LlmError(
          'The conversation is longer than the model can read.',
          contextOverflow: true,
        );
    }
  }

  /// All input tokens: uncached, written to the cache and read from it.
  static int _inputTokens(Map<String, Object?> usage) =>
      (usage['input_tokens'] as int? ?? 0) +
      (usage['cache_creation_input_tokens'] as int? ?? 0) +
      (usage['cache_read_input_tokens'] as int? ?? 0);

  static LlmError _streamError(Object? error) {
    final map = error is Map<String, Object?> ? error : const {};
    final message = map['message'] as String? ?? '$error';
    return LlmError(
      message,
      kind: switch (map['type']) {
        'rate_limit_error' => LlmErrorKind.rateLimit,
        'overloaded_error' || 'api_error' => LlmErrorKind.server,
        _ => null,
      },
      retryable: _retryableTypes.contains(map['type']),
      contextOverflow: _tooLong.hasMatch(message),
    );
  }

  static LlmError _error(int status, String body, Map<String, String> headers) {
    var message = shortBody(body);
    var type = '';
    try {
      final json = jsonDecode(body);
      if (json case {'error': final Map<String, Object?> error}) {
        message = error['message'] as String? ?? message;
        type = error['type'] as String? ?? '';
      }
    } on FormatException {
      // Not JSON: the cut body is the message.
    }
    return LlmError(
      message,
      status: status,
      retryable:
          status == 408 ||
          status == 429 ||
          status >= 500 ||
          _retryableTypes.contains(type),
      retryAfter: parseRetryAfter(headers['retry-after']),
      contextOverflow: status == 400 && _tooLong.hasMatch(message),
    );
  }
}
