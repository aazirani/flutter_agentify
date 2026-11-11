import 'dart:async';

import 'package:flutter_agentify/ai/assistant_providers.dart';
import 'package:flutter_agentify/ai/model_route.dart';
import 'package:flutter_agentify/ai/on_device_model.dart';
import 'package:flutter_agentify/data/repositories/in_memory_settings_repository.dart';
import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/domain/actions/app_actions.dart';
import 'package:flutter_agentify/domain/entities/assistant_settings.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_agentify_ui/flutter_agentify_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

const _spec = OnDeviceModelSpec(
  id: 'm',
  label: 'M',
  url: 'https://example.com/m',
  sizeBytes: 100,
  minRamBytes: 1,
  config: ModelConfig(model: 'device-model'),
);

AssistantSetup _setup(ModelMode mode) => AssistantSetup(
  mode: mode,
  onDevice: mode == ModelMode.server ? null : const OnDeviceSetup(model: _spec),
);

/// A container in [mode]; the server is set up when [serverModel] is not
/// empty and answers with [server].
Future<ProviderContainer> _container(
  ModelMode mode, {
  required FakeOnDeviceEngine engine,
  String serverModel = 'm',
  ScriptedProvider? server,
}) async {
  final settings = InMemorySettingsRepository();
  await settings.setAssistantSettings(AssistantSettings(model: serverModel));
  final container = setUpTestServices(
    settings: settings,
    setup: _setup(mode),
    onDeviceEngine: engine,
    overrides: [
      modelConnectorProvider.overrideWithValue(
        ({required presetId, required baseUrl, apiKey}) =>
            server ?? ScriptedProvider(const []),
      ),
    ],
  );
  container.read(onDeviceModelProvider);
  await pumpEventQueue();
  return container;
}

Future<AssistantController> _controller(ProviderContainer c) async {
  await c.read(assistantSessionProvider.future);
  final controller = c.read(assistantControllerProvider);
  if (controller == null) fail('No assistant controller.');
  await pumpEventQueue();
  return controller;
}

void main() {
  test('the web reports webDisabled unless the setup turns it on', () async {
    final engine = FakeOnDeviceEngine();
    const off = OnDeviceSetup(model: _spec);
    const on = OnDeviceSetup(model: _spec, enableOnWeb: true);
    expect(identical(engineFor(engine, off, web: false), engine), isTrue);
    expect(identical(engineFor(engine, on, web: true), engine), isTrue);
    final c = OnDeviceModelController(
      engine: engineFor(engine, off, web: true),
      spec: _spec,
      marker: InMemoryLoadMarker(),
    );
    await c.start();
    expect(
      c.state,
      isA<ModelUnsupported>().having(
        (s) => s.reason,
        'reason',
        UnsupportedReason.webDisabled,
      ),
    );
  });

  test('onDevice mode: none until Ready, then device', () async {
    final engine = FakeOnDeviceEngine()..installed = true;
    final c = await _container(ModelMode.onDevice, engine: engine);
    expect(c.read(modelRouteProvider), AnsweredBy.none);
    // The chat still opens its conversations; the state replaces the input.
    expect(
      c.read(assistantControllerProvider)?.onDevice,
      anyOf(isNull, isTrue),
    );
    await c.read(onDeviceModelProvider)!.ensureLoaded();
    await pumpEventQueue();
    expect(c.read(modelRouteProvider), AnsweredBy.device);
    expect(await c.read(assistantSessionProvider.future), isNotNull);
    expect((await _controller(c)).onDevice, isTrue);
  });

  test('both: server while downloading, device once Ready', () async {
    final gate = Completer<void>();
    final engine = FakeOnDeviceEngine()..downloadGate = gate;
    final c = await _container(ModelMode.both, engine: engine);
    final model = c.read(onDeviceModelProvider)!;
    expect(c.read(modelRouteProvider), AnsweredBy.server);
    final download = model.download();
    await pumpEventQueue();
    expect(model.state, isA<ModelDownloading>());
    expect(c.read(modelRouteProvider), AnsweredBy.server);
    gate.complete();
    await download;
    await pumpEventQueue();
    expect(c.read(modelRouteProvider), AnsweredBy.server);
    await model.ensureLoaded();
    await pumpEventQueue();
    expect(c.read(modelRouteProvider), AnsweredBy.device);
  });

  test(
    'both: the switch sends the next message to the server and back',
    () async {
      final engine = FakeOnDeviceEngine()..installed = true;
      final c = await _container(ModelMode.both, engine: engine);
      await c.read(onDeviceModelProvider)!.ensureLoaded();
      await pumpEventQueue();
      expect(c.read(modelRouteProvider), AnsweredBy.device);

      final registry = ServiceLocator.getIt<ActionRegistry>();
      final actions = ServiceLocator.getIt<AppActions>();
      await registry.run(actions.setUseOnDeviceModel, false);
      await pumpEventQueue();
      expect(c.read(modelRouteProvider), AnsweredBy.server);

      await registry.run(actions.setUseOnDeviceModel, true);
      await pumpEventQueue();
      expect(c.read(modelRouteProvider), AnsweredBy.device);
    },
  );

  test(
    'both, turned off: opening the assistant does not load the model',
    () async {
      final engine = FakeOnDeviceEngine()..installed = true;
      final c = await _container(ModelMode.both, engine: engine);
      await ServiceLocator.getIt<ActionRegistry>().run(
        ServiceLocator.getIt<AppActions>().setUseOnDeviceModel,
        false,
      );
      await _controller(c);
      c.read(assistantPanelOpenProvider.notifier).toggle();
      await pumpEventQueue();
      expect(engine.loadCalls, 0);
      expect(c.read(modelRouteProvider), AnsweredBy.server);
    },
  );

  test('onDevice mode has no switch', () async {
    final engine = FakeOnDeviceEngine();
    await _container(ModelMode.onDevice, engine: engine);
    final registry = ServiceLocator.getIt<ActionRegistry>();
    expect(registry.find('set_use_on_device_model'), isNull);
  });

  test('both without a server model: none until Ready', () async {
    final engine = FakeOnDeviceEngine()..installed = true;
    final c = await _container(ModelMode.both, engine: engine, serverModel: '');
    expect(c.read(modelRouteProvider), AnsweredBy.none);
    await c.read(onDeviceModelProvider)!.ensureLoaded();
    await pumpEventQueue();
    expect(c.read(modelRouteProvider), AnsweredBy.device);
  });

  test(
    'route does not change while a reply runs; it changes when the reply ends',
    () async {
      final server = ScriptedProvider([ScriptedStep.hang()]);
      final device = ScriptedProvider([ScriptedStep.text('From the device.')]);
      final engine = FakeOnDeviceEngine(provider: device)..installed = true;
      final c = await _container(
        ModelMode.both,
        engine: engine,
        server: server,
      );
      final chat = await _controller(c);
      final reply = chat.send('Hi');
      await pumpEventQueue();
      expect(chat.isRunning, isTrue);

      await c.read(onDeviceModelProvider)!.ensureLoaded();
      await pumpEventQueue();
      expect(c.read(modelRouteProvider), AnsweredBy.server);
      expect(identical(c.read(assistantControllerProvider), chat), isTrue);

      chat.stop();
      await reply;
      await pumpEventQueue();
      expect(c.read(modelRouteProvider), AnsweredBy.device);
      final next = await _controller(c);
      await next.send('Again');
      expect(device.requests, hasLength(1));
      expect(server.requests, hasLength(1));
    },
  );

  test(
    'the thread and its messages are the same after the route changes',
    () async {
      final server = ScriptedProvider([ScriptedStep.text('From the server.')]);
      final engine = FakeOnDeviceEngine()..installed = true;
      final c = await _container(
        ModelMode.both,
        engine: engine,
        server: server,
      );
      final chat = await _controller(c);
      await chat.newThread();
      await chat.send('Hi');
      final thread = chat.threadId;
      await c.read(onDeviceModelProvider)!.ensureLoaded();
      await pumpEventQueue();
      final next = await _controller(c);
      expect(identical(next, chat), isFalse);
      expect(next.threadId, thread);
      expect(next.items.whereType<UserItem>().single.text, 'Hi');
    },
  );

  test(
    'opening the assistant loads a Downloaded model; app start alone does not',
    () async {
      final engine = FakeOnDeviceEngine()..installed = true;
      final c = await _container(ModelMode.both, engine: engine);
      await _controller(c);
      expect(engine.loadCalls, 0);
      c.read(assistantPanelOpenProvider.notifier).toggle();
      await pumpEventQueue();
      expect(engine.loadCalls, 1);
      expect(c.read(onDeviceModelProvider)!.state, isA<ModelReady>());
    },
  );
  test('opening without asking first does not download or load past the load guard', () async {
    final engine = FakeOnDeviceEngine()..installed = true;
    final c = setUpTestServices(
      setup: const AssistantSetup(
        mode: ModelMode.onDevice,
        onDevice: OnDeviceSetup(model: _spec, askBeforeDownload: false),
      ),
      onDeviceEngine: engine,
      loadMarker: InMemoryLoadMarker(true),
    );
    // Opened at once, before the model's check at launch has finished.
    c.read(assistantPanelOpenProvider.notifier).toggle();
    await pumpEventQueue();
    expect(engine.downloadCalls, 0);
    expect(engine.loadCalls, 0);
    expect(
      c.read(onDeviceModelProvider)!.state,
      isA<ModelFailed>().having((s) => s.kind, 'kind', OnDeviceFailure.memory),
    );
  });
  test('each chat knows where its own session runs, even mid-switch', () async {
    final engine = FakeOnDeviceEngine()..installed = true;
    final c = await _container(ModelMode.both, engine: engine);
    final built = <AssistantController>[];
    c.listen(assistantControllerProvider, (_, next) {
      if (next != null) built.add(next);
    }, fireImmediately: true);
    final model = c.read(onDeviceModelProvider)!;
    await model.ensureLoaded();
    await pumpEventQueue();
    await model.delete();
    await pumpEventQueue();
    expect(built, isNotEmpty);
    for (final chat in built) {
      // The server's connection is the scripted provider; the device's is not.
      expect(chat.onDevice, chat.session.provider is! ScriptedProvider);
    }
  });
}
