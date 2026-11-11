import 'package:drift/native.dart';
import 'package:flutter_agentify/data/local/database/app_database.dart';
import 'package:flutter_agentify/data/repositories/drift_memory_store.dart';
import 'package:flutter_agentify/data/repositories/drift_thread_store.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase _db() {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

void main() {
  test(
    'DriftThreadStore meets the thread store contract',
    () => verifyThreadStore(() => DriftThreadStore(_db())),
  );

  test(
    'DriftMemoryStore meets the memory store contract',
    () => verifyMemoryStore(() => DriftMemoryStore(_db())),
  );
}
