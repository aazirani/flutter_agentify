import '../cancel_token.dart';

/// Who started an action call. Approval and logging depend on it.
enum Caller { ui, assistant, cli }

/// What a write really changed, shown to the person under the assistant's
/// reply whatever the model claims.
class Receipt {
  const Receipt({
    required this.resource,
    required this.ids,
    required this.summary,
    this.verified = false,
    this.key,
    this.args = const {},
  });

  factory Receipt.fromJson(Map<String, Object?> json) => Receipt(
    resource: json['resource'] as String,
    ids: [...(json['ids'] as List<Object?>).cast<String>()],
    summary: json['summary'] as String,
    verified: json['verified'] as bool? ?? false,
    key: json['key'] as String?,
    args: {...?(json['args'] as Map<String, Object?>?)?.cast<String, String>()},
  );

  /// The kind of data changed, such as `items`.
  final String resource;

  /// The ids of the records changed.
  final List<String> ids;

  /// One line for people, such as `Created "Milk"`.
  final String summary;

  /// Whether the action read the data back after writing it.
  final bool verified;

  /// Names the [summary]'s translation, such as `created_item`; the app
  /// looks up `receipt_<key>` and fills `{name}` from [args]. Null: the
  /// chat shows [summary] as it is.
  final String? key;
  final Map<String, String> args;

  Map<String, Object?> toJson() => {
    'resource': resource,
    'ids': ids,
    'summary': summary,
    'verified': verified,
    if (key != null) 'key': key,
    if (args.isNotEmpty) 'args': args,
  };
}

/// Handed to every action run.
class ActionContext {
  ActionContext({required this.caller, this.cancel});

  final Caller caller;

  /// Fires when the person stops the run or the action times out. The action
  /// keeps running after a timeout, so a long action must check
  /// `cancel.isCancelled` before each write and stop without writing.
  final CancelToken? cancel;

  final List<Receipt> _receipts = [];

  /// Receipts recorded so far in this call.
  List<Receipt> get receipts => List.unmodifiable(_receipts);

  /// Records what this call changed. [key] and [args] let the chat show
  /// [summary] in the app's language; see [Receipt.key].
  void receipt({
    required String resource,
    required List<String> ids,
    required String summary,
    bool verified = false,
    String? key,
    Map<String, String> args = const {},
  }) => _receipts.add(
    Receipt(
      resource: resource,
      ids: ids,
      summary: summary,
      verified: verified,
      key: key,
      args: args,
    ),
  );
}
