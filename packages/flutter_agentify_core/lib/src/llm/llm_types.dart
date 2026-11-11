import 'dart:convert';

/// What a model can do. It belongs to the model, not the provider: one
/// Ollama server can host models with and without tool calling.
class ModelConfig {
  const ModelConfig({
    required this.model,
    this.toolCalling = true,
    this.streaming = true,
    this.contextWindow = 8192,
    this.maxOutputTokens = 2048,
  });

  final String model;
  final bool toolCalling;
  final bool streaming;
  final int contextWindow;
  final int maxOutputTokens;

  ModelConfig copyWith({
    String? model,
    bool? toolCalling,
    bool? streaming,
    int? contextWindow,
    int? maxOutputTokens,
  }) => ModelConfig(
    model: model ?? this.model,
    toolCalling: toolCalling ?? this.toolCalling,
    streaming: streaming ?? this.streaming,
    contextWindow: contextWindow ?? this.contextWindow,
    maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
  );
}

/// A tool as the model sees it.
class ToolSpec {
  const ToolSpec({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;

  /// JSON Schema of the tool's input.
  final Map<String, Object?> parameters;
}

/// A tool call the model asked for.
class ToolCall {
  ToolCall({required this.id, required this.name, required this.rawArguments})
    : arguments = _parseArguments(rawArguments);

  final String id;
  final String name;

  /// The parsed arguments; null when [rawArguments] is not a JSON object.
  final Map<String, Object?>? arguments;

  /// The arguments exactly as the model sent them.
  final String rawArguments;

  static Map<String, Object?>? _parseArguments(String raw) {
    if (raw.trim().isEmpty) return const {};
    try {
      final value = jsonDecode(raw);
      return value is Map<String, Object?> ? value : null;
    } on FormatException {
      return null;
    }
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'arguments': rawArguments,
  };

  factory ToolCall.fromJson(Map<String, Object?> json) => ToolCall(
    id: json['id'] as String,
    name: json['name'] as String,
    rawArguments: json['arguments'] as String,
  );
}

/// A reply exactly as one provider returned it, kept so that provider can
/// send it back unchanged (for example Claude's thinking blocks, which must
/// return with the tool results they led to). Other providers ignore it.
class ProviderContent {
  const ProviderContent({required this.format, required this.blocks});

  factory ProviderContent.fromJson(Map<String, Object?> json) =>
      ProviderContent(
        format: json['format'] as String,
        blocks: [
          for (final block in json['blocks'] as List<Object?>)
            block as Map<String, Object?>,
        ],
      );

  /// Which provider wrote it, such as `anthropic`.
  final String format;
  final List<Map<String, Object?>> blocks;

  Map<String, Object?> toJson() => {'format': format, 'blocks': blocks};
}

/// One message of a conversation.
sealed class ChatMessage {
  Map<String, Object?> toJson();

  static ChatMessage fromJson(Map<String, Object?> json) =>
      switch (json['role']) {
        'user' => UserMessage(
          json['text'] as String,
          context: json['context'] as String?,
        ),
        'assistant' => AssistantMessage(
          json['text'] as String,
          toolCalls: [
            for (final call in json['toolCalls'] as List<Object?>? ?? const [])
              ToolCall.fromJson(call as Map<String, Object?>),
          ],
          providerContent: switch (json['providerContent']) {
            final Map<String, Object?> content => ProviderContent.fromJson(
              content,
            ),
            _ => null,
          },
        ),
        'tool' => ToolResultMessage(
          callId: json['callId'] as String,
          name: json['name'] as String,
          content: json['content'] as String,
          isError: json['isError'] as bool? ?? false,
        ),
        final role => throw FormatException('Unknown message role: $role'),
      };
}

/// What the person typed, plus the app state attached when it was sent.
final class UserMessage extends ChatMessage {
  UserMessage(this.text, {this.context});

  /// What the person typed; the chat shows only this.
  final String text;

  /// The `<current-screen>` block, sent to the model after [text].
  final String? context;

  /// What the model receives: [text], then a blank line and [context].
  String get content => context == null ? text : '$text\n\n$context';

  @override
  Map<String, Object?> toJson() => {
    'role': 'user',
    'text': text,
    'context': ?context,
  };
}

final class AssistantMessage extends ChatMessage {
  AssistantMessage(
    this.text, {
    this.toolCalls = const [],
    this.providerContent,
  });

  final String text;
  final List<ToolCall> toolCalls;

  /// The reply as its provider returned it, for replay to that provider.
  final ProviderContent? providerContent;

  @override
  Map<String, Object?> toJson() => {
    'role': 'assistant',
    'text': text,
    if (toolCalls.isNotEmpty)
      'toolCalls': [for (final call in toolCalls) call.toJson()],
    'providerContent': ?providerContent?.toJson(),
  };
}

final class ToolResultMessage extends ChatMessage {
  ToolResultMessage({
    required this.callId,
    required this.name,
    required this.content,
    this.isError = false,
  });

  final String callId;
  final String name;
  final String content;
  final bool isError;

  @override
  Map<String, Object?> toJson() => {
    'role': 'tool',
    'callId': callId,
    'name': name,
    'content': content,
    if (isError) 'isError': true,
  };
}

/// Tokens a request used, as the provider reported them.
class Usage {
  const Usage({required this.inputTokens, required this.outputTokens});

  final int inputTokens;
  final int outputTokens;
}

/// What a provider stream emits.
sealed class LlmEvent {}

final class LlmTextDelta extends LlmEvent {
  LlmTextDelta(this.text);

  final String text;
}

final class LlmToolCall extends LlmEvent {
  LlmToolCall(this.call);

  final ToolCall call;
}

final class LlmDone extends LlmEvent {
  LlmDone([this.usage, this.content, this.truncated = false]);

  final Usage? usage;

  /// The whole reply in the provider's own format, when it needs it back.
  final ProviderContent? content;

  /// The model stopped at its output limit.
  final bool truncated;
}

/// Why a model request failed, so a chat can say what to do next.
enum LlmErrorKind {
  /// The server could not be reached, or the connection dropped.
  connection,

  /// The server sent nothing for [llmIdleTimeout].
  timeout,

  /// The key was refused (HTTP 401 or 403).
  auth,

  /// The address or the model does not exist (HTTP 404).
  notFound,

  /// Too many requests (HTTP 429).
  rateLimit,

  /// The server failed (HTTP 5xx).
  server,

  /// The server refused the request for another reason (other HTTP 4xx).
  request,

  /// The reply could not be read, or it stopped part way.
  badReply,

  /// Anything else.
  other,
}

/// How long a provider waits for the server's first or next bytes before
/// it gives up with an [LlmErrorKind.timeout] error. A streaming model sends
/// bytes while it thinks, so only a stalled server reaches it; a model with
/// streaming off sends its whole reply at the end, so this also bounds how
/// long one reply may take.
const llmIdleTimeout = Duration(seconds: 120);

/// A failed model request.
class LlmError implements Exception {
  const LlmError(
    this.message, {
    this.status,
    LlmErrorKind? kind,
    this.retryable = false,
    this.contextOverflow = false,
    this.toolsUnsupported = false,
    this.retryAfter,
  }) : _kind = kind;

  final String message;

  /// The HTTP status, or null when the connection failed.
  final int? status;

  final LlmErrorKind? _kind;

  /// Why it failed: the kind given, or the one [status] implies.
  LlmErrorKind get kind =>
      _kind ??
      switch (status) {
        null => LlmErrorKind.other,
        401 || 403 => LlmErrorKind.auth,
        404 => LlmErrorKind.notFound,
        408 => LlmErrorKind.timeout,
        429 => LlmErrorKind.rateLimit,
        final s when s >= 500 => LlmErrorKind.server,
        _ => LlmErrorKind.request,
      };

  /// Whether the same request may succeed later.
  final bool retryable;

  /// The conversation is longer than the model's context window.
  final bool contextOverflow;

  /// The model cannot call tools.
  final bool toolsUnsupported;

  /// How long the server asked to wait before retrying.
  final Duration? retryAfter;

  @override
  String toString() =>
      status == null ? 'LlmError: $message' : 'LlmError $status: $message';
}
