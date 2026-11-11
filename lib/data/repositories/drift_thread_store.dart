import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:uuid/uuid.dart';

import '../local/database/app_database.dart';

/// Assistant conversations in the app's database.
class DriftThreadStore implements ThreadStore {
  DriftThreadStore(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  static AssistantThread _toThread(AssistantThreadRow row) => AssistantThread(
    id: row.id,
    title: row.title,
    summary: row.summary,
    createdAt: row.createdAt,
    unshared: row.unshared,
  );

  @override
  Future<AssistantThread> createThread({String? title}) async {
    final id = _uuid.v4();
    await _db
        .into(_db.assistantThreads)
        .insert(
          AssistantThreadsCompanion.insert(
            id: id,
            title: Value(title),
            createdAt: DateTime.now(),
          ),
        );
    final created = await thread(id);
    if (created == null) throw StateError('Thread $id was not stored.');
    return created;
  }

  @override
  Future<List<AssistantThread>> threads() async {
    final rows =
        await (_db.select(_db.assistantThreads)..orderBy([
              (t) => OrderingTerm.desc(t.createdAt),
              (t) => OrderingTerm.desc(t.rowId),
            ]))
            .get();
    return rows.map(_toThread).toList();
  }

  @override
  Future<AssistantThread?> thread(String id) async {
    final row = await (_db.select(
      _db.assistantThreads,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toThread(row);
  }

  @override
  Future<List<StoredMessage>> messages(String threadId) async {
    final rows =
        await (_db.select(_db.assistantMessages)
              ..where((m) => m.threadId.equals(threadId))
              ..orderBy([(m) => OrderingTerm.asc(m.id)]))
            .get();
    return [
      for (final row in rows)
        StoredMessage.fromJson(jsonDecode(row.payload) as Map<String, Object?>),
    ];
  }

  @override
  Future<void> append(String threadId, StoredMessage message) => _db
      .into(_db.assistantMessages)
      .insert(
        AssistantMessagesCompanion.insert(
          threadId: threadId,
          payload: jsonEncode(message.toJson()),
          createdAt: DateTime.now(),
        ),
      );

  @override
  Future<void> summarize(
    String threadId, {
    required String summary,
    required int dropCount,
  }) => _db.transaction(() async {
    final oldest =
        await (_db.selectOnly(_db.assistantMessages)
              ..addColumns([_db.assistantMessages.id])
              ..where(_db.assistantMessages.threadId.equals(threadId))
              ..orderBy([OrderingTerm.asc(_db.assistantMessages.id)])
              ..limit(dropCount))
            .map((row) => row.read(_db.assistantMessages.id))
            .get();
    final ids = oldest.whereType<int>().toList();
    if (ids.isNotEmpty) {
      await (_db.delete(
        _db.assistantMessages,
      )..where((m) => m.id.isIn(ids))).go();
    }
    await (_db.update(_db.assistantThreads)
          ..where((t) => t.id.equals(threadId)))
        .write(AssistantThreadsCompanion(summary: Value(summary)));
  });

  @override
  Future<void> deleteThread(String id) => _db.transaction(() async {
    await (_db.delete(
      _db.assistantMessages,
    )..where((m) => m.threadId.equals(id))).go();
    await (_db.delete(
      _db.assistantThreads,
    )..where((t) => t.id.equals(id))).go();
  });

  @override
  Future<void> setUnshared(String threadId, bool value) =>
      (_db.update(_db.assistantThreads)..where((t) => t.id.equals(threadId)))
          .write(AssistantThreadsCompanion(unshared: Value(value)));
}
