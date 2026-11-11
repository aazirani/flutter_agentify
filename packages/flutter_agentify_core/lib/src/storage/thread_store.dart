import '../actions/action_context.dart';
import '../llm/llm_types.dart';

/// One conversation with the assistant.
class AssistantThread {
  const AssistantThread({
    required this.id,
    required this.createdAt,
    this.title,
    this.summary,
    this.unshared = false,
  });

  final String id;
  final String? title;

  /// What older, dropped messages said; part of the system text.
  final String? summary;
  final DateTime createdAt;

  /// Has turns answered on this device that no server has seen yet.
  final bool unshared;
}

/// A message as stored, with the receipts of what its run changed.
class StoredMessage {
  const StoredMessage(this.message, {this.receipts = const []});

  factory StoredMessage.fromJson(Map<String, Object?> json) => StoredMessage(
    ChatMessage.fromJson(json['message'] as Map<String, Object?>),
    receipts: [
      for (final r in json['receipts'] as List<Object?>? ?? const [])
        Receipt.fromJson(r as Map<String, Object?>),
    ],
  );

  final ChatMessage message;
  final List<Receipt> receipts;

  Map<String, Object?> toJson() => {
    'message': message.toJson(),
    if (receipts.isNotEmpty) 'receipts': [for (final r in receipts) r.toJson()],
  };
}

/// Where conversations live. Implementations must pass `verifyThreadStore`
/// from `package:flutter_agentify_core/testing.dart`.
abstract class ThreadStore {
  Future<AssistantThread> createThread({String? title});

  /// Newest first.
  Future<List<AssistantThread>> threads();

  Future<AssistantThread?> thread(String id);

  /// Oldest first.
  Future<List<StoredMessage>> messages(String threadId);

  Future<void> append(String threadId, StoredMessage message);

  /// Drops the oldest [dropCount] messages and stores [summary] in their
  /// place.
  Future<void> summarize(
    String threadId, {
    required String summary,
    required int dropCount,
  });

  Future<void> deleteThread(String id);

  /// Marks whether [threadId] has turns not yet shared with a server.
  Future<void> setUnshared(String threadId, bool value);
}
