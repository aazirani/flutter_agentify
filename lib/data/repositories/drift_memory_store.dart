import 'package:drift/drift.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:uuid/uuid.dart';

import '../local/database/app_database.dart';

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

  @override
  Future<Memory> save(String text) async {
    final memory = Memory(
      id: _uuid.v4(),
      text: text,
      createdAt: DateTime.now(),
    );
    await _db
        .into(_db.assistantMemories)
        .insert(
          AssistantMemoriesCompanion.insert(
            id: memory.id,
            body: text,
            createdAt: memory.createdAt,
          ),
        );
    return memory;
  }

  @override
  Future<bool> delete(String id) async =>
      await (_db.delete(
        _db.assistantMemories,
      )..where((m) => m.id.equals(id))).go() >
      0;
}
