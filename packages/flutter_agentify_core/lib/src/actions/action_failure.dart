import 'action_context.dart';

/// The one way an action reports failure: a stable [code] the model and the
/// UI can act on, a [message] for people, and optional [details].
///
/// Actions throw it; they never return error strings or maps.
class ActionFailure implements Exception {
  const ActionFailure(
    this.code,
    this.message, {
    this.details,
    this.receipts = const [],
  });

  /// A short stable name for the failure, such as `not_found`.
  final String code;

  /// What went wrong, for people.
  final String message;

  /// Extra JSON-encodable facts, such as the `path` of an invalid field.
  final Map<String, Object?>? details;

  /// What the action had already written when it failed, filled in by the
  /// registry. Show these: the data did change.
  final List<Receipt> receipts;

  @override
  String toString() => '$code: $message';
}
