import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:get_it/get_it.dart';

import '../actions/app_actions.dart';
// @example:begin
import '../repositories/items_repository.dart';
// @example:end
import '../repositories/secret_store.dart';
import '../repositories/settings_repository.dart';

class DomainLayerInjection {
  /// [serverEditable] comes from the setup file.
  // @on-device:begin
  /// [onDeviceModel] finds the in-app model for the actions that manage it;
  /// [deviceOptional] comes from the setup file.
  // @on-device:end
  static Future<void> configureDomainLayerInjection(
    GetIt getIt, {
    required bool serverEditable,
    // @on-device:begin
    required OnDeviceModelController? Function() onDeviceModel,
    required bool deviceOptional,
    // @on-device:end
  }) async {
    getIt.registerSingleton<AppActions>(
      AppActions(
        settings: getIt<SettingsRepository>(),
        secrets: getIt<SecretStore>(),
        approvals: getIt<ApprovalPrefs>(),
        serverEditable: serverEditable,
        // @on-device:begin
        onDeviceModel: onDeviceModel,
        deviceOptional: deviceOptional,
        // @on-device:end
        // @example:begin
        items: getIt<ItemsRepository>(),
        // @example:end
      ),
    );
  }
}
