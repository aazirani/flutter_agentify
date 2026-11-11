import '../actions/action_context.dart';
import '../llm/llm_types.dart';

/// What happens during one run of the assistant. A run's stream ends with
/// exactly one of [Done], [Cancelled], [LoopLimit] or [AgentError].
sealed class AgentEvent {}

/// A piece of the assistant's reply.
final class TextDelta extends AgentEvent {
  TextDelta(this.text);

  final String text;
}

final class ToolStarted extends AgentEvent {
  ToolStarted({required this.callId, required this.name, this.args});

  final String callId;
  final String name;

  /// Null when the model sent arguments that are not a JSON object.
  final Map<String, Object?>? args;
}

final class ToolFinished extends AgentEvent {
  ToolFinished({
    required this.callId,
    required this.name,
    required this.content,
    this.isError = false,
    this.errorCode,
  });

  final String callId;
  final String name;

  /// What the model gets back.
  final String content;
  final bool isError;
  final String? errorCode;
}

/// The run waits until the person approves, edits or rejects this call.
final class ApprovalRequired extends AgentEvent {
  ApprovalRequired({
    required this.callId,
    required this.action,
    required this.args,
    this.summary,
    this.allowAlways = true,
  });

  final String callId;
  final String action;
  final Map<String, Object?> args;

  /// One line saying what the call is for, such as the item it deletes.
  final String? summary;

  /// Whether the card may offer "Always allow".
  final bool allowAlways;
}

/// Something really changed.
final class ChangeReceipt extends AgentEvent {
  ChangeReceipt(this.receipt);

  final Receipt receipt;
}

/// The model cannot call tools; the assistant answers from the screen only.
final class AnswerOnly extends AgentEvent {}

final class AgentError extends AgentEvent {
  AgentError(
    this.message, {
    this.retryable = false,
    this.kind = LlmErrorKind.other,
  });

  /// What went wrong, for logs and the debug inspector. A chat shows a
  /// message for [kind] instead.
  final String message;

  /// Why it failed; [LlmErrorKind.other] for errors outside the model
  /// request, such as storage.
  final LlmErrorKind kind;

  /// Whether sending again may work.
  final bool retryable;
}

enum LoopLimitReason { maxSteps, tokenBudget, repeatedCall, outputLimit }

/// The run stopped at a safety limit.
final class LoopLimit extends AgentEvent {
  LoopLimit(this.reason);

  final LoopLimitReason reason;
}

/// The person stopped the run.
final class Cancelled extends AgentEvent {}

/// The assistant finished its reply.
final class Done extends AgentEvent {}
