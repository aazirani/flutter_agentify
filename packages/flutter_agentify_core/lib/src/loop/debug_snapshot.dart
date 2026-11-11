import '../llm/llm_types.dart';
import 'agent_event.dart';

/// What the last model request looked like, for the debug inspector.
class DebugSnapshot {
  const DebugSnapshot({
    required this.system,
    required this.activeTools,
    required this.lastCalls,
    this.lastUsage,
  });

  final String system;
  final List<String> activeTools;

  /// Tool calls of the last run, in order.
  final List<ToolFinished> lastCalls;
  final Usage? lastUsage;
}
