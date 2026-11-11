import 'dart:async';

import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:test/test.dart';

import '../actions/fake_action.dart';

/// Everything an [AgentSession] needs, with in-memory parts.
class LoopFixture {
  LoopFixture(
    List<ScriptedStep> steps, {
    List<AgentAction<Object?, Object?>>? actions,
    this.config = const AgentConfig(),
    ModelConfig? model,
    this.approvals,
    InMemoryMemoryStore? memories,
    InMemoryThreadStore? threads,
    Future<void> Function(Duration)? delay,
  }) : _delayOverride = delay,
       threads = threads ?? InMemoryThreadStore(),
       memories = memories ?? InMemoryMemoryStore(),
       provider = ScriptedProvider(steps),
       model = model ?? const ModelConfig(model: 'test-model') {
    registry = ActionRegistry(
      actions ??
          [
            echo(),
            addNote(),
            FakeAction(
              'boom',
              readOnly: true,
              resources: const [],
              run: (_, _) async => throw StateError('kaput'),
            ),
          ],
    );
  }

  final ScriptedProvider provider;
  final Future<void> Function(Duration)? _delayOverride;
  final ApprovalPrefs? approvals;
  final ModelConfig model;
  final AgentConfig config;
  late final ActionRegistry registry;
  final InMemoryThreadStore threads;
  final InMemoryMemoryStore memories;
  final delays = <Duration>[];
  final appContext = AppContext(
    screens: {
      '/': ScreenContext((_) => {'items': 2}),
    },
  );

  late final AgentSession session = AgentSession(
    registry: registry,
    appContext: appContext,
    provider: provider,
    model: model,
    threads: threads,
    memories: memories,
    appInstructions: 'Test app.',
    config: config,
    delay: (d) async {
      delays.add(d);
      await _delayOverride?.call(d);
    },
    approvals: approvals,
  );

  late final Future<String> threadId = threads.createThread().then((t) => t.id);

  Future<List<AgentEvent>> send(String text) async =>
      session.send(await threadId, text).toList();

  Future<List<StoredMessage>> stored() async =>
      threads.messages(await threadId);

  /// Every stored tool call has a later stored result with the same id.
  Future<void> expectThreadValid() async {
    final messages = (await stored()).map((m) => m.message).toList();
    for (final (i, message) in messages.indexed) {
      if (message is! AssistantMessage) continue;
      for (final call in message.toolCalls) {
        final answered = messages
            .skip(i + 1)
            .whereType<ToolResultMessage>()
            .any((r) => r.callId == call.id);
        expect(answered, isTrue, reason: 'call ${call.id} has no result');
      }
    }
  }
}

ToolCall call(String id, String name, Map<String, Object?> args) =>
    ToolCall(id: id, name: name, rawArguments: _json(args));

String _json(Map<String, Object?> args) => [
  '{',
  [for (final MapEntry(:key, :value) in args.entries) '"$key":${_value(value)}']
      .join(','),
  '}',
].join();

String _value(Object? v) => v is String ? '"$v"' : '$v';

/// Collects events and reacts to them while the run goes on.
Future<List<AgentEvent>> listen(
  Stream<AgentEvent> stream,
  void Function(AgentEvent event) onEvent,
) {
  final events = <AgentEvent>[];
  final done = Completer<List<AgentEvent>>();
  stream.listen(
    (e) {
      events.add(e);
      onEvent(e);
    },
    onDone: () => done.complete(events),
    onError: done.completeError,
  );
  return done.future.timeout(const Duration(seconds: 5));
}
