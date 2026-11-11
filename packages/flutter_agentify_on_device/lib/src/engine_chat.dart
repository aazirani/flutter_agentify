import 'package:flutter_edge_ai/flutter_edge_ai.dart' as edge;

/// The engine's stateful chat, as [OnDeviceProvider] uses it; tests fake it.
abstract class EngineChat {
  /// Starts over with [history] as the conversation so far.
  Future<void> replay(List<edge.Message> history);

  Future<void> add(edge.Message message);

  /// The reply to everything added so far.
  Stream<edge.ModelResponse> generate();

  Future<void> stop();

  Future<void> close();
}

/// Opens a new [EngineChat].
typedef OpenEngineChat = Future<EngineChat> Function({
  required String system,
  required List<edge.Tool> tools,
  required int maxOutputTokens,
});

/// [EngineChat] on flutter_edge_ai's [edge.InferenceChat].
class EdgeAiChat implements EngineChat {
  EdgeAiChat(this._chat);

  final edge.InferenceChat _chat;

  @override
  Future<void> replay(List<edge.Message> history) =>
      _chat.clearHistory(replayHistory: history);

  @override
  Future<void> add(edge.Message message) => _chat.addQueryChunk(message);

  @override
  Stream<edge.ModelResponse> generate() => _chat.generateChatResponseAsync();

  @override
  Future<void> stop() => _chat.stopGeneration();

  @override
  Future<void> close() => _chat.close();
}
