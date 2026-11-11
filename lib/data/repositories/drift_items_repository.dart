import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/item.dart';
import '../../domain/repositories/items_repository.dart';
import '../local/database/app_database.dart';
import '../local/database/daos/example_dao.dart';

class DriftItemsRepository implements ItemsRepository {
  DriftItemsRepository(this._dao);

  final ExampleDao _dao;
  static const _uuid = Uuid();

  $ExampleItemsTable get _table => _dao.exampleItems;

  SimpleSelectStatement<$ExampleItemsTable, ExampleItem> _newestFirst() =>
      _dao.select(_table)..orderBy([
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.desc(t.rowId),
      ]);

  static Item _toItem(ExampleItem row) => Item(
    id: row.id,
    title: row.title,
    description: row.description,
    createdAt: row.createdAt,
  );

  @override
  Stream<List<Item>> watchItems() =>
      _newestFirst().watch().map((rows) => rows.map(_toItem).toList());

  @override
  Future<List<Item>> getItems({int limit = 50}) async =>
      (await (_newestFirst()..limit(limit)).get()).map(_toItem).toList();

  @override
  Future<int> getItemCount() async {
    final count = _table.id.count();
    final row = await (_dao.selectOnly(
      _table,
    )..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<Item?> getItem(String id) async {
    final row = await (_dao.select(
      _table,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toItem(row);
  }

  @override
  Future<Item> createItem({required String title, String? description}) async {
    final id = _uuid.v4();
    await _dao.insertItem(
      ExampleItemsCompanion.insert(
        id: id,
        title: title,
        description: Value(description),
        createdAt: DateTime.now(),
      ),
    );
    final created = await getItem(id);
    if (created == null) throw StateError('Item $id was not stored.');
    return created;
  }

  @override
  Future<Item?> updateItem(
    String id, {
    String? title,
    String? description,
    bool clearDescription = false,
  }) async {
    final changed = await (_dao.update(_table)..where((t) => t.id.equals(id)))
        .write(
          ExampleItemsCompanion(
            title: title == null ? const Value.absent() : Value(title),
            description: clearDescription
                ? const Value(null)
                : description == null
                ? const Value.absent()
                : Value(description),
          ),
        );
    return changed == 0 ? null : getItem(id);
  }

  @override
  Future<bool> deleteItem(String id) async =>
      await (_dao.delete(_table)..where((t) => t.id.equals(id))).go() > 0;

  @override
  Future<int> deleteItems(List<String> ids) =>
      (_dao.delete(_table)..where((t) => t.id.isIn(ids))).go();
}
