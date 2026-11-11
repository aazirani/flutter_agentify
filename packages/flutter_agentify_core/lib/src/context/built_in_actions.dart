import '../actions/agent_action.dart';
import '../storage/memory_store.dart';
import 'app_context.dart';
import 'memory_actions.dart';
import 'screen_actions.dart';

/// The actions every app registers next to its own: [builtInActionNames].
List<AgentAction<Object?, Object?>> builtInActions({
  required AppContext appContext,
  required MemoryStore memories,
}) => [
  ViewScreenAction(appContext),
  NavigateAction(appContext),
  SaveMemoryAction(memories),
  DeleteMemoryAction(memories),
];
