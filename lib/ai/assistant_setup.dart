import 'package:flutter_agentify_core/flutter_agentify_core.dart';
// @on-device:begin
import 'package:flutter_agentify_on_device/flutter_agentify_on_device.dart';

// @on-device:end

/// Where the assistant's model runs: the one place to change it.
///
/// `mode`: `ModelMode.server` (a model server), `ModelMode.onDevice` (only
/// the model inside the app) or `ModelMode.both` (the model inside the app
/// once it is ready, the server until then).
const assistantSetup = AssistantSetup(
  mode: ModelMode.both,
  // @on-device:begin
  onDevice: OnDeviceSetup(model: gemma4E2b),
  // @on-device:end
  server: ServerSetup(),
);
