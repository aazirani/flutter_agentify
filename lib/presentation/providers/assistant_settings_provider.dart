import 'package:flutter_agentify/ai/model_route.dart';
import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/domain/entities/assistant_settings.dart';
import 'package:flutter_agentify/domain/repositories/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'assistant_settings_provider.g.dart';

/// The assistant's server settings. Refreshed after
/// `set_assistant_provider` runs. A server the setup file locks ignores
/// anything saved.
@Riverpod(keepAlive: true)
AssistantSettings assistantSettings(Ref ref) {
  final server = ref.watch(activeSetupProvider).server;
  return server.userEditable
      ? ServiceLocator.getIt<SettingsRepository>().getAssistantSettings()
      : AssistantSettings.fromServer(server);
}
// @on-device:begin

/// Whether the person answered the in-app model's offer with "Not now".
@Riverpod(keepAlive: true)
bool onDeviceOfferDismissed(Ref ref) =>
    ServiceLocator.getIt<SettingsRepository>().getOnDeviceOfferDismissed();

/// Whether the person lets the in-app model answer in `ModelMode.both`.
@Riverpod(keepAlive: true)
bool useOnDeviceModel(Ref ref) =>
    ServiceLocator.getIt<SettingsRepository>().getUseOnDeviceModel();
// @on-device:end
