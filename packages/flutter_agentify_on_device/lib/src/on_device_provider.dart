import 'dart:async';
import 'dart:convert';

import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart' as edge;

import 'engine_chat.dart';

/// Parameter names Gemma's chat template takes for schema keywords and
/// leaves out of the tool, so the model never sees them. They go to the
/// model as `<name>_value` and come back under their own name.
const _hiddenNames = {
  'description',
  'type',
  'properties',
  'required',
  'nullable',
};

String _shown(String name) =>
    _hiddenNames.contains(name) ? '${name}_value' : name;

final _shownName = RegExp('^(${_hiddenNames.join('|')})_value\$');

/// [schema] with every parameter name the template would hide renamed.
Map<String, Object?> shownSchema(Map<String, Object?> schema) => {
  for (final MapEntry(:key, :value) in schema.entries)
    key: switch ((key, value)) {
      ('properties', final Map<String, Object?> props) => {
        for (final MapEntry(:key, :value) in props.entries)
          _shown(key): value is Map<String, Object?>
              ? shownSchema(value)
              : value,
      },
      ('required', final List<Object?> names) => [
        for (final n in names) n is String ? _shown(n) : n,
      ],
      ('items', final Map<String, Object?> items) => shownSchema(items),
      _ => value,
    },
};

/// [args] as the model sends them (`shown` true) or as the action reads them.
Object? _renamed(Object? args, {required bool shown}) => switch (args) {
  final Map<String, Object?> map => {
    for (final MapEntry(:key, :value) in map.entries)
      (shown ? _shown(key) : (_shownName.firstMatch(key)?.group(1) ?? key)):
          _renamed(value, shown: shown),
  },
  final List<Object?> list => [for (final v in list) _renamed(v, shown: shown)],
  _ => args,
};

Map<String, Object?> _args(Map<String, Object?> args, {required bool shown}) =>
    _renamed(args, shown: shown) as Map<String, Object?>;

/// [LlmProvider] on the engine's stateful chat. Keeps one chat warm while each
/// request only extends the last one (same system text and tools, earlier
/// messages unchanged) and feeds it only the new messages. Otherwise it opens
/// a new chat and replays the history, which is many times slower to the
/// first token (measured on macOS: 0.2 s warm against 5 s replayed).
class OnDeviceProvider implements LlmProvider {
  OnDeviceProvider(this._open);

  final OpenEngineChat _open;
  EngineChat? _chat;
  String? _key;

  /// The messages the chat holds, as JSON, not counting its own last reply.
  List<String> _held = const [];
  var _ids = 0;

  static edge.Message _toEngine(ChatMessage m) => switch (m) {
    UserMessage() => edge.Message(text: m.content, isUser: true),
    AssistantMessage(:final toolCalls) when toolCalls.isNotEmpty =>
      edge.Message.toolCall(
        calls: [
          for (final c in toolCalls)
            edge.FunctionCallResponse(
              name: c.name,
              args: _args(c.arguments ?? const {}, shown: true),
              id: c.id,
            ),
        ],
      ),
    AssistantMessage() => edge.Message(text: m.text),
    ToolResultMessage() => edge.Message.toolResponse(
      toolName: m.name,
      response: {if (m.isError) 'error': m.content else 'result': m.content},
      toolCallId: m.callId,
    ),
  };

  /// Whether [encoded] is what the chat holds, its reply, then new messages.
  bool _extends(String key, List<ChatMessage> messages, List<String> encoded) {
    if (_chat == null || _key != key) return false;
    if (encoded.length <= _held.length + 1) return false;
    if (messages[_held.length] is! AssistantMessage) return false;
    for (var i = 0; i < _held.length; i++) {
      if (_held[i] != encoded[i]) return false;
    }
    return true;
  }

  @override
  Stream<LlmEvent> stream({
    required String system,
    required List<ChatMessage> messages,
    List<ToolSpec> tools = const [],
    required ModelConfig config,
    CancelToken? cancel,
  }) async* {
    if (messages.isEmpty || (cancel?.isCancelled ?? false)) return;
    final encoded = [for (final m in messages) jsonEncode(m.toJson())];
    final key = jsonEncode([
      system,
      config.maxOutputTokens,
      for (final t in tools) [t.name, t.description, t.parameters],
    ]);
    var stopped = false;
    var finished = false;
    try {
      final EngineChat chat;
      final List<ChatMessage> fresh;
      if (_chat case final warm? when _extends(key, messages, encoded)) {
        chat = warm;
        fresh = messages.sublist(_held.length + 1);
      } else {
        await _drop();
        chat = _chat = await _open(
          system: system,
          tools: [
            for (final t in tools)
              edge.Tool(
                name: t.name,
                description: t.description,
                parameters: shownSchema(t.parameters),
              ),
          ],
          maxOutputTokens: config.maxOutputTokens,
        );
        _key = key;
        final history = messages.sublist(0, messages.length - 1);
        if (history.isNotEmpty) {
          await chat.replay([for (final m in history) _toEngine(m)]);
        }
        fresh = [messages.last];
      }
      for (final m in fresh) {
        await chat.add(_toEngine(m));
      }
      _held = encoded;
      unawaited(
        cancel?.whenCancelled.then((_) async {
          if (finished) return;
          stopped = true;
          try {
            await chat.stop();
          } on Object {
            // The reply just ended on its own; nothing is left to stop.
          }
        }),
      );

      final calls = <ToolCall>[];
      await for (final r in chat.generate()) {
        if (stopped) break;
        switch (r) {
          case edge.TextResponse(:final token):
            yield LlmTextDelta(token);
          case edge.FunctionCallResponse():
            calls.add(_call(r));
          case edge.ParallelFunctionCallResponse(calls: final many):
            calls.addAll(many.map(_call));
          case edge.ThinkingResponse():
            break;
        }
      }
      finished = true;
      if (stopped) {
        // The chat holds a reply cut short; the next request starts afresh.
        await _drop();
        return;
      }
      for (final c in calls) {
        yield LlmToolCall(c);
      }
      yield LlmDone();
    } on LlmError {
      finished = true;
      await _drop();
      rethrow;
    } on Object catch (e) {
      finished = true;
      await _drop();
      throw LlmError(
        'The model on this device failed: $e',
        kind: LlmErrorKind.other,
        contextOverflow: e is edge.ContextLimitException,
      );
    }
  }

  ToolCall _call(edge.FunctionCallResponse r) => ToolCall(
    id: r.id ?? 'call_${_ids++}',
    name: r.name,
    rawArguments: jsonEncode(_args(r.args, shown: false)),
  );

  Future<void> _drop() async {
    final chat = _chat;
    _chat = null;
    _key = null;
    _held = const [];
    await chat?.close();
  }

  @override
  void close() => unawaited(_drop());

  /// Like [close], but completes once the engine's chat is closed, so the
  /// model can be closed after it.
  Future<void> dispose() => _drop();
}
