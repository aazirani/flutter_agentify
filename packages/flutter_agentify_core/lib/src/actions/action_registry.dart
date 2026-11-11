import 'dart:async';
import 'dart:convert';

import '../cancel_token.dart';
import '../schema/schema.dart';
import '../secrets/redactor.dart';
import '../text.dart';
import 'action_context.dart';
import 'action_failure.dart';
import '../loop/tool_search.dart';
import 'agent_action.dart';
import 'change_event.dart';

final _namePattern = RegExp(r'^[a-z][a-z0-9_]{0,63}$');

/// An action definition the registry refuses, found at startup.
class ActionDefinitionError extends Error {
  ActionDefinitionError(this.action, this.message);

  /// The action that was refused.
  final String action;

  /// Why.
  final String message;

  @override
  String toString() => 'Action "$action": $message';
}

/// The outcome of [ActionRegistry.call].
class ActionCallResult {
  const ActionCallResult({
    required this.name,
    required this.output,
    required this.content,
    required this.receipts,
  });

  /// The action's name.
  final String name;

  /// What the action returned.
  final Object? output;

  /// The output as JSON for the model: redacted and cut to the action's
  /// `maxResultChars`.
  final String content;

  /// What the call changed.
  final List<Receipt> receipts;
}

/// Every action of the app, checked once at startup, and the one place they
/// are called from.
class ActionRegistry {
  ActionRegistry(Iterable<AgentAction<Object?, Object?>> actions) {
    for (final action in actions) {
      _check(action);
      if (_byName.containsKey(action.name)) {
        throw ActionDefinitionError(action.name, 'the name is used twice');
      }
      _byName[action.name] = action;
    }
  }

  final _byName = <String, AgentAction<Object?, Object?>>{};
  final _changes = StreamController<ChangeEvent>.broadcast(sync: true);
  static const _redactor = Redactor();

  /// Every action, sorted by name.
  List<AgentAction<Object?, Object?>> get all =>
      _byName.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  /// The actions the assistant may call.
  List<AgentAction<Object?, Object?>> get tools => [
    for (final action in all)
      if (action.agentTool) action,
  ];

  /// The action called [name], or null.
  AgentAction<Object?, Object?>? find(String name) => _byName[name];

  /// Closes [changes]. Call it when the registry is no longer used.
  Future<void> dispose() => _changes.close();

  /// One event per resource after each call to a writing action.
  Stream<ChangeEvent> get changes => _changes.stream;

  /// Whether a call with [jsonInput] needs approval. False when the action is
  /// unknown or the input is invalid (the call itself reports those). True
  /// when deciding throws.
  bool requiresApproval(String name, Object? jsonInput) {
    final action = find(name);
    if (action == null) return false;
    final Object? input;
    try {
      input = action.input.parse(jsonInput);
    } on Object {
      return false;
    }
    return _needsApproval(action, input);
  }

  /// Fails closed: a throwing `needsApproval` means approval is required.
  static bool _needsApproval<I, O>(AgentAction<I, O> action, I input) {
    try {
      return action.needsApproval(input);
    } on Object {
      return true;
    }
  }

  /// What the approval card shows for a call with [jsonInput]. Never throws:
  /// an unknown action, invalid input or a failing summary gives
  /// `(allowAlways: false, summary: null)`.
  Future<({bool allowAlways, String? summary})> approvalInfo(
    String name,
    Object? jsonInput,
  ) async {
    final action = find(name);
    if (action == null) return (allowAlways: false, summary: null);
    try {
      final summary = await action.approvalSummary(
        action.input.parse(jsonInput),
      );
      return (allowAlways: action.allowAlways, summary: summary);
    } on Object {
      return (allowAlways: false, summary: null);
    }
  }

  /// Calls [name] with JSON input, as the assistant and the CLI do.
  /// Throws [ActionFailure], or [ArgumentError] for [Caller.ui]: the UI
  /// calls [run], so JSON input never skips approval.
  Future<ActionCallResult> call(
    String name,
    Object? jsonInput, {
    required Caller caller,
    bool approved = false,
    CancelToken? cancel,
  }) async {
    if (caller == Caller.ui) {
      throw ArgumentError.value(caller, 'caller', 'The UI calls run()');
    }
    final action = find(name);
    if (action == null || (caller == Caller.assistant && !action.agentTool)) {
      throw ActionFailure(
        'unknown_action',
        'There is no action named "$name".',
      );
    }
    final Object? input;
    try {
      input = action.input.parse(jsonInput);
    } on SchemaError catch (e) {
      throw ActionFailure(
        'invalid_input',
        e.message,
        details: {'path': e.path},
      );
    } catch (e) {
      throw ActionFailure('invalid_input', _clean(e));
    }
    _checkApproval(action, input, caller, approved);

    final (output, receipts) = await _execute(action, input, caller, cancel);
    final String json;
    try {
      json = jsonEncode(action.encode(output));
    } catch (e) {
      throw ActionFailure('internal_error', _clean(e));
    }
    return ActionCallResult(
      name: name,
      output: output,
      content: _cut(_redactor.redact(json), action.maxResultChars),
      receipts: receipts,
    );
  }

  /// Calls a registered [action] with typed input, as the app's UI does.
  /// Throws [ActionFailure], or [StateError] when [action] is not the
  /// registered instance.
  Future<O> run<I, O>(
    AgentAction<I, O> action,
    I input, {
    Caller caller = Caller.ui,
  }) async {
    if (!identical(find(action.name), action)) {
      throw StateError('Action "${action.name}" is not in this registry.');
    }
    if (caller == Caller.assistant && !action.agentTool) {
      throw ActionFailure(
        'unknown_action',
        'There is no action named "${action.name}".',
      );
    }
    _checkApproval(action, input, caller, false);
    final (output, _) = await _execute(action, input, caller, null);
    return output;
  }

  void _checkApproval<I, O>(
    AgentAction<I, O> action,
    I input,
    Caller caller,
    bool approved,
  ) {
    if (caller != Caller.ui && !approved && _needsApproval(action, input)) {
      throw ActionFailure(
        'approval_required',
        '"${action.name}" needs the person\'s approval first.',
      );
    }
  }

  Future<(O, List<Receipt>)> _execute<I, O>(
    AgentAction<I, O> action,
    I input,
    Caller caller,
    CancelToken? cancel,
  ) async {
    // Its own token: the caller's stops it too, and so does a timeout.
    final token = CancelToken();
    cancel?.whenCancelled.then((_) => token.cancel());
    final context = ActionContext(caller: caller, cancel: token);
    var succeeded = false;
    try {
      final output = await action
          .run(input, context)
          .timeout(
            action.timeout,
            onTimeout: () {
              token.cancel();
              throw ActionFailure(
                'timeout',
                '"${action.name}" took longer than '
                    '${action.timeout.inMilliseconds} ms.',
              );
            },
          );
      succeeded = true;
      return (output, context.receipts);
    } on ActionFailure catch (f) {
      throw ActionFailure(
        f.code,
        _clean(f.message, 1000),
        details: _cleanDetails(f.details),
        receipts: context.receipts,
      );
    } catch (e) {
      throw ActionFailure(
        'internal_error',
        _clean(e),
        receipts: context.receipts,
      );
    } finally {
      if (!action.readOnly) {
        for (final resource in action.resources) {
          _changes.add(
            ChangeEvent(
              resource: resource,
              action: action.name,
              caller: caller,
              succeeded: succeeded,
            ),
          );
        }
      }
    }
  }

  /// An exception's text without secrets, short enough for the model.
  static String _clean(Object error, [int max = 300]) {
    final text = _redactor.redact(error.toString());
    return cutText(text, max);
  }

  static Map<String, Object?>? _cleanDetails(Map<String, Object?>? details) =>
      details == null
      ? null
      : {
          for (final MapEntry(:key, :value) in details.entries)
            key: value is String ? _clean(value) : value,
        };

  static String _cut(String text, int max) {
    final cut = cutText(text, max);
    return cut.length == text.length
        ? text
        : '$cut…[truncated ${text.length - cut.length} characters]';
  }

  static void _check(AgentAction<Object?, Object?> action) {
    final name = action.name;
    void fail(String message) => throw ActionDefinitionError(name, message);

    if (!_namePattern.hasMatch(name)) {
      fail(
        'the name must be snake_case, start with a letter, at most 64 '
        'characters',
      );
    }
    if (name == toolSearchName) fail('the name $toolSearchName is reserved');
    final description = action.description.trim();
    if (description.isEmpty || description.contains('\n')) {
      fail('the description must be one non-empty line');
    }
    if (!action.readOnly && action.resources.isEmpty) {
      fail('a writing action must list the resources it writes');
    }
    try {
      action.input;
    } on ArgumentError catch (e) {
      fail('an input field is invalid: ${e.message}');
    }
  }
}
