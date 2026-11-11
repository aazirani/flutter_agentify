import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:test/test.dart';

/// Returns messages newest first, which the contract forbids.
class _ReversedStore extends InMemoryThreadStore {
  @override
  Future<List<StoredMessage>> messages(String threadId) async =>
      (await super.messages(threadId)).reversed.toList();
}

/// Forgets nothing on delete, which the contract forbids.
class _StickyMemories extends InMemoryMemoryStore {
  @override
  Future<bool> delete(String id) async => true;
}

void main() {
  test(
    'InMemoryThreadStore meets the thread store contract',
    () => verifyThreadStore(InMemoryThreadStore.new),
  );

  test(
    'InMemoryMemoryStore meets the memory store contract',
    () => verifyMemoryStore(InMemoryMemoryStore.new),
  );

  test('verifyThreadStore names the broken rule', () async {
    await expectLater(
      verifyThreadStore(_ReversedStore.new),
      throwsA(
        isA<StoreContractError>().having(
          (e) => e.rule,
          'rule',
          'messages oldest first',
        ),
      ),
    );
  });

  test('verifyMemoryStore names the broken rule', () async {
    await expectLater(
      verifyMemoryStore(_StickyMemories.new),
      throwsA(
        isA<StoreContractError>().having(
          (e) => e.rule,
          'rule',
          'delete returns true once, then false',
        ),
      ),
    );
  });
}
