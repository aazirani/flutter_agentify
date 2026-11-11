import 'dart:async';

import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_on_device/flutter_agentify_on_device.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart' as edge;
import 'package:flutter_test/flutter_test.dart';

/// One reply the fake chat gives: responses, an error, or a wait for stop.
typedef _Reply = ({
  List<edge.ModelResponse> responses,
  Object? error,
  bool hang,
});

_Reply _text(String text) =>
    (responses: [edge.TextResponse(text)], error: null, hang: false);

class _FakeChat implements EngineChat {
  _FakeChat(this.owner, this.system, this.tools);

  final _Opener owner;
  final String system;
  final List<edge.Tool> tools;
  final replayed = <List<edge.Message>>[];
  final added = <edge.Message>[];
  var stops = 0;
  var closes = 0;
  Completer<void>? _stopped;

  @override
  Future<void> replay(List<edge.Message> history) async =>
      replayed.add(history);

  @override
  Future<void> add(edge.Message message) async => added.add(message);

  @override
  Stream<edge.ModelResponse> generate() async* {
    final reply = owner.replies.removeAt(0);
    for (final r in reply.responses) {
      yield r;
    }
    if (reply.hang) {
      await (_stopped = Completer<void>()).future;
      return;
    }
    if (reply.error case final error?) throw error;
  }

  @override
  Future<void> stop() async {
    stops++;
    _stopped?.complete();
  }

  /// When set, [close] waits for it.
  Completer<void>? closeGate;

  @override
  Future<void> close() async {
    closes++;
    await closeGate?.future;
  }
}

class _Opener {
  final chats = <_FakeChat>[];
  final replies = <_Reply>[];
  int? maxOutputTokens;

  Future<EngineChat> open({
    required String system,
    required List<edge.Tool> tools,
    required int maxOutputTokens,
  }) async {
    this.maxOutputTokens = maxOutputTokens;
    final chat = _FakeChat(this, system, tools);
    chats.add(chat);
    return chat;
  }
}

const _config = ModelConfig(model: 'm', maxOutputTokens: 77);
const _tool = ToolSpec(
  name: 'add_item',
  description: 'Adds an item.',
  parameters: {'type': 'object'},
);

void main() {
  late _Opener opener;
  late OnDeviceProvider provider;

  setUp(() {
    opener = _Opener();
    provider = OnDeviceProvider(opener.open);
  });

  Future<List<LlmEvent>> send(
    List<ChatMessage> messages, {
    String system = 'S',
    List<ToolSpec> tools = const [_tool],
    CancelToken? cancel,
  }) => provider
      .stream(
        system: system,
        messages: messages,
        tools: tools,
        config: _config,
        cancel: cancel,
      )
      .toList();

  test('text stream: deltas then LlmDone', () async {
    opener.replies.add((
      responses: [edge.TextResponse('Hel'), edge.TextResponse('lo')],
      error: null,
      hang: false,
    ));
    final events = await send([UserMessage('Hi')]);
    expect(
      [
        for (final e in events)
          if (e is LlmTextDelta) e.text,
      ],
      ['Hel', 'lo'],
    );
    expect(events.last, isA<LlmDone>());
    expect(opener.maxOutputTokens, 77);
    expect(opener.chats.single.system, 'S');
    expect(opener.chats.single.tools.single.name, 'add_item');
    expect(opener.chats.single.added.single.text, 'Hi');
    expect(opener.chats.single.added.single.isUser, isTrue);
  });

  test('one tool call and parallel tool calls become LlmToolCall events with JSON arguments', () async {
    opener.replies
      ..add((
        responses: [
          const edge.FunctionCallResponse(
            name: 'add_item',
            args: {'title': 'Milk'},
            id: 'a',
          ),
        ],
        error: null,
        hang: false,
      ))
      ..add((
        responses: [
          const edge.ParallelFunctionCallResponse(
            calls: [
              edge.FunctionCallResponse(
                name: 'add_item',
                args: {'title': 'Eggs'},
              ),
              edge.FunctionCallResponse(
                name: 'add_item',
                args: {'title': 'Bread'},
              ),
            ],
          ),
        ],
        error: null,
        hang: false,
      ));
    final one = await send([UserMessage('Add milk')]);
    final call = one.whereType<LlmToolCall>().single.call;
    expect(call.id, 'a');
    expect(call.rawArguments, '{"title":"Milk"}');
    expect(one.last, isA<LlmDone>());

    final two = await send([UserMessage('Add eggs and bread')]);
    final calls = [for (final e in two.whereType<LlmToolCall>()) e.call];
    expect([for (final c in calls) c.arguments?['title']], ['Eggs', 'Bread']);
    expect(calls.map((c) => c.id).toSet(), hasLength(2));
    expect(calls.first.id, startsWith('call_'));
  });

  test('a parameter named like a schema keyword reaches the model renamed and '
      'comes back under its own name', () async {
    const update = ToolSpec(
      name: 'update_item',
      description: 'Changes an item.',
      parameters: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string'},
          'description': {'type': 'string', 'description': 'The new text.'},
          'meta': {
            'type': 'object',
            'properties': {
              'type': {'type': 'string'},
            },
          },
        },
        'required': ['id', 'description'],
      },
    );
    opener.replies.add((
      responses: [
        const edge.FunctionCallResponse(
          name: 'update_item',
          args: {
            'id': '7',
            'description_value': '2 liters',
            'meta': {'type_value': 'x'},
          },
        ),
      ],
      error: null,
      hang: false,
    ));
    final events = await send([UserMessage('Describe it')], tools: [update]);
    final sent = opener.chats.single.tools.single.parameters;
    expect((sent['properties'] as Map).keys, [
      'id',
      'description_value',
      'meta',
    ]);
    expect(sent['required'], ['id', 'description_value']);
    expect(
      ((sent['properties'] as Map)['description_value'] as Map)['description'],
      'The new text.',
    );
    expect(
      (((sent['properties'] as Map)['meta'] as Map)['properties'] as Map).keys,
      ['type_value'],
    );
    expect(events.whereType<LlmToolCall>().single.call.arguments, {
      'id': '7',
      'description': '2 liters',
      'meta': {'type': 'x'},
    });
  });

  final user = UserMessage('Add milk');
  final call = ToolCall(
    id: 'a',
    name: 'add_item',
    rawArguments: '{"title":"Milk"}',
  );
  final asked = AssistantMessage('', toolCalls: [call]);
  final result = ToolResultMessage(
    callId: 'a',
    name: 'add_item',
    content: '{"id":"7"}',
  );

  test('a second request that extends the first reuses the chat and adds only the new messages', () async {
    opener.replies
      ..add((
        responses: [
          const edge.FunctionCallResponse(
            name: 'add_item',
            args: {'title': 'Milk'},
            id: 'a',
          ),
        ],
        error: null,
        hang: false,
      ))
      ..add(_text('Added.'));
    await send([user]);
    await send([user, asked, result]);
    expect(opener.chats, hasLength(1));
    final added = opener.chats.single.added;
    expect(added, hasLength(2));
    expect(added.last.type, edge.MessageType.toolResponse);
    expect(added.last.toolName, 'add_item');
    expect(added.last.toolCallId, 'a');
    expect(added.last.text, '{"result":"{\\"id\\":\\"7\\"}"}');
  });

  test(
    'the assistant message the chat already holds is not added again',
    () async {
      opener.replies
        ..add(_text('Hello.'))
        ..add(_text('Fine.'));
      await send([UserMessage('Hi')]);
      await send([
        UserMessage('Hi'),
        AssistantMessage('Hello.'),
        UserMessage('How are you?'),
      ]);
      final added = opener.chats.single.added;
      expect([for (final m in added) m.text], ['Hi', 'How are you?']);
    },
  );

  test(
    'a changed system text or tool list opens a new chat and replays',
    () async {
      opener.replies
        ..add(_text('Hello.'))
        ..add(_text('Fine.'))
        ..add(_text('Still fine.'));
      await send([UserMessage('Hi')]);
      final history = [
        UserMessage('Hi'),
        AssistantMessage('Hello.'),
        UserMessage('And?'),
      ];
      await send(history, system: 'S2');
      expect(opener.chats, hasLength(2));
      expect(opener.chats.first.closes, 1);
      expect(
        [for (final m in opener.chats[1].replayed.single) m.text],
        ['Hi', 'Hello.'],
      );
      expect(opener.chats[1].added.single.text, 'And?');

      await send(
        [...history, AssistantMessage('Fine.'), UserMessage('Ok')],
        system: 'S2',
        tools: const [],
      );
      expect(opener.chats, hasLength(3));
    },
  );

  test(
    'a shorter or different history (new thread, compacted) replays',
    () async {
      opener.replies
        ..add(_text('Hello.'))
        ..add(_text('Other.'))
        ..add(_text('Again.'));
      await send([UserMessage('Hi')]);
      await send([UserMessage('Something else')]);
      expect(opener.chats, hasLength(2));
      await send([
        UserMessage('Different'),
        AssistantMessage('x'),
        UserMessage('y'),
      ]);
      expect(opener.chats, hasLength(3));
      expect(opener.chats.last.replayed.single, hasLength(2));
    },
  );

  test('first request with history replays every earlier message, tool calls paired with their results', () async {
    opener.replies.add(_text('Done.'));
    await send([
      user,
      asked,
      result,
      AssistantMessage('Added.'),
      UserMessage('Thanks'),
    ]);
    final chat = opener.chats.single;
    final replayed = chat.replayed.single;
    expect(
      [for (final m in replayed) m.type],
      [
        edge.MessageType.text,
        edge.MessageType.toolCall,
        edge.MessageType.toolResponse,
        edge.MessageType.text,
      ],
    );
    expect(replayed[1].toolCalls.single.id, 'a');
    expect(replayed[1].toolCalls.single.args, {'title': 'Milk'});
    expect(replayed[2].toolCallId, 'a');
    expect(replayed[0].isUser, isTrue);
    expect(replayed[3].isUser, isFalse);
    expect(chat.added.single.text, 'Thanks');
  });

  test('a user message sends its screen context', () async {
    opener.replies.add(_text('Ok.'));
    await send([
      UserMessage('Hi', context: '<current-screen>{}</current-screen>'),
    ]);
    expect(
      opener.chats.single.added.single.text,
      'Hi\n\n<current-screen>{}</current-screen>',
    );
  });

  test('cancel calls stop and the stream closes without LlmDone and without an error', () async {
    opener.replies.add((
      responses: [edge.TextResponse('Hel')],
      error: null,
      hang: true,
    ));
    final cancel = CancelToken();
    final events = <LlmEvent>[];
    final done = provider
        .stream(
          system: 'S',
          messages: [UserMessage('Hi')],
          config: _config,
          cancel: cancel,
        )
        .listen(events.add)
        .asFuture<void>();
    await pumpEventQueue();
    cancel.cancel();
    await done;
    expect(opener.chats.single.stops, 1);
    expect(events.whereType<LlmDone>(), isEmpty);
  });

  test(
    'an engine error is LlmError; ContextLimitException sets contextOverflow',
    () async {
      opener.replies
        ..add((responses: const [], error: Exception('boom'), hang: false))
        ..add((
          responses: const [],
          error: const edge.ContextLimitException('full'),
          hang: false,
        ));
      await expectLater(
        send([UserMessage('Hi')]),
        throwsA(
          isA<LlmError>().having((e) => e.contextOverflow, 'overflow', isFalse),
        ),
      );
      await expectLater(
        send([UserMessage('Hi')]),
        throwsA(
          isA<LlmError>().having((e) => e.contextOverflow, 'overflow', isTrue),
        ),
      );
    },
  );

  test('after an error the next request opens a new chat', () async {
    opener.replies
      ..add((responses: const [], error: Exception('boom'), hang: false))
      ..add(_text('Ok.'));
    await expectLater(send([UserMessage('Hi')]), throwsA(isA<LlmError>()));
    await send([UserMessage('Hi'), AssistantMessage(''), UserMessage('Again')]);
    expect(opener.chats, hasLength(2));
    expect(opener.chats.first.closes, 1);
  });

  test('close() closes the chat but is safe to call twice', () async {
    opener.replies.add(_text('Ok.'));
    await send([UserMessage('Hi')]);
    provider
      ..close()
      ..close();
    await pumpEventQueue();
    expect(opener.chats.single.closes, 1);
  });

  test('dispose completes only after the chat has closed', () async {
    opener.replies.add(_text('Ok.'));
    await send([UserMessage('Hi')]);
    final gate = opener.chats.single.closeGate = Completer<void>();
    var disposed = false;
    final disposing = provider.dispose().then((_) => disposed = true);
    await pumpEventQueue();
    expect(disposed, isFalse);
    gate.complete();
    await disposing;
    expect(opener.chats.single.closes, 1);
  });
}
