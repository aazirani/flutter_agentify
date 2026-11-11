import 'package:drift/drift.dart';

import 'tables/assistant_tables.dart';
// @example:begin
import 'tables/example_table.dart';
// @example:end

part 'app_database.drift.dart';

/// The app's database. The connection is passed in, so the same code runs
/// under Flutter (`openAppConnection`) and in plain Dart (the action CLI and
/// tests).
@DriftDatabase(
  tables: [
    // @example:begin
    ExampleItems,
    // @example:end
    AssistantThreads,
    AssistantMessages,
    AssistantMemories,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) => m.createAll(),
      // A new schema version adds an `if (from < N)` step here.
      onUpgrade: (Migrator m, int from, int to) async {},
    );
  }
}
