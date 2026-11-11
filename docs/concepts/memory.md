# Memory

The assistant keeps two kinds of data:

- **Threads.** Each conversation, with its messages, tool calls and receipts.
- **Memories.** Short facts the assistant saved for later conversations, such as "the person writes in Farsi".

Both live behind an interface in the core package: `ThreadStore` and `MemoryStore`.

## Why

Threads let the person come back to a conversation after the app restarts. Memories let the assistant keep a preference without the person repeating it. The interfaces let an app keep both anywhere: in memory, in a database or on a server.

## Saving a memory

The model saves a fact with the built-in `save_memory` action and forgets one with `delete_memory`. Both ask the person first. Saved facts go into the model's system text on the next run, marked as facts, not instructions. The list is cut at 1500 characters, oldest first. The person sees the saved notes under Settings > Assistant > Saved notes, where Forget runs the same `delete_memory`.

## The stores in this app

The app keeps both in its drift database. This is part of the memory store, from [`lib/data/repositories/drift_memory_store.dart`](../../lib/data/repositories/drift_memory_store.dart):

```dart
/// The assistant's saved facts in the app's database.
class DriftMemoryStore implements MemoryStore {
  DriftMemoryStore(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  @override
  Future<List<Memory>> all() async {
    final rows =
        await (_db.select(_db.assistantMemories)..orderBy([
              (m) => OrderingTerm.asc(m.createdAt),
              (m) => OrderingTerm.asc(m.rowId),
            ]))
            .get();
    return [
      for (final row in rows)
        Memory(id: row.id, text: row.body, createdAt: row.createdAt),
    ];
  }
```

The core package has a shared contract test for each interface. A new store passes it before it is used. The app runs it on both drift stores:

```bash
flutter test test/data/repositories/drift_stores_test.dart
```

## Reference

[Storage and memory](../../packages/flutter_agentify_core/doc/storage-and-memory.md): the interfaces, the contract tests and how memories reach the model.
