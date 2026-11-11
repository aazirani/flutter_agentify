import 'dart:convert';

import '../llm/llm_types.dart';
import '../storage/thread_store.dart';

/// A rough token count: ASCII characters / 4, other characters (Persian,
/// Arabic, CJK...) / 1.5, rounded up. Those scripts cost far more tokens per
/// character.
int estimateTokens(String text) {
  var other = 0;
  for (final unit in text.runes) {
    if (unit > 127) other++;
  }
  return ((text.runes.length - other) / 4 + other / 1.5).ceil();
}

/// Estimated tokens of one stored message.
int messageTokens(StoredMessage message) =>
    estimateTokens(jsonEncode(message.message.toJson()));

/// Index of the first message to keep so the kept tail fits [budgetTokens];
/// never splits a tool call from its results and keeps at least [keepRecent]
/// messages, and always at least one.
int historyCutIndex(
  List<StoredMessage> messages, {
  required int budgetTokens,
  required int keepRecent,
}) {
  var cut = messages.length;
  var used = 0;
  while (cut > 0) {
    final next = used + messageTokens(messages[cut - 1]);
    if (next > budgetTokens) break;
    used = next;
    cut--;
  }
  final mostKept = messages.length - (keepRecent < 1 ? 1 : keepRecent);
  if (cut > mostKept) cut = mostKept < 0 ? 0 : mostKept;
  // The kept history must start with a person message: a model API rejects a
  // conversation that starts with the assistant, and a cut there could also
  // orphan tool results from their call. Prefer dropping more; else keep
  // more.
  bool startsTurn(int i) => messages[i].message is UserMessage;
  var next = cut;
  while (next < messages.length && !startsTurn(next)) {
    next++;
  }
  if (next < messages.length) return next;
  while (cut > 0 && !startsTurn(cut)) {
    cut--;
  }
  return cut;
}

/// [messages] with a cancelled error result added after every tool call that
/// has none before the next turn, as left by a crash mid-run: a model API
/// rejects a call without its result.
List<ChatMessage> withToolResults(List<ChatMessage> messages) {
  final fixed = <ChatMessage>[];
  var open = <ToolCall>[];
  void answerOpen() {
    for (final call in open) {
      fixed.add(
        ToolResultMessage(
          callId: call.id,
          name: call.name,
          content: '{"error":"cancelled"}',
          isError: true,
        ),
      );
    }
    open = [];
  }

  for (final message in messages) {
    switch (message) {
      case ToolResultMessage(:final callId):
        open.removeWhere((call) => call.id == callId);
      case AssistantMessage(:final toolCalls):
        answerOpen();
        open = List.of(toolCalls);
      case UserMessage():
        answerOpen();
    }
    fixed.add(message);
  }
  answerOpen();
  return fixed;
}
