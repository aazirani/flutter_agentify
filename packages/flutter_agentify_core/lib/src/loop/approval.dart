/// The person's answer to an approval request.
sealed class ApprovalDecision {
  const ApprovalDecision();
}

/// Run the call. With [always], stop asking for this action.
final class Approve extends ApprovalDecision {
  const Approve({this.always = false});

  final bool always;
}

/// Do not run the call; the model hears that the person declined.
final class Reject extends ApprovalDecision {
  const Reject();
}

/// Run the call with these arguments instead.
final class Edit extends ApprovalDecision {
  const Edit(this.args);

  final Map<String, Object?> args;
}

/// Which actions the person allowed for good. Apps persist it.
abstract class ApprovalPrefs {
  bool isAlwaysAllowed(String action);

  Future<void> setAlwaysAllowed(String action, bool value);

  /// Forgets every "always allow", so each action asks again.
  Future<void> clear();
}

/// Remembers "always allow" until the app closes.
class InMemoryApprovalPrefs implements ApprovalPrefs {
  final _allowed = <String>{};

  @override
  bool isAlwaysAllowed(String action) => _allowed.contains(action);

  @override
  Future<void> setAlwaysAllowed(String action, bool value) async {
    if (value) {
      _allowed.add(action);
    } else {
      _allowed.remove(action);
    }
  }

  @override
  Future<void> clear() async => _allowed.clear();
}
