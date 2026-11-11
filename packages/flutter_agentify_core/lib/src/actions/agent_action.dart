import '../schema/schema.dart';
import 'action_context.dart';
import 'action_failure.dart';

/// One capability of the app, called the same way by its UI, the assistant
/// and the action CLI.
///
/// `I` is the parsed input, `O` the output. Actions are deterministic: they
/// never call a model.
abstract class AgentAction<I, O> {
  const AgentAction();

  /// Unique `snake_case` name, also the tool name the model sees.
  String get name;

  /// One complete line saying what the action does.
  String get description;

  /// The input's JSON schema; it also parses the model's arguments.
  ObjectSchema<I> get input;

  /// Does the work; throws [ActionFailure] to fail. After [timeout] the
  /// caller gets a `timeout` failure but this keeps running, so long actions
  /// must check `context.cancel` before each write.
  Future<O> run(I input, ActionContext context);

  /// Turns [output] into a JSON-encodable value for the model.
  Object? encode(O output);

  /// False keeps the action out of the assistant's tools (UI only).
  bool get agentTool => true;

  /// True when the action changes nothing.
  bool get readOnly => false;

  /// Whether a call from the assistant or the CLI must be approved first.
  bool needsApproval(I input) => false;

  /// Whether the person may answer "Always allow". False for anything
  /// destructive, so every call asks again.
  bool get allowAlways => true;

  /// One line the person reads on the approval card, such as the title of
  /// the item a delete removes. Null shows only the arguments.
  Future<String?> approvalSummary(I input) async => null;

  /// The data this action writes, such as `['items']`.
  List<String> get resources => const [];

  /// How long a call may take before it fails with `timeout`.
  Duration get timeout => const Duration(seconds: 30);

  /// Longest result the model gets; longer results are cut.
  int get maxResultChars => 4000;

  /// Extra words that help tool search find this action.
  List<String> get searchHints => const [];

  /// Codes this action may fail with, besides the built-in ones.
  List<String> get failureCodes => const [];
}
