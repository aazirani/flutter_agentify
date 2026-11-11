import 'memory_store.dart';
import 'thread_store.dart';

/// Keeps threads in memory: lost when the app closes. Apps that want history
/// to survive provide their own [ThreadStore].
class InMemoryThreadStore implements ThreadStore {
  final _threads = <AssistantThread>[];
  final _messages = <String, List<StoredMessage>>{};
  var _next = 0;

  @override
  Future<AssistantThread> createThread({String? title}) async {
    final thread = AssistantThread(
      id: 'thread_${++_next}',
      title: title,
      createdAt: DateTime.now(),
    );
    _threads.add(thread);
    _messages[thread.id] = [];
    return thread;
  }

  @override
  Future<List<AssistantThread>> threads() async => _threads.reversed.toList();

  @override
  Future<AssistantThread?> thread(String id) async {
    for (final thread in _threads) {
      if (thread.id == id) return thread;
    }
    return null;
  }

  @override
  Future<List<StoredMessage>> messages(String threadId) async =>
      List.of(_messages[threadId] ?? const []);

  @override
  Future<void> append(String threadId, StoredMessage message) async {
    final list = _messages[threadId];
    if (list == null) throw StateError('No thread "$threadId".');
    list.add(message);
  }

  @override
  Future<void> summarize(
    String threadId, {
    required String summary,
    required int dropCount,
  }) async {
    final list = _messages[threadId];
    final index = _threads.indexWhere((t) => t.id == threadId);
    if (list == null || index < 0) throw StateError('No thread "$threadId".');
    list.removeRange(0, dropCount.clamp(0, list.length));
    final old = _threads[index];
    _threads[index] = AssistantThread(
      id: old.id,
      title: old.title,
      summary: summary,
      createdAt: old.createdAt,
      unshared: old.unshared,
    );
  }

  @override
  Future<void> setUnshared(String threadId, bool value) async {
    final index = _threads.indexWhere((t) => t.id == threadId);
    if (index < 0) throw StateError('No thread "$threadId".');
    final old = _threads[index];
    _threads[index] = AssistantThread(
      id: old.id,
      title: old.title,
      summary: old.summary,
      createdAt: old.createdAt,
      unshared: value,
    );
  }

  @override
  Future<void> deleteThread(String id) async {
    _threads.removeWhere((t) => t.id == id);
    _messages.remove(id);
  }
}

/// Keeps memories in memory: lost when the app closes.
class InMemoryMemoryStore implements MemoryStore {
  final _memories = <Memory>[];
  var _next = 0;

  @override
  Future<List<Memory>> all() async => List.of(_memories);

  @override
  Future<Memory> save(String text) async {
    final memory = Memory(
      id: 'memory_${++_next}',
      text: text,
      createdAt: DateTime.now(),
    );
    _memories.add(memory);
    return memory;
  }

  @override
  Future<bool> delete(String id) async {
    final before = _memories.length;
    _memories.removeWhere((m) => m.id == id);
    return _memories.length < before;
  }
}
