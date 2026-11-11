import 'package:flutter_agentify/ai/assistant_providers.dart';
import 'package:flutter_agentify/ai/model_route.dart';
import 'package:flutter_agentify/data/repositories/in_memory_settings_repository.dart';
import 'package:flutter_agentify/domain/entities/assistant_settings.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// A container in server mode; the server is set up when [serverModel] is
/// not empty.
Future<ProviderContainer> _container({String serverModel = 'm'}) async {
  final settings = InMemorySettingsRepository();
  await settings.setAssistantSettings(AssistantSettings(model: serverModel));
  return setUpTestServices(
    settings: settings,
    setup: const AssistantSetup(mode: ModelMode.server),
    overrides: [
      modelConnectorProvider.overrideWithValue(
        ({required presetId, required baseUrl, apiKey}) =>
            ScriptedProvider(const []),
      ),
    ],
  );
}

void main() {
  test('routeFor follows the three modes', () {
    for (final (mode, ready, server, expected) in [
      (ModelMode.server, false, true, AnsweredBy.server),
      (ModelMode.server, true, false, AnsweredBy.none),
      (ModelMode.onDevice, false, true, AnsweredBy.none),
      (ModelMode.onDevice, true, true, AnsweredBy.device),
      (ModelMode.both, false, true, AnsweredBy.server),
      (ModelMode.both, true, true, AnsweredBy.device),
      (ModelMode.both, false, false, AnsweredBy.none),
    ]) {
      expect(
        routeFor(mode, deviceReady: ready, serverConfigured: server),
        expected,
        reason: '$mode ready=$ready server=$server',
      );
    }
  });

  test('both: turned off, the server answers; without a server, the device '
      'still does', () {
    for (final (ready, server, expected) in [
      (true, true, AnsweredBy.server),
      (false, true, AnsweredBy.server),
      (true, false, AnsweredBy.device),
      (false, false, AnsweredBy.none),
    ]) {
      expect(
        routeFor(
          ModelMode.both,
          deviceReady: ready,
          serverConfigured: server,
          useDevice: false,
        ),
        expected,
        reason: 'ready=$ready server=$server',
      );
    }
    // The switch does not apply where only one model can answer.
    expect(
      routeFor(
        ModelMode.onDevice,
        deviceReady: true,
        serverConfigured: true,
        useDevice: false,
      ),
      AnsweredBy.device,
    );
  });

  test('server mode: route is server, no controller', () async {
    final c = await _container();
    expect(c.read(modelRouteProvider), AnsweredBy.server);
    await c.read(assistantSessionProvider.future);
    expect(c.read(assistantControllerProvider)?.onDevice, isFalse);
  });

  test('server mode without a model has no session', () async {
    final c = await _container(serverModel: '');
    expect(c.read(modelRouteProvider), AnsweredBy.none);
    expect(await c.read(assistantSessionProvider.future), isNull);
  });
}
