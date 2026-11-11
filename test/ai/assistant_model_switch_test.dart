import 'package:flutter/material.dart';
import 'package:flutter_agentify/data/repositories/in_memory_settings_repository.dart';
import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/domain/entities/assistant_settings.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_agentify_ui/flutter_agentify_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/on_device_fixture.dart';
import '../support/test_app.dart';

AssistantSetup _setup(ModelMode mode) => AssistantSetup(
  mode: mode,
  onDevice: const OnDeviceSetup(model: testModelSpec),
);

Future<InMemorySettingsRepository> _server() async =>
    InMemorySettingsRepository()
      ..setAssistantSettings(const AssistantSettings(model: 'test'));

Finder get _input => find.descendant(
  of: find.byType(AssistantChat),
  matching: find.byType(TextField),
);

/// The header line while the test model answers on the device.
const _onDevice = 'Test model · On this device';

const _leave =
    'This conversation was answered on this device. Continue with Ollama? '
    'The whole conversation will be sent to it.';

/// Both mode: a reply answered on the device, then the model deleted from
/// the chat's menu.
Future<(ScriptedProvider, InMemoryThreadStore)> _answeredThenDeleted(
  WidgetTester tester, {
  List<ScriptedStep> server = const [],
}) async {
  final threads = InMemoryThreadStore();
  final serverModel = ScriptedProvider(server);
  final engine = FakeOnDeviceEngine(
    provider: ScriptedProvider([ScriptedStep.text('From the device.')]),
  )..installed = true;
  await pumpFullApp(
    tester,
    locale: english,
    provider: serverModel,
    settings: await _server(),
    setup: _setup(ModelMode.both),
    onDeviceEngine: engine,
    threads: threads,
  );
  await openAssistant(tester);
  expect(find.text(_onDevice), findsOneWidget);
  await sendToAssistant(tester, 'Hi');
  expect(find.text('From the device.'), findsOneWidget);
  await tester.tap(find.byTooltip('Model on this device'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete model'));
  await tester.pumpAndSettle();
  // The dialog names the model before anything is deleted.
  expect(find.text('Delete Test model?'), findsOneWidget);
  await tester.tap(find.text('Delete model').last);
  await tester.pumpAndSettle();
  expect(find.text('Ollama · test'), findsOneWidget);
  return (serverModel, threads);
}

void main() {
  testWidgets(
    'both: device reply marks the thread; model deleted; next send shows the card and sends nothing',
    (tester) async {
      final (server, threads) = await _answeredThenDeleted(tester);
      final thread = (await threads.threads()).single;
      expect(thread.unshared, isTrue);
      await sendToAssistant(tester, 'Next');
      expect(find.text(_leave), findsOneWidget);
      expect(server.requests, isEmpty);
    },
  );

  testWidgets(
    'Continue sends the whole conversation to the server and clears the flag',
    (tester) async {
      final (server, threads) = await _answeredThenDeleted(
        tester,
        server: [ScriptedStep.text('From the server.')],
      );
      await sendToAssistant(tester, 'Next');
      await tester.tap(find.text('Continue with Ollama'));
      await tester.pumpAndSettle();
      expect(find.text('From the server.'), findsOneWidget);
      final sent = server.requests.single.messages.whereType<UserMessage>();
      expect(sent.map((m) => m.text), ['Hi', 'Next']);
      expect((await threads.threads()).single.unshared, isFalse);
    },
  );

  testWidgets(
    'Start a new chat sends in a new thread; the old thread stays unshared',
    (tester) async {
      final (server, threads) = await _answeredThenDeleted(
        tester,
        server: [ScriptedStep.text('From the server.')],
      );
      final old = (await threads.threads()).single;
      await sendToAssistant(tester, 'Next');
      await tester.tap(find.text('Start a new chat'));
      await tester.pumpAndSettle();
      final sent = server.requests.single.messages.whereType<UserMessage>();
      expect(sent.map((m) => m.text), ['Next']);
      expect((await threads.thread(old.id))!.unshared, isTrue);
      expect(await threads.threads(), hasLength(2));
    },
  );

  testWidgets('a thread with only server turns is not asked', (tester) async {
    final server = ScriptedProvider([ScriptedStep.text('From the server.')]);
    await pumpFullApp(
      tester,
      locale: english,
      provider: server,
      settings: await _server(),
      setup: _setup(ModelMode.both),
      onDeviceEngine: FakeOnDeviceEngine(),
    );
    await openAssistant(tester);
    await sendToAssistant(tester, 'Hi');
    expect(find.text(_leave), findsNothing);
    expect(server.requests, hasLength(1));
  });

  testWidgets(
    'the card still appears after the app restarts with the model gone',
    (tester) async {
      // What the last run left: a conversation answered on the device.
      final threads = InMemoryThreadStore();
      final thread = await threads.createThread();
      await threads.append(thread.id, StoredMessage(UserMessage('Hi')));
      await threads.append(
        thread.id,
        StoredMessage(AssistantMessage('Hello.')),
      );
      await threads.setUnshared(thread.id, true);
      final server = ScriptedProvider(const []);
      await pumpFullApp(
        tester,
        locale: english,
        provider: server,
        settings: await _server(),
        setup: _setup(ModelMode.both),
        onDeviceEngine: FakeOnDeviceEngine(),
        threads: threads,
      );
      await openAssistant(tester);
      await sendToAssistant(tester, 'Next');
      expect(find.text(_leave), findsOneWidget);
      expect(server.requests, isEmpty);
    },
  );

  testWidgets(
    'server -> device adds the line "Now answered on this device" once',
    (tester) async {
      final engine = FakeOnDeviceEngine(
        provider: ScriptedProvider([ScriptedStep.text('From the device.')]),
      );
      await pumpFullApp(
        tester,
        locale: english,
        provider: ScriptedProvider([ScriptedStep.text('From the server.')]),
        settings: await _server(),
        setup: _setup(ModelMode.both),
        onDeviceEngine: engine,
      );
      await openAssistant(tester);
      await sendToAssistant(tester, 'Hi');
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(find.text(_onDevice), findsOneWidget);
      expect(find.text('Now answered on this device'), findsOneWidget);
      await sendToAssistant(tester, 'Again');
      expect(find.text('From the device.'), findsOneWidget);
      expect(find.text('Now answered on this device'), findsOneWidget);
    },
  );

  testWidgets(
    'Not now in both mode: card gone after restart, Download in the menu',
    (tester) async {
      final settings = await _server();
      Future<void> start() => pumpFullApp(
        tester,
        locale: english,
        provider: ScriptedProvider(const []),
        settings: settings,
        setup: _setup(ModelMode.both),
        onDeviceEngine: FakeOnDeviceEngine(),
      );
      await start();
      await openAssistant(tester);
      expect(find.text('Run the assistant on this device'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('Run the assistant on this device'), findsNothing);

      // A restart: a new app over the same saved settings.
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(ServiceLocator.getIt.reset);
      await start();
      await openAssistant(tester);
      expect(find.text('Run the assistant on this device'), findsNothing);
      await tester.tap(find.byTooltip('Model on this device'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Download ('), findsOneWidget);
    },
  );

  testWidgets('onDevice mode: no input until Ready', (tester) async {
    await pumpFullApp(
      tester,
      locale: english,
      setup: _setup(ModelMode.onDevice),
      onDeviceEngine: FakeOnDeviceEngine(
        provider: ScriptedProvider([ScriptedStep.text('Ok.')]),
      ),
    );
    await openAssistant(tester);
    expect(_input, findsNothing);
    expect(find.text('Run the assistant on this device'), findsOneWidget);
    expect(find.text('Not now'), findsNothing);
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();
    expect(_input, findsOneWidget);
    expect(find.text(_onDevice), findsOneWidget);
  });

  testWidgets('a phone opening the assistant sheet loads an installed model', (
    tester,
  ) async {
    final engine = FakeOnDeviceEngine()..installed = true;
    await pumpFullApp(
      tester,
      locale: english,
      size: const Size(400, 800),
      setup: _setup(ModelMode.both),
      onDeviceEngine: engine,
    );
    expect(engine.loadCalls, 0);
    await openAssistant(tester);
    expect(engine.loadCalls, 1);
    expect(find.text(_onDevice), findsOneWidget);
  });
}
