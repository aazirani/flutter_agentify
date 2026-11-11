/// Actions, app context, agent loop and model providers that make a Dart or
/// Flutter app AI-ready. Safe to import on every platform, web included.
library;

export 'src/actions/action_context.dart';
export 'src/actions/action_failure.dart';
export 'src/actions/action_registry.dart';
export 'src/actions/agent_action.dart';
export 'src/actions/change_event.dart';
export 'src/cancel_token.dart';
export 'src/cli/action_reference.dart';
export 'src/context/app_context.dart';
export 'src/context/built_in_actions.dart';
export 'src/context/memory_actions.dart';
export 'src/context/screen_actions.dart';
export 'src/llm/anthropic_provider.dart';
export 'src/llm/llm_provider.dart';
export 'src/llm/llm_types.dart';
export 'src/llm/openai_compatible_provider.dart';
export 'src/llm/provider_presets.dart';
export 'src/loop/agent_config.dart';
export 'src/loop/agent_event.dart';
export 'src/loop/agent_session.dart';
export 'src/loop/approval.dart';
export 'src/loop/debug_snapshot.dart';
export 'src/loop/history.dart';
export 'src/loop/prompt_builder.dart';
export 'src/loop/tool_search.dart';
export 'src/on_device/assistant_setup.dart';
export 'src/on_device/on_device_engine.dart';
export 'src/on_device/on_device_model.dart';
export 'src/on_device/on_device_model_controller.dart';
export 'src/schema/schema.dart';
export 'src/secrets/redactor.dart';
export 'src/secrets/secret_patterns.dart';
export 'src/storage/in_memory_stores.dart';
export 'src/storage/memory_store.dart';
export 'src/storage/thread_store.dart';
export 'src/text.dart';
