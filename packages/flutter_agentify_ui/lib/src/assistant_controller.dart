import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';

/// One entry of the chat.
sealed class ChatItem {
  const ChatItem();
}

/// What the person typed (never the screen context sent with it).
final class UserItem extends ChatItem {
  const UserItem(this.text);

  final String text;
}

/// The assistant's reply to one message: its text, the tools it ran, what
/// really changed, and an approval it waits for.
final class AssistantItem extends ChatItem {
  const AssistantItem({
    this.text = '',
    this.tools = const [],
    this.receipts = const [],
    this.approval,
    this.cancelled = false,
  });

  final String text;
  final List<ToolRowData> tools;
  final List<Receipt> receipts;
  final PendingApproval? approval;

  /// The person stopped this reply.
  final bool cancelled;

  AssistantItem copyWith({
    String? text,
    List<ToolRowData>? tools,
    List<Receipt>? receipts,
    PendingApproval? Function()? approval,
    bool? cancelled,
  }) => AssistantItem(
    text: text ?? this.text,
    tools: tools ?? this.tools,
    receipts: receipts ?? this.receipts,
    approval: approval == null ? this.approval : approval(),
    cancelled: cancelled ?? this.cancelled,
  );
}

class ToolRowData {
  const ToolRowData({
    required this.callId,
    required this.name,
    this.running = false,
    this.isError = false,
    this.errorCode,
  });

  final String callId;
  final String name;
  final bool running;
  final bool isError;

  /// Why it failed, such as `declined` (the person rejected it) or
  /// `cancelled` (the person stopped the run).
  final String? errorCode;
}

class PendingApproval {
  const PendingApproval({
    required this.callId,
    required this.action,
    required this.args,
    this.summary,
    this.allowAlways = true,
  });

  final String callId;
  final String action;
  final Map<String, Object?> args;

  /// One line saying what the call is for, shown above the arguments.
  final String? summary;

  /// False hides the "Always allow" button.
  final bool allowAlways;
}

/// The chat's state: turns [AgentSession] events into [items] for the
/// widget. Usable on its own with another chat UI.
class AssistantController extends ChangeNotifier {
  AssistantController({
    required this.session,
    required this.threads,
    this.onDevice = false,
  }) : _answerOnly = session.answerOnly;

  final AgentSession session;
  final ThreadStore threads;

  /// Whether [session]'s model runs on this device. Its threads are marked
  /// unshared; a server session asks before sending in such a thread.
  final bool onDevice;

  String? _leavingDevice;

  /// The message held back because it would send an on-device conversation
  /// to a server; null when nothing waits. Resolve it with
  /// [continueOnServer] or [startNewChat].
  String? get leavingDevice => _leavingDevice;

  String? _threadId;
  List<ChatItem> _items = const [];
  bool _running = false;
  bool _answerOnly;
  bool _waiting = false;
  bool _stopping = false;
  bool _openFailed = false;
  bool _newParagraph = false;
  String? _error;
  LlmErrorKind _errorKind = LlmErrorKind.other;
  bool _errorRetryable = false;
  LoopLimitReason? _limit;
  String? _lastUserText;
  bool _disposed = false;

  /// The open thread; null before [open].
  String? get threadId => _threadId;
  List<ChatItem> get items => _items;
  bool get isRunning => _running;
  bool get answerOnly => _answerOnly;

  /// True while a reply runs and the model works out its next step: after
  /// a send, after each tool, and during a retry, until text, a tool or an
  /// approval request arrives. Chats show a thinking indicator then.
  /// Off once Stop is pressed, even while the run winds down.
  bool get isWaiting => _running && _waiting && !_stopping;

  /// The person pressed Stop and the run has not ended yet (a started
  /// write runs to its end).
  bool get isStopping => _running && _stopping;

  /// The pending approval of the newest reply, if any.
  PendingApproval? get pendingApproval => switch (_items.lastOrNull) {
    AssistantItem(:final approval) => approval,
    _ => null,
  };

  /// The last error's detail, for logs and debugging; chats show a message
  /// for [errorKind] instead. Cleared on the next send.
  String? get error => _error;

  /// Why the last run or load failed.
  LlmErrorKind get errorKind => _errorKind;

  /// Whether [retry] may help: a failed load, or a failed send that may work
  /// when sent again.
  bool get canRetry =>
      _error != null &&
      !_running &&
      (_openFailed ||
          (_lastUserText != null &&
              (_errorRetryable || _errorKind == LlmErrorKind.other)));

  /// The safety limit the last run stopped at; cleared on the next send.
  LoopLimitReason? get limit => _limit;

  /// What the person sent last, for a retry button.
  String? get lastUserText => _lastUserText;

  // A reply or a load can finish after the chat is gone; it then has no one
  // to tell.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void>? _opening;
  String? _openingFor;
  var _opens = 0;

  /// Loads thread [threadId], or the newest thread, or a new one. A call for
  /// the same thread while it loads shares that load; the newest call wins.
  /// Ignored while a reply runs. A store error sets [error].
  Future<void> open({String? threadId}) {
    if (_running) return Future.value();
    final current = _opening;
    if (current != null && _openingFor == threadId) return current;
    final load = _open(threadId, ++_opens);
    _opening = load;
    _openingFor = threadId;
    return load.whenComplete(() {
      if (identical(_opening, load)) _opening = null;
    });
  }

  Future<void> _open(String? threadId, int seq) async {
    try {
      var id = threadId;
      if (id == null) {
        final all = await threads.threads();
        id = all.isEmpty ? (await threads.createThread()).id : all.first.id;
      }
      final items = _toItems(await threads.messages(id));
      // A newer open or a send started meanwhile: its state wins.
      if (seq != _opens || _running) return;
      _items = items;
      _threadId = id;
      _leavingDevice = null;
      _clearError();
      _limit = null;
    } catch (e) {
      if (seq != _opens || _running) return;
      _fail('$e', LlmErrorKind.other, retryable: true);
      _openFailed = true;
    }
    notifyListeners();
  }

  final _titles = <String, Future<String?>>{};

  /// What a list of conversations calls [thread]: its title, or its first
  /// message on one line; null while it has none. The store keeps no title
  /// for new threads, so the first message is read once and then cached.
  Future<String?> threadTitle(AssistantThread thread) {
    if (thread.title case final title? when title.trim().isNotEmpty) {
      return Future.value(title);
    }
    return _titles[thread.id] ??= () async {
      String? first;
      try {
        first = (await threads.messages(thread.id))
            .map((m) => m.message)
            .whereType<UserMessage>()
            .firstOrNull
            ?.text
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      } catch (_) {
        // A title is not worth an error; the row shows "untitled".
      }
      // An empty thread may get a first message later, and a failed read
      // may work later: ask again next time.
      if (first == null) _titles.remove(thread.id);
      return first;
    }();
  }

  /// Starts an empty conversation; keeps the current one when it is still
  /// empty, so repeated taps make no empty threads.
  Future<void> newThread() async {
    if (_running) return;
    if (_threadId != null && _items.isEmpty) {
      _clearError();
      _limit = null;
      notifyListeners();
      return;
    }
    try {
      _threadId = (await threads.createThread()).id;
      _items = const [];
      _leavingDevice = null;
      _clearError();
      _limit = null;
    } catch (e) {
      _fail('$e', LlmErrorKind.other, retryable: true);
      _openFailed = true;
    }
    notifyListeners();
  }

  /// Repeats what failed: the load, or the last message.
  Future<void> retry() async {
    if (!canRetry) return;
    if (_openFailed) return open(threadId: _threadId);
    final text = _lastUserText;
    if (text != null) await send(text);
  }

  void _clearError() {
    _error = null;
    _errorKind = LlmErrorKind.other;
    _errorRetryable = false;
    _openFailed = false;
  }

  void _fail(String detail, LlmErrorKind kind, {required bool retryable}) {
    _error = detail;
    _errorKind = kind;
    _errorRetryable = retryable;
    if (kDebugMode) debugPrint('Assistant error ($kind): $detail');
  }

  /// Sends [text] and completes when the reply is finished. Ignores blank
  /// text and sends while a reply is running.
  Future<void> send(String text) async {
    if (text.trim().isEmpty || _running) return;
    if (_threadId == null) await open();
    final threadId = _threadId;
    if (threadId == null) return;

    _running = true;
    _waiting = true;
    _stopping = false;
    _newParagraph = false;
    _clearError();
    _limit = null;
    _lastUserText = text;
    // A retry of a failed send keeps its one message.
    final at = _items.lastIndexWhere((i) => i is UserItem);
    final retry =
        at >= 0 &&
        (_items[at] as UserItem).text == text &&
        _items
            .skip(at + 1)
            .every(
              (i) =>
                  i is AssistantItem &&
                  i.text.isEmpty &&
                  i.tools.isEmpty &&
                  i.receipts.isEmpty,
            );
    final before = _items;
    _items = [
      if (retry)
        ..._items.sublist(0, at + 1)
      else ...[
        ..._items,
        UserItem(text),
      ],
      const AssistantItem(),
    ];
    notifyListeners();

    try {
      // Nothing from an on-device conversation reaches a server unasked.
      if (onDevice) {
        await threads.setUnshared(threadId, true);
      } else if ((await threads.thread(threadId))?.unshared ?? false) {
        // A thread with no messages has nothing to share: drop the mark.
        if ((await threads.messages(threadId)).isEmpty) {
          await threads.setUnshared(threadId, false);
        } else {
          _items = before;
          _leavingDevice = text;
          return;
        }
      }
      // Stop pressed during the check: nothing was sent or stored.
      if (_stopping) {
        _items = before;
        return;
      }
      await for (final event in session.send(threadId, text)) {
        _apply(event);
        notifyListeners();
      }
    } catch (e) {
      _fail('$e', LlmErrorKind.other, retryable: false);
    } finally {
      _running = false;
      _waiting = false;
      _stopping = false;
      _answerOnly = session.answerOnly;
      notifyListeners();
    }
  }

  /// Sends the held message here; the whole conversation goes to the server.
  Future<void> continueOnServer() async {
    final text = _leavingDevice;
    final threadId = _threadId;
    if (text == null || threadId == null) return;
    _leavingDevice = null;
    await threads.setUnshared(threadId, false);
    await send(text);
  }

  /// Sends the held message in a new conversation; the old one stays on
  /// this device.
  Future<void> startNewChat() async {
    final text = _leavingDevice;
    if (text == null) return;
    _leavingDevice = null;
    await newThread();
    await send(text);
  }

  /// Stops the running reply.
  void stop() {
    if (!_running) return;
    _stopping = true;
    session.cancel();
    notifyListeners();
  }

  /// Approves the pending call, with [editedArgs] when given. Returns null
  /// when accepted, or a message when the edited arguments are invalid (the
  /// card then stays). A call that is no longer pending (a second tap, a
  /// stale card) is ignored. [editedArgs] is the hook for an app's own
  /// approval card with argument editing; the built-in card has none.
  String? approve(
    String callId, {
    bool always = false,
    Map<String, Object?>? editedArgs,
  }) => _resolve(
    callId,
    editedArgs == null ? Approve(always: always) : Edit(editedArgs),
  );

  void reject(String callId) => _resolve(callId, const Reject());

  String? _resolve(String callId, ApprovalDecision decision) {
    if (pendingApproval?.callId != callId) return null;
    final String? message;
    try {
      message = session.resolveApproval(callId, decision);
    } on StateError {
      return null;
    }
    if (message == null) {
      _waiting = true;
      _updateReply((item) => item.copyWith(approval: () => null));
      notifyListeners();
    }
    return message;
  }

  void _apply(AgentEvent event) {
    switch (event) {
      case TextDelta(:final text):
        _waiting = false;
        // Text after a tool starts a new paragraph, as it does on reload.
        final gap = _newParagraph ? '\n\n' : '';
        _newParagraph = false;
        _updateReply(
          (item) => item.copyWith(
            text: item.text.isEmpty ? text : item.text + gap + text,
          ),
        );
      case ToolStarted(:final callId, :final name):
        _waiting = false;
        _updateReply(
          (item) => item.copyWith(
            tools: [
              ...item.tools,
              ToolRowData(callId: callId, name: name, running: true),
            ],
          ),
        );
      case ToolFinished(
        :final callId,
        :final name,
        :final isError,
        :final errorCode,
      ):
        _waiting = true;
        _newParagraph = true;
        _updateReply(
          (item) => item.copyWith(
            tools: [
              for (final row in item.tools)
                if (row.callId == callId)
                  ToolRowData(
                    callId: callId,
                    name: name,
                    isError: isError,
                    errorCode: errorCode,
                  )
                else
                  row,
            ],
          ),
        );
      case ApprovalRequired(
        :final callId,
        :final action,
        :final args,
        :final summary,
        :final allowAlways,
      ):
        _waiting = false;
        _updateReply(
          (item) => item.copyWith(
            approval: () => PendingApproval(
              callId: callId,
              action: action,
              args: args,
              summary: summary,
              allowAlways: allowAlways,
            ),
          ),
        );
      case ChangeReceipt(:final receipt):
        _waiting = true;
        _updateReply(
          (item) => item.copyWith(receipts: [...item.receipts, receipt]),
        );
      case AnswerOnly():
        _answerOnly = true;
      case AgentError(:final message, :final kind, :final retryable):
        _fail(message, kind, retryable: retryable);
      case LoopLimit(:final reason):
        _limit = reason;
      case Cancelled():
        _updateReply(
          (item) => item.copyWith(cancelled: true, approval: () => null),
        );
      case Done():
        break;
    }
  }

  /// Replaces the last assistant item with [change] applied to it.
  void _updateReply(AssistantItem Function(AssistantItem item) change) {
    final index = _items.lastIndexWhere((i) => i is AssistantItem);
    final item = index < 0 ? null : _items[index];
    if (item is! AssistantItem) return;
    _items = [..._items]..[index] = change(item);
  }

  /// Stored messages as items: each person message, then one assistant item
  /// for everything until the next one.
  static List<ChatItem> _toItems(List<StoredMessage> stored) {
    final items = <ChatItem>[];
    AssistantItem? reply;
    void flush() {
      if (reply case final item?) items.add(item);
      reply = null;
    }

    for (final entry in stored) {
      switch (entry.message) {
        case UserMessage(:final text):
          flush();
          items.add(UserItem(text));
        case AssistantMessage(:final text, :final toolCalls):
          final current = reply ?? const AssistantItem();
          reply = current.copyWith(
            text: [
              if (current.text.isNotEmpty) current.text,
              if (text.isNotEmpty) text,
            ].join('\n\n'),
            tools: [
              ...current.tools,
              for (final call in toolCalls)
                ToolRowData(callId: call.id, name: call.name),
            ],
            receipts: [...current.receipts, ...entry.receipts],
          );
        case ToolResultMessage(:final callId, :final isError, :final content):
          final current = reply;
          if (current == null || !isError) continue;
          reply = current.copyWith(
            tools: [
              for (final row in current.tools)
                if (row.callId == callId)
                  ToolRowData(
                    callId: callId,
                    name: row.name,
                    isError: true,
                    errorCode: _errorCode(content),
                  )
                else
                  row,
            ],
          );
      }
    }
    flush();
    return items;
  }

  /// The `error` code of a stored tool result, such as `declined`.
  static String? _errorCode(String content) {
    try {
      return switch (jsonDecode(content)) {
        {'error': final String code} => code,
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }
}
