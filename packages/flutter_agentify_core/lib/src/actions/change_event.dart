import 'action_context.dart';

/// Emitted after every call to a writing action, success or failure (a failed
/// call may have written part of its work), once per declared resource.
class ChangeEvent {
  const ChangeEvent({
    required this.resource,
    required this.action,
    required this.caller,
    required this.succeeded,
  });

  /// The resource written.
  final String resource;

  /// The action's name.
  final String action;

  /// Who called it.
  final Caller caller;

  /// False when the call failed, though it may have written part of its work.
  final bool succeeded;
}
