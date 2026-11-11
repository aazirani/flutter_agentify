import '../entities/item.dart';

/// The app's items. Screens read through `watch…` and `get…`; every change
/// goes through an action.
abstract class ItemsRepository {
  /// Newest first.
  Stream<List<Item>> watchItems();

  /// Newest first, at most [limit].
  Future<List<Item>> getItems({int limit = 50});

  Future<int> getItemCount();

  Future<Item?> getItem(String id);

  Future<Item> createItem({required String title, String? description});

  /// Null when [id] does not exist.
  Future<Item?> updateItem(
    String id, {
    String? title,
    String? description,
    bool clearDescription = false,
  });

  /// False when [id] does not exist.
  Future<bool> deleteItem(String id);

  /// Deletes all of [ids] in one write; the number deleted.
  Future<int> deleteItems(List<String> ids);
}
