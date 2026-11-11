/// A fact the assistant keeps across conversations.
class Memory {
  const Memory({required this.id, required this.text, required this.createdAt});

  /// The id `delete_memory` takes.
  final String id;

  /// The fact, in one short line.
  final String text;

  /// When it was saved.
  final DateTime createdAt;
}

/// Where memories live. Implementations must pass `verifyMemoryStore` from
/// `package:flutter_agentify_core/testing.dart`.
abstract class MemoryStore {
  /// Oldest first.
  Future<List<Memory>> all();

  /// Stores [text] and returns the new memory.
  Future<Memory> save(String text);

  /// True when a memory was deleted.
  Future<bool> delete(String id);
}
