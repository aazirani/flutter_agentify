import 'package:drift/drift.dart';

/// Conversations with the assistant.
@DataClassName('AssistantThreadRow')
class AssistantThreads extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().nullable()();
  TextColumn get summary => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// Has turns answered on this device that no server has seen yet.
  BoolColumn get unshared => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One stored message per row; `payload` holds `StoredMessage.toJson()`.
@DataClassName('AssistantMessageRow')
class AssistantMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get threadId => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Facts the assistant saved for later conversations.
@DataClassName('AssistantMemoryRow')
class AssistantMemories extends Table {
  TextColumn get id => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
