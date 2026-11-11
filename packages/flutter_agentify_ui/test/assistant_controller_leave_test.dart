import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_agentify_ui/flutter_agentify_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// A chat whose model is on the device ([onDevice]) or a server, sharing
/// [threads] so one conversation can move between them.
(AssistantController, ScriptedProvider) _chat(
  InMemoryThreadStore threads, {
  required bool onDevice,
  List<ScriptedStep> steps = const [],
}) {
  final provider = ScriptedProvider(steps);
  final session = AgentSession(
    registry: ActionRegistry(const []),
    appContext: AppContext(screens: const {}),
    provider: provider,
    model: const ModelConfig(model: 'test'),
    threads: threads,
    memories: InMemoryMemoryStore(),
    delay: (_) async {},
  );
  return (
    AssistantController(session: session, threads: threads, onDevice: onDevice),
    provider,
  );
}

void main() {
  late InMemoryThreadStore threads;
  late String threadId;

  /// One reply answered on the device in a fresh thread.
  setUp(() async {
    threads = InMemoryThreadStore();
    final (device, _) = _chat(
      threads,
      onDevice: true,
      steps: [ScriptedStep.text('From the device.')],
    );
    await device.open();
    await device.send('Hi');
    threadId = device.threadId!;
  });

  test('a message answered on the device marks its thread', () async {
    expect((await threads.thread(threadId))!.unshared, isTrue);
  });

  test(
    'a server send in that thread waits for a choice and sends nothing',
    () async {
      final (server, provider) = _chat(threads, onDevice: false);
      await server.open(threadId: threadId);
      await server.send('Next');
      expect(provider.requests, isEmpty);
      expect(server.leavingDevice, 'Next');
      expect(server.items.whereType<UserItem>().map((i) => i.text), ['Hi']);
    },
  );

  test(
    'continueOnServer clears the flag and sends the whole conversation',
    () async {
      final (server, provider) = _chat(
        threads,
        onDevice: false,
        steps: [ScriptedStep.text('From the server.')],
      );
      await server.open(threadId: threadId);
      await server.send('Next');
      await server.continueOnServer();
      expect(server.leavingDevice, isNull);
      expect((await threads.thread(threadId))!.unshared, isFalse);
      expect(
        provider.requests.single.messages.whereType<UserMessage>().map(
          (m) => m.text,
        ),
        ['Hi', 'Next'],
      );
    },
  );

  test(
    'startNewChat sends in a new thread and the old one stays unshared',
    () async {
      final (server, provider) = _chat(
        threads,
        onDevice: false,
        steps: [ScriptedStep.text('From the server.')],
      );
      await server.open(threadId: threadId);
      await server.send('Next');
      await server.startNewChat();
      expect(server.threadId, isNot(threadId));
      expect(
        provider.requests.single.messages.whereType<UserMessage>().map(
          (m) => m.text,
        ),
        ['Next'],
      );
      expect((await threads.thread(threadId))!.unshared, isTrue);
    },
  );

  test('a thread with only server turns is not asked', () async {
    final (server, provider) = _chat(
      threads,
      onDevice: false,
      steps: [ScriptedStep.text('Ok.')],
    );
    await server.newThread();
    await server.send('Hello');
    expect(server.leavingDevice, isNull);
    expect(provider.requests, hasLength(1));
  });

  test(
    'an empty thread left marked is not asked: it has nothing to share',
    () async {
      final empty = await threads.createThread();
      await threads.setUnshared(empty.id, true);
      final (server, provider) = _chat(
        threads,
        onDevice: false,
        steps: [ScriptedStep.text('Ok.')],
      );
      await server.open(threadId: empty.id);
      await server.send('Hello');
      expect(server.leavingDevice, isNull);
      expect(provider.requests, hasLength(1));
    },
  );
}
