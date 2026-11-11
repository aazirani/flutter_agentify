import '../cancel_token.dart';
import 'llm_types.dart';

/// A way to reach a model: a cloud API, a local server, the app's own proxy.
abstract class LlmProvider {
  /// Emits text and tool calls, then one [LlmDone]. Errors are [LlmError].
  /// When [cancel] fires, the stream closes without [LlmDone] and without an
  /// error.
  Stream<LlmEvent> stream({
    required String system,
    required List<ChatMessage> messages,
    List<ToolSpec> tools = const [],
    required ModelConfig config,
    CancelToken? cancel,
  });

  /// Frees the connection this provider opened itself; a client passed in
  /// stays open. Call it when the provider is replaced.
  void close();
}
