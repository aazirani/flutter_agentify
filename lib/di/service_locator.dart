import 'package:flutter_agentify/ai/ai_injection.dart';
import 'package:flutter_agentify/ai/assistant_setup.dart';
// @on-device:begin
import 'package:flutter_agentify/ai/on_device_model.dart';
// @on-device:end
import 'package:flutter_agentify/data/di/data_layer_injection.dart';
import 'package:flutter_agentify/domain/di/domain_layer_injection.dart';
// @on-device:begin
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
// @on-device:end
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

class ServiceLocator {
  ServiceLocator._();

  static final GetIt getIt = GetIt.instance;

  /// Registers the data, domain and assistant layers. [container] is the
  /// app's provider container, so the assistant's adapters can reach it.
  static Future<void> configure(ProviderContainer container) async {
    await DataLayerInjection.configureDataLayerInjection();
    await DomainLayerInjection.configureDomainLayerInjection(
      getIt,
      serverEditable:
          assistantSetup.usesServer && assistantSetup.server.userEditable,
      // @on-device:begin
      onDeviceModel: () => container.read(onDeviceModelProvider),
      deviceOptional: assistantSetup.mode == ModelMode.both,
      // @on-device:end
    );
    await configureAi(container);
  }
}
