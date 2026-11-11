import 'package:drift/native.dart';
import 'package:flutter_agentify/data/local/database/app_database.dart';
import 'package:flutter_agentify/data/local/database/daos/example_dao.dart';
import 'package:flutter_agentify/data/repositories/drift_items_repository.dart';
import 'package:flutter_agentify/domain/entities/item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftItemsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftItemsRepository(ExampleDao(db));
  });
  tearDown(() => db.close());

  test('createItem returns the stored item with an id and createdAt', () async {
    final item = await repo.createItem(title: 'Milk', description: 'Oat');
    expect(item.id, isNotEmpty);
    expect(item.title, 'Milk');
    expect(item.description, 'Oat');
    final stored = await repo.getItem(item.id);
    expect(stored?.title, 'Milk');
    expect(
      stored?.createdAt.difference(item.createdAt).inSeconds.abs(),
      lessThanOrEqualTo(1),
    );
  });

  test('getItems returns newest first and respects limit', () async {
    for (final title in ['a', 'b', 'c']) {
      await repo.createItem(title: title);
    }
    expect((await repo.getItems()).map((i) => i.title), ['c', 'b', 'a']);
    expect((await repo.getItems(limit: 2)).map((i) => i.title), ['c', 'b']);
  });

  test('getItemCount counts every row', () async {
    for (var i = 0; i < 4; i++) {
      await repo.createItem(title: 'x$i');
    }
    expect(await repo.getItemCount(), 4);
  });

  test('getItem returns null for an unknown id', () async {
    expect(await repo.getItem('nope'), isNull);
  });

  test('updateItem changes only the given fields', () async {
    final item = await repo.createItem(title: 'Milk', description: 'Oat');
    final updated = await repo.updateItem(item.id, title: 'Bread');
    expect(updated?.title, 'Bread');
    expect(updated?.description, 'Oat');
    expect((await repo.getItem(item.id))?.title, 'Bread');
  });

  test('updateItem with clearDescription removes the description', () async {
    final item = await repo.createItem(title: 'Milk', description: 'Oat');
    final updated = await repo.updateItem(item.id, clearDescription: true);
    expect(updated?.description, isNull);
    expect(updated?.title, 'Milk');
  });

  test('updateItem returns null for an unknown id', () async {
    expect(await repo.updateItem('nope', title: 'x'), isNull);
  });

  test('deleteItem returns true once, then false', () async {
    final item = await repo.createItem(title: 'Milk');
    expect(await repo.deleteItem(item.id), isTrue);
    expect(await repo.deleteItem(item.id), isFalse);
    expect(await repo.getItem(item.id), isNull);
  });

  test('watchItems emits after a create', () async {
    final emitted = <List<Item>>[];
    final sub = repo.watchItems().listen(emitted.add);
    await pumpEventQueue();
    await repo.createItem(title: 'Milk');
    await pumpEventQueue();
    await sub.cancel();
    expect(emitted.first, isEmpty);
    expect(emitted.last.single.title, 'Milk');
  });

  test('toJson holds id, title, description and createdAt', () async {
    final item = await repo.createItem(title: 'Milk');
    expect(item.toJson().keys, containsAll(['id', 'title', 'createdAt']));
    expect(item.toJson().containsKey('description'), isFalse);
  });
}
