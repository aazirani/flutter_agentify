import 'dart:async';

import 'package:flutter_agentify/domain/entities/item.dart';
import 'package:flutter_agentify/domain/repositories/items_repository.dart';

/// Items in memory, with a live stream, for widget tests.
class FakeItemsRepository implements ItemsRepository {
  FakeItemsRepository([Iterable<Item> items = const []]) : _items = [...items];

  final List<Item> _items;
  final _changes = StreamController<void>.broadcast();
  var _next = 0;

  List<Item> get _newestFirst =>
      [..._items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Stream<List<Item>> watchItems() async* {
    yield _newestFirst;
    await for (final _ in _changes.stream) {
      yield _newestFirst;
    }
  }

  @override
  Future<List<Item>> getItems({int limit = 50}) async =>
      _newestFirst.take(limit).toList();

  @override
  Future<int> getItemCount() async => _items.length;

  @override
  Future<Item?> getItem(String id) async {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Future<Item> createItem({required String title, String? description}) async {
    final item = Item(
      id: 'item_${++_next}',
      title: title,
      description: description,
      createdAt: DateTime.now().add(Duration(microseconds: _next)),
    );
    _items.add(item);
    _changes.add(null);
    return item;
  }

  @override
  Future<Item?> updateItem(
    String id, {
    String? title,
    String? description,
    bool clearDescription = false,
  }) async {
    final index = _items.indexWhere((i) => i.id == id);
    if (index < 0) return null;
    final old = _items[index];
    final updated = Item(
      id: id,
      title: title ?? old.title,
      description: clearDescription ? null : description ?? old.description,
      createdAt: old.createdAt,
    );
    _items[index] = updated;
    _changes.add(null);
    return updated;
  }

  @override
  Future<bool> deleteItem(String id) async {
    final before = _items.length;
    _items.removeWhere((i) => i.id == id);
    _changes.add(null);
    return _items.length < before;
  }

  @override
  Future<int> deleteItems(List<String> ids) async {
    final before = _items.length;
    _items.removeWhere((i) => ids.contains(i.id));
    _changes.add(null);
    return before - _items.length;
  }
}
