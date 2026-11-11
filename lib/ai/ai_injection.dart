import 'package:flutter/services.dart';
import 'package:flutter_agentify/ai/assistant_providers.dart';
import 'package:flutter_agentify/ai/change_event_adapter.dart';
import 'package:flutter_agentify/ai/go_router_adapter.dart';
import 'package:flutter_agentify/ai/screen_contexts.dart';
import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/domain/actions/app_actions.dart';
import 'package:flutter_agentify/utils/routes/app_router.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wires the assistant's side of the app: the app context with the screen
/// table, the shared action registry, the router and change-event adapters,
/// and the assistant's runtime instructions.
Future<void> configureAi(ProviderContainer container) async {
  final getIt = ServiceLocator.getIt;
  final appContext = AppContext(screens: buildScreenContexts(container));
  final registry = buildActionRegistry(
    getIt<AppActions>(),
    appContext: appContext,
    memories: getIt<MemoryStore>(),
  );
  getIt
    ..registerSingleton<AppContext>(appContext)
    ..registerSingleton<ActionRegistry>(
      registry,
      dispose: (registry) => registry.dispose(),
    )
    ..registerSingleton<AssistantInstructions>(
      AssistantInstructions(
        await rootBundle.loadString('assets/assistant/instructions.md'),
      ),
    );
  attachRouter(AppRouter.router, appContext);
  attachChangeEvents(registry, container);
}
