import 'dart:convert';

import '../actions/action_context.dart';
import '../llm/llm_types.dart';
import '../storage/memory_store.dart';
import '../storage/thread_store.dart';

/// A store broke one rule of its contract.
class StoreContractError extends Error {
  StoreContractError(this.rule);

  /// The rule, such as `messages oldest first`.
  final String rule;

  @override
  String toString() => 'Store contract broken: $rule';
}

void _expect(bool holds, String rule) {
  if (!holds) throw StoreContractError(rule);
}

String _json(Object? value) => jsonEncode(value);

/// Checks every rule a [ThreadStore] must follow, on fresh stores from
/// [create]. Throws [StoreContractError] naming the first broken rule.
Future<void> verifyThreadStore(ThreadStore Function() create) async {
  const receipt = Receipt(resource: 'items', ids: ['7'], summary: 'Added');

  var store = create();
  var thread = await store.createThread(title: 'First');
  final texts = ['one', 'two', 'three', 'four', 'five'];
  for (final text in texts) {
    await store.append(
      thread.id,
      StoredMessage(UserMessage(text), receipts: [if (text == 'two') receipt]),
    );
  }
  final stored = await store.messages(thread.id);
  _expect(
    _json([for (final m in stored) (m.message as UserMessage).text]) ==
        _json(texts),
    'messages oldest first',
  );
  _expect(
    _json(stored[1].receipts.map((r) => r.toJson()).toList()) ==
        _json([receipt.toJson()]),
    'messages keep their receipts',
  );

  await Future<void>.delayed(const Duration(milliseconds: 5));
  final second = await store.createThread();
  final threads = await store.threads();
  _expect(
    threads.length == 2 &&
        threads.first.id == second.id &&
        threads.last.id == thread.id,
    'threads newest first',
  );
  _expect((await store.thread(thread.id))?.title == 'First', 'thread by id');

  _expect(
    (await store.thread(thread.id))?.unshared == false,
    'a new thread is not unshared',
  );
  await store.setUnshared(thread.id, true);
  _expect(
    (await store.thread(thread.id))?.unshared == true &&
        (await store.threads()).any((t) => t.id == thread.id && t.unshared),
    'setUnshared is read back by thread and threads',
  );

  await store.summarize(thread.id, summary: 'Counted to three.', dropCount: 3);
  _expect(
    (await store.thread(thread.id))?.unshared == true,
    'unshared survives summarize',
  );
  await store.setUnshared(thread.id, false);
  _expect(
    (await store.thread(thread.id))?.unshared == false,
    'setUnshared false clears it',
  );
  final left = await store.messages(thread.id);
  _expect(
    _json([for (final m in left) (m.message as UserMessage).text]) ==
        _json(['four', 'five']),
    'summarize drops the oldest dropCount messages',
  );
  _expect(
    (await store.thread(thread.id))?.summary == 'Counted to three.',
    'summarize stores the summary',
  );

  await store.deleteThread(thread.id);
  _expect(
    await store.thread(thread.id) == null &&
        (await store.messages(thread.id)).isEmpty &&
        (await store.threads()).length == 1,
    'deleteThread removes the thread and its messages',
  );

  store = create();
  thread = await store.createThread();
  final kinds = <StoredMessage>[
    StoredMessage(
      UserMessage('Hi', context: '<current-screen>\n{}\n</current-screen>'),
    ),
    StoredMessage(
      AssistantMessage(
        'Adding it.',
        toolCalls: [
          ToolCall(
            id: 'c1',
            name: 'add_item',
            rawArguments: '{"title":"Milk"}',
          ),
        ],
      ),
    ),
    StoredMessage(
      ToolResultMessage(
        callId: 'c1',
        name: 'add_item',
        content: '{"error":"invalid_input"}',
        isError: true,
      ),
    ),
    StoredMessage(
      AssistantMessage(
        'Done.',
        providerContent: const ProviderContent(
          format: 'anthropic',
          blocks: [
            {'type': 'thinking', 'thinking': '', 'signature': 'abc'},
            {'type': 'text', 'text': 'Done.'},
          ],
        ),
      ),
      receipts: const [receipt],
    ),
  ];
  for (final message in kinds) {
    await store.append(thread.id, message);
  }
  _expect(
    _json((await store.messages(thread.id)).map((m) => m.toJson()).toList()) ==
        _json(kinds.map((m) => m.toJson()).toList()),
    'every message kind survives storage',
  );
}

/// Checks every rule a [MemoryStore] must follow, on a fresh store from
/// [create]. Throws [StoreContractError] naming the first broken rule.
Future<void> verifyMemoryStore(MemoryStore Function() create) async {
  final store = create();
  final first = await store.save('Likes oat milk');
  await Future<void>.delayed(const Duration(milliseconds: 5));
  final second = await store.save('Shops on Fridays');
  final all = await store.all();
  _expect(
    all.length == 2 &&
        all.first.id == first.id &&
        all.first.text == 'Likes oat milk' &&
        all.last.id == second.id,
    'save then all returns it, oldest first',
  );
  _expect(
    await store.delete(first.id) && !await store.delete(first.id),
    'delete returns true once, then false',
  );
  _expect(
    (await store.all()).map((m) => m.id).toList().join() == second.id,
    'delete removes only that memory',
  );
}
