import 'dart:async';

import 'package:flutter_agentify/ai/model_route.dart';
import 'package:flutter_agentify/di/service_locator.dart';
// @on-device:begin
import 'package:flutter_agentify/ai/on_device_model.dart';
import 'package:flutter_agentify/domain/actions/app_actions.dart';
// @on-device:end
import 'package:flutter_agentify/domain/entities/assistant_settings.dart';
import 'package:flutter_agentify/domain/repositories/secret_store.dart';
import 'package:flutter_agentify/presentation/providers/assistant_settings_provider.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_ui/flutter_agentify_ui.dart';
import 'package:get_it/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'assistant_providers.g.dart';

/// The assistant's runtime instructions, from
/// `assets/assistant/instructions.md`.
class AssistantInstructions {
  const AssistantInstructions(this.text);

  final String text;
}

/// Opens the connection to a model; tests swap in a scripted one.
typedef ModelConnector = LlmProvider Function({
  required String presetId,
  required String baseUrl,
  String? apiKey,
});

@Riverpod(keepAlive: true)
ModelConnector modelConnector(Ref ref) => buildProvider;

/// The assistant for the model [modelRouteProvider] picks; null while no
/// model can answer. Rebuilt when the route changes, and for the server when
/// its settings change or a key is saved.
@Riverpod(keepAlive: true)
Future<AgentSession?> assistantSession(Ref ref) async {
  final route = ref.watch(modelRouteProvider);
  switch (route) {
    // With nothing to answer, an app with the in-app model still shows its
    // conversations; the chat shows the model's state instead of the input.
    case AnsweredBy.none when !ref.read(activeSetupProvider).usesDevice:
      return null;
    case AnsweredBy.none || AnsweredBy.device:
      // @on-device:begin
      final model = ref.read(onDeviceModelProvider);
      final spec = ref.read(activeSetupProvider).onDevice?.model;
      if (model != null && spec != null) {
        return _session(LoadedOnDeviceModel(model), spec.config);
      }
      // @on-device:end
      return null;
    case AnsweredBy.server:
      break;
  }
  final settings = ref.watch(assistantSettingsProvider);
  if (!settings.isConfigured) return null;
  final preset = providerPresets.firstWhere(
    (p) => p.id == settings.presetId,
    orElse: () => providerPresets.last,
  );
  final model = preset.defaults.copyWith(
    model: settings.model,
    toolCalling: settings.toolCalling,
    contextWindow: settings.contextWindow,
  );
  final connect = ref.watch(modelConnectorProvider);
  // Each preset reads only its own key, so a key never reaches another server.
  // A key never goes over plain http to a non-local host.
  final uri = Uri.tryParse(settings.baseUrl);
  final insecure =
      uri != null && uri.scheme == 'http' && !isLocalHost(uri.host);
  final apiKey = preset.keyUse == KeyUse.none || insecure
      ? null
      : await _getIt<SecretStore>().getApiKey(preset.id);
  if (!ref.mounted) return null;
  final connection = connect(
    presetId: preset.id,
    baseUrl: settings.baseUrl,
    apiKey: apiKey,
  );
  ref.onDispose(connection.close);
  return _session(connection, model);
}

GetIt get _getIt => ServiceLocator.getIt;

AgentSession _session(LlmProvider provider, ModelConfig model) => AgentSession(
  registry: _getIt<ActionRegistry>(),
  appContext: _getIt<AppContext>(),
  provider: provider,
  model: model,
  threads: _getIt<ThreadStore>(),
  memories: _getIt<MemoryStore>(),
  appInstructions: _getIt<AssistantInstructions>().text,
  approvals: _getIt<ApprovalPrefs>(),
);

/// Whether [session] talks to the model inside the app.
bool _onDevice(AgentSession session) {
  // @on-device:begin
  if (session.provider is LoadedOnDeviceModel) return true;
  // @on-device:end
  return false;
}

/// The thread the chat shows, kept when the chat is rebuilt for another
/// model.
class _ShownThread {
  String? id;
}

@Riverpod(keepAlive: true)
_ShownThread _shownThread(Ref ref) => _ShownThread();

/// The chat's state for the current session, kept while the app runs so the
/// conversation survives navigation and closing the sheet.
@Riverpod(keepAlive: true)
AssistantController? assistantController(Ref ref) {
  final session = ref.watch(assistantSessionProvider).value;
  if (session == null) return null;
  final controller = AssistantController(
    session: session,
    threads: ServiceLocator.getIt<ThreadStore>(),
    onDevice: _onDevice(session),
  );
  final shown = ref.watch(_shownThreadProvider);
  final running = ref.read(replyRunningProvider.notifier);
  void sync() {
    shown.id = controller.threadId ?? shown.id;
    running.set(controller.isRunning);
  }

  controller.addListener(sync);
  ref.onDispose(() {
    session.cancel();
    controller.dispose();
    // A reply cut off by a rebuild must not hold the route.
    scheduleMicrotask(() => running.set(false));
  });
  unawaited(controller.open(threadId: shown.id));
  return controller;
}

/// Whether the side panel is open on wide screens.
@Riverpod(keepAlive: true)
class AssistantPanelOpen extends _$AssistantPanelOpen {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
    // @on-device:begin
    if (state) prepareModel();
    // @on-device:end
  }
  // @on-device:begin

  /// Opening the assistant, as a panel or a sheet, loads a downloaded in-app
  /// model (app start alone does not), or starts the download when the setup
  /// does not ask first.
  void prepareModel() {
    final model = ref.read(onDeviceModelProvider);
    if (model == null) return;
    final setup = ref.read(activeSetupProvider);
    // Turned off while a server answers: keep the model out of memory.
    if (setup.mode == ModelMode.both &&
        !ref.read(useOnDeviceModelProvider) &&
        ref.read(assistantSettingsProvider).isConfigured) {
      return;
    }
    final ask = setup.onDevice?.askBeforeDownload;
    unawaited(() async {
      // Decide on the state the launch check found, not the one before it.
      await model.started;
      if (ask == false && model.state is ModelNotDownloaded) {
        final actions = ServiceLocator.getIt<AppActions>();
        try {
          await ServiceLocator.getIt<ActionRegistry>().run(
            actions.downloadOnDeviceModel,
            null,
          );
        } on ActionFailure {
          // A device that cannot run it already shows why.
        }
      } else {
        await model.ensureLoaded();
      }
    }());
  }
  // @on-device:end
}
