import 'dart:async';

import '../cancel_token.dart';
import '../llm/llm_provider.dart';
import '../llm/llm_types.dart';

/// One canned model reply for [ScriptedProvider].
sealed class ScriptedStep {
  /// Replies with [text]; [truncated] when cut at the output limit.
  factory ScriptedStep.text(
    String text, {
    Usage? usage,
    ProviderContent? providerContent,
    bool truncated = false,
  }) => _Reply(text, const [], usage, providerContent, truncated);

  /// Asks for [calls], after optional [text].
  factory ScriptedStep.toolCalls(
    List<ToolCall> calls, {
    String text = '',
    Usage? usage,
    ProviderContent? providerContent,
    bool truncated = false,
  }) => _Reply(text, calls, usage, providerContent, truncated);

  /// Fails the request with [error].
  factory ScriptedStep.error(LlmError error) => _Fail(error);

  /// Never answers; the stream closes only when the request is cancelled.
  factory ScriptedStep.hang() => const _Hang();
}

final class _Reply implements ScriptedStep {
  const _Reply(this.text, this.calls, this.usage, this.content, this.truncated);

  final String text;
  final List<ToolCall> calls;
  final Usage? usage;
  final ProviderContent? content;
  final bool truncated;
}

final class _Fail implements ScriptedStep {
  const _Fail(this.error);

  final LlmError error;
}

final class _Hang implements ScriptedStep {
  const _Hang();
}

/// A model that replies with [ScriptedStep]s in order and records every
/// request, for tests of code built on the agent loop.
class ScriptedProvider implements LlmProvider {
  ScriptedProvider(List<ScriptedStep> steps) : _steps = List.of(steps);

  final List<ScriptedStep> _steps;

  /// Every request so far, oldest first.
  final List<
    ({String system, List<ChatMessage> messages, List<ToolSpec> tools})
  >
  requests = [];

  /// Whether [close] was called.
  bool closed = false;

  @override
  void close() => closed = true;

  @override
  Stream<LlmEvent> stream({
    required String system,
    required List<ChatMessage> messages,
    List<ToolSpec> tools = const [],
    required ModelConfig config,
    CancelToken? cancel,
  }) async* {
    requests.add((
      system: system,
      messages: List.unmodifiable(messages),
      tools: List.unmodifiable(tools),
    ));
    if (_steps.isEmpty) {
      throw const LlmError('The script has no more replies.');
    }
    switch (_steps.removeAt(0)) {
      case _Reply(
        :final text,
        :final calls,
        :final usage,
        :final content,
        :final truncated,
      ):
        if (text.isNotEmpty) yield LlmTextDelta(text);
        for (final call in calls) {
          yield LlmToolCall(call);
        }
        yield LlmDone(usage, content, truncated);
      case _Fail(:final error):
        throw error;
      case _Hang():
        await (cancel?.whenCancelled ?? Completer<void>().future);
    }
  }
}
