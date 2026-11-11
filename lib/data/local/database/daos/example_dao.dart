import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/example_table.dart';

part 'example_dao.drift.dart';

@DriftAccessor(tables: [ExampleItems])
class ExampleDao extends DatabaseAccessor<AppDatabase> with _$ExampleDaoMixin {
  ExampleDao(super.db);

  Future<void> insertItem(ExampleItemsCompanion item) =>
      into(exampleItems).insert(item);
}
