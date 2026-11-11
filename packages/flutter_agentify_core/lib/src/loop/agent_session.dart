import 'dart:async';
import 'dart:convert';

import '../actions/action_context.dart';
import '../actions/action_failure.dart';
import '../actions/action_registry.dart';
import '../actions/agent_action.dart';
import '../cancel_token.dart';
import '../context/app_context.dart';
import '../context/screen_actions.dart';
import '../llm/llm_provider.dart';
import '../llm/llm_types.dart';
import '../schema/schema.dart';
import '../secrets/redactor.dart';
import '../storage/memory_store.dart';
import '../storage/thread_store.dart';
import '../text.dart';
import 'agent_config.dart';
import 'agent_event.dart';
import 'approval.dart';
import 'debug_snapshot.dart';
import 'history.dart';
import 'prompt_builder.dart';
import 'tool_search.dart';

const _declined = 'The user declined this action.';
const _maxRetryWait = Duration(seconds: 30);
const _summaryInstructions =
    'Summarize the conversation below for your own later use, in a few short '
    'sentences. Keep names, ids, numbers and decisions. Write only the '
    'summary.';

final _toolSearchSpec = ToolSpec(
  name: toolSearchName,
  description:
      'Finds more tools by what they do. Tools it finds can be called from '
      'the next step on.',
  parameters: S
      .object(
        fields: {
          'query': S.string(
            description: 'Words describing what you want to do.',
            minLength: 1,
          ),
        },
        build: (v) => v['query'] as String,
      )
      .toJsonSchema(),
);

/// The model's reply to one request.
typedef _Reply = ({
  String text,
  List<ToolCall> calls,
  Usage? usage,
  ProviderContent? content,
  bool truncated,
});

/// The assistant: runs the conversation loop between the person, the model
/// and the app's actions.
class AgentSession {
  AgentSession({
    required this.registry,
    required this.appContext,
    required this.provider,
    required this.model,
    required this.threads,
    required this.memories,
    this.appInstructions = '',
    this.config = const AgentConfig(),
    Future<void> Function(Duration)? delay,
    ApprovalPrefs? approvals,
  }) : _delay = delay ?? Future<void>.delayed,
       approvals = approvals ?? InMemoryApprovalPrefs();

  final ActionRegistry registry;
  final AppContext appContext;
  final LlmProvider provider;
  final ModelConfig model;
  final ThreadStore threads;
  final MemoryStore memories;

  /// The app's runtime instructions for its assistant.
  final String appInstructions;
  final AgentConfig config;
  final Future<void> Function(Duration) _delay;

  /// Actions the person allowed for good.
  final ApprovalPrefs approvals;

  CancelToken? _cancel;
  DebugSnapshot? _debug;
  final _pending =
      <String, ({String action, Completer<ApprovalDecision> answer})>{};

  final _answerOnlyModels = <String>{};

  /// Tools found by search or by a message, per thread, oldest first; capped
  /// at [_maxActivated].
  final _activated = <String, Set<String>>{};
  static const _maxActivated = 8;

  bool get isRunning => _cancel != null;

  /// Whether the model answers without tools: it has no tool calling, or
  /// the server said it does not support tools.
  bool get answerOnly =>
      !model.toolCalling || _answerOnlyModels.contains(model.model);

  /// Whether a step sends a subset of tools plus `tool_search`.
  bool get _toolSearchOn =>
      config.forceToolSearch ||
      (model.contextWindow < config.smallContextWindow &&
          estimateTokens(
                jsonEncode([
                  for (final t in registry.tools)
                    {
                      'name': t.name,
                      'description': t.description,
                      'parameters': t.input.toJsonSchema(),
                    },
                ]),
              ) >
              model.contextWindow * config.toolSearchShare);

  /// Remembers [names] for later steps of the thread; the oldest go first.
  void _activate(String threadId, Iterable<String> names) {
    final set = _activated.putIfAbsent(threadId, () => {});
    for (final name in names) {
      set
        ..remove(name)
        ..add(name);
    }
    while (set.length > _maxActivated) {
      set.remove(set.first);
    }
  }

  bool get _compact => model.contextWindow < config.smallContextWindow;

  /// The last request, for the debug inspector; null before the first run.
  DebugSnapshot? get debugSnapshot => _debug;

  /// Sends [text] in thread [threadId] and runs until the reply is done.
  ///
  /// Throws [ArgumentError] for blank text and [StateError] while another run
  /// is active, before any request is made. The stream ends with exactly one
  /// of [Done], [Cancelled], [LoopLimit] or [AgentError], then closes.
  Stream<AgentEvent> send(String threadId, String text) {
    if (text.trim().isEmpty) {
      throw ArgumentError.value(text, 'text', 'must not be blank');
    }
    if (isRunning) throw StateError('The assistant is already running.');
    final cancel = _cancel = CancelToken();
    final events = StreamController<AgentEvent>();
    unawaited(() async {
      final run = _Run(this, threadId, cancel, events.add);
      try {
        events.add(await run.execute(text));
      } finally {
        _cancel = null;
        await events.close();
      }
    }());
    return events.stream;
  }

  /// Stops the active run; its stream ends with [Cancelled].
  void cancel() => _cancel?.cancel();

  /// Answers the pending [ApprovalRequired] for [callId]. Returns null when
  /// accepted; returns a message when edited arguments are invalid, and the
  /// approval then stays pending. Does nothing for a [callId] that is not
  /// pending (already answered, or the run was stopped): a button tap can
  /// race with Stop.
  String? resolveApproval(String callId, ApprovalDecision decision) {
    final pending = _pending[callId];
    if (pending == null) return null;
    if (decision case Edit(:final args)) {
      try {
        registry.find(pending.action)?.input.parse(args);
      } on SchemaError catch (e) {
        return '${e.path}: ${e.message}';
      } catch (e) {
        return const Redactor().redact('$e');
      }
    }
    _pending.remove(callId);
    pending.answer.complete(decision);
    return null;
  }
}

/// One run: everything between a message and the final event.
class _Run {
  _Run(this.session, this.threadId, this.cancel, this.emit);

  final AgentSession session;
  final String threadId;
  final CancelToken cancel;
  final void Function(AgentEvent) emit;

  final _receipts = <Receipt>[];
  final _calls = <ToolFinished>[];
  String? _lastCallKey;
  var _repeats = 0;
  int? _lastInputTokens;

  /// Tool calls stored without a result yet.
  final _open = <ToolCall>[];
  var _tokens = 0;
  var _repliedLast = false;
  var _saidAnswerOnly = false;
  var _overflowHandled = false;

  /// Names of the tools the current step sent.
  var _offered = const <String>{};

  AgentConfig get config => session.config;

  Future<AgentEvent> execute(String text) async {
    AgentEvent end;
    try {
      end = await _loop(text);
    } catch (e) {
      end = _error(e);
    }
    try {
      await _finish(end);
    } catch (e) {
      end = _error(e);
    }
    return end;
  }

  static AgentError _error(Object e) {
    const redactor = Redactor();
    return e is LlmError
        ? AgentError(
            redactor.redact(e.message),
            retryable: e.retryable,
            kind: e.kind,
          )
        : AgentError(redactor.redact('$e'));
  }

  Future<AgentEvent> _loop(String text) async {
    final screen = await session.appContext.currentScreenBlock(
      maxChars: config.currentScreenMaxChars,
    );
    // A thread only ends with a person message when the run before it failed
    // without a reply: a retry of the same text must not store it twice.
    final stored = await session.threads.messages(threadId);
    final last = stored.isEmpty ? null : stored.last.message;
    if (!(last is UserMessage && last.text == text)) {
      await session.threads.append(
        threadId,
        StoredMessage(UserMessage(text, context: screen)),
      );
    }

    // The system text stays fixed for the whole run: a memory saved mid-run
    // shows from the next run, so replies stay valid for replay.
    String? system;
    bool? systemAnswerOnly;
    for (var step = 0; ; step++) {
      if (cancel.isCancelled) return Cancelled();
      if (step > 0 && _tokens > config.tokenBudget) {
        return LoopLimit(LoopLimitReason.tokenBudget);
      }
      if (step >= config.maxSteps) return LoopLimit(LoopLimitReason.maxSteps);

      final answerOnly = session.answerOnly;
      if (answerOnly && !_saidAnswerOnly) {
        _saidAnswerOnly = true;
        emit(AnswerOnly());
      }
      final tools = answerOnly ? const <ToolSpec>[] : _stepTools(text);
      _offered = {for (final t in tools) t.name};
      if (system == null || systemAnswerOnly != answerOnly) {
        system = await _system(answerOnly);
        systemAnswerOnly = answerOnly;
      }
      if (await _fitHistory(system, tools)) system = await _system(answerOnly);
      if (cancel.isCancelled) return Cancelled();
      final stepSystem = system;
      final history = await _history();
      void snapshot(Usage? usage) => session._debug = DebugSnapshot(
        system: stepSystem,
        activeTools: [for (final t in tools) t.name],
        lastCalls: List.unmodifiable(_calls),
        lastUsage: usage,
      );
      snapshot(session._debug?.lastUsage);

      final _Reply? reply;
      try {
        reply = await _ask(stepSystem, history, tools);
      } on LlmError catch (e) {
        if (e.toolsUnsupported && !answerOnly) {
          session._answerOnlyModels.add(session.model.model);
          step--;
          continue;
        }
        if (e.contextOverflow && !_overflowHandled) {
          _overflowHandled = true;
          if (await _fitHistory(stepSystem, tools, force: true)) {
            system = await _system(answerOnly);
            step--;
            continue;
          }
        }
        rethrow;
      }
      if (reply == null) return Cancelled();
      _tokens += _used(reply, stepSystem, history);
      snapshot(reply.usage);

      // A cut-off reply keeps only its text: its tool calls and provider
      // content may be incomplete.
      if (reply.truncated) {
        if (reply.text.isNotEmpty) {
          await _store(AssistantMessage(reply.text), receipts: _receipts);
          _repliedLast = true;
        }
        return LoopLimit(LoopLimitReason.outputLimit);
      }
      if (reply.calls.isEmpty) {
        await _store(
          AssistantMessage(reply.text, providerContent: reply.content),
          receipts: _receipts,
        );
        _repliedLast = true;
        return Done();
      }
      await _store(
        AssistantMessage(
          reply.text,
          toolCalls: reply.calls,
          providerContent: reply.content,
        ),
      );
      _open.addAll(reply.calls);

      for (final call in reply.calls) {
        if (cancel.isCancelled) return Cancelled();
        final key =
            '${call.name} ${_canonical(call.arguments) ?? call.rawArguments}';
        _repeats = key == _lastCallKey ? _repeats + 1 : 1;
        _lastCallKey = key;
        if (_repeats >= config.repeatLimit) {
          return LoopLimit(LoopLimitReason.repeatedCall);
        }
        final finished = await _runTool(call);
        if (finished == null) return Cancelled();
      }
    }
  }

  Future<String> _system(bool answerOnly) async {
    final thread = await session.threads.thread(threadId);
    return PromptBuilder(
      appInstructions: session.appInstructions,
      compact: session._compact,
    ).system(
      memories: await session.memories.all(),
      threadSummary: thread?.summary,
      answerOnly: answerOnly,
    );
  }

  /// Every tool, or with tool search on: the built-ins, the tools activated
  /// in this thread, the best matches for [text], and `tool_search`.
  List<ToolSpec> _stepTools(String text) {
    final all = session.registry.tools;
    if (!session._toolSearchOn) return [for (final tool in all) _spec(tool)];
    // Remembered, so a follow-up like "do it again" keeps the tool.
    session._activate(threadId, [
      for (final tool in searchTools(all, text, limit: 4)) tool.name,
    ]);
    final chosen = {
      for (final tool in all)
        if (builtInActionNames.contains(tool.name)) tool.name,
      ...?session._activated[threadId],
    };
    return [
      for (final tool in all)
        if (chosen.contains(tool.name)) _spec(tool),
      _toolSearchSpec,
    ];
  }

  /// Summarizes or drops the oldest messages when the history does not fit
  /// next to [system] and [tools]; with [force], cuts it to about half. True
  /// when the thread changed.
  Future<bool> _fitHistory(
    String system,
    List<ToolSpec> tools, {
    bool force = false,
  }) async {
    final model = session.model;
    final stored = await session.threads.messages(threadId);
    final total = stored.fold(0, (sum, m) => sum + messageTokens(m));
    final schemas = jsonEncode([
      for (final t in tools)
        {
          'name': t.name,
          'description': t.description,
          'parameters': t.parameters,
        },
    ]);
    final budget =
        model.contextWindow -
        model.maxOutputTokens -
        estimateTokens(system) -
        estimateTokens(schemas);
    if (!force && total <= budget) return false;
    final cut = historyCutIndex(
      stored,
      budgetTokens: force ? total ~/ 2 : budget,
      keepRecent: config.keepRecentMessages,
    );
    if (cut <= 0) return false;

    final previous = (await session.threads.thread(threadId))?.summary;
    var summary = '';
    try {
      summary = await _summarize(previous, stored.sublist(0, cut));
    } on Exception {
      // A weak model may fail here; the old messages are dropped anyway.
    }
    // Stopped mid-summary: keep the history as it is.
    if (cancel.isCancelled) return false;
    if (summary.trim().isEmpty) summary = previous ?? '';
    await session.threads.summarize(
      threadId,
      summary: summary.trim(),
      dropCount: cut,
    );
    return true;
  }

  Future<String> _summarize(String? previous, List<StoredMessage> old) async {
    // The request must fit the window itself: cap each line, and keep the
    // newest lines that fit in 60% of it.
    var room = session.model.contextWindow * 6 ~/ 10;
    final kept = <String>[];
    for (final stored in old.reversed) {
      final line = cutText(_transcriptLine(stored.message), 600, suffix: '...');
      room -= estimateTokens(line) + 1;
      if (room < 0) break;
      kept.add(line);
    }
    final transcript = [
      if (previous != null && previous.isNotEmpty)
        'Earlier summary: ${cutText(previous, 1000, suffix: '...')}',
      ...kept.reversed,
    ].join('\n');
    final text = StringBuffer();
    await for (final event in session.provider.stream(
      system: _summaryInstructions,
      messages: [UserMessage(transcript)],
      config: session.model,
      cancel: cancel,
    )) {
      if (event is LlmTextDelta) text.write(event.text);
    }
    return '$text';
  }

  static String _transcriptLine(ChatMessage message) => switch (message) {
    UserMessage(:final text) => 'Person: $text',
    AssistantMessage(:final text, :final toolCalls) => [
      if (text.isNotEmpty) 'Assistant: $text',
      for (final call in toolCalls)
        'Assistant called ${call.name} ${call.rawArguments}',
    ].join('\n'),
    ToolResultMessage(:final name, :final content) =>
      'Result of $name: ${cutText(content, 300)}',
  };

  /// The stored conversation, without empty assistant messages, with a
  /// cancelled result for every call a crash left unanswered.
  Future<List<ChatMessage>> _history() async => withToolResults([
    for (final stored in await session.threads.messages(threadId))
      if (stored.message case final m
          when m is! AssistantMessage ||
              m.text.isNotEmpty ||
              m.toolCalls.isNotEmpty)
        m,
  ]);

  static ToolSpec _spec(AgentAction<Object?, Object?> action) => ToolSpec(
    name: action.name,
    description: action.description,
    parameters: action.input.toJsonSchema(),
  );

  /// One model request, retried when it may succeed later. Null when
  /// cancelled.
  Future<_Reply?> _ask(
    String system,
    List<ChatMessage> history,
    List<ToolSpec> tools,
  ) async {
    for (var attempt = 0; ; attempt++) {
      final text = StringBuffer();
      final calls = <ToolCall>[];
      Usage? usage;
      ProviderContent? content;
      var truncated = false;
      var done = false;
      try {
        final stream = session.provider.stream(
          system: system,
          messages: history,
          tools: tools,
          config: session.model,
          cancel: cancel,
        );
        await for (final event in stream) {
          switch (event) {
            case LlmTextDelta(text: final delta):
              text.write(delta);
              emit(TextDelta(delta));
            case LlmToolCall(:final call):
              calls.add(call);
            case LlmDone(
              usage: final reported,
              content: final raw,
              truncated: final cut,
            ):
              usage = reported;
              content = raw;
              truncated = cut;
              done = true;
          }
        }
        if (!done && !cancel.isCancelled) {
          throw const LlmError(
            'The model stopped before finishing its reply.',
            kind: LlmErrorKind.badReply,
            retryable: true,
          );
        }
      } on LlmError catch (e) {
        if (cancel.isCancelled) return _partial(text);
        final silent = text.isEmpty && calls.isEmpty;
        // A timeout already waited [llmIdleTimeout]; waiting again silently
        // would keep the person waiting minutes. They can press Retry.
        if (e.retryable &&
            e.kind != LlmErrorKind.timeout &&
            silent &&
            attempt < config.maxRetries) {
          var wait = e.retryAfter ?? Duration(seconds: 1 << attempt);
          if (wait > _maxRetryWait) wait = _maxRetryWait;
          await Future.any([session._delay(wait), cancel.whenCancelled]);
          if (cancel.isCancelled) return null;
          continue;
        }
        await _partial(text);
        rethrow;
      }
      if (cancel.isCancelled || !done) return _partial(text);
      return (
        text: '$text',
        calls: calls,
        usage: usage,
        content: content,
        truncated: truncated,
      );
    }
  }

  /// Keeps text the person already saw when a request ends early.
  Future<Null> _partial(StringBuffer text) async {
    if (text.isNotEmpty) await _store(AssistantMessage('$text'));
    return null;
  }

  /// Tokens this run spent on this step: its output, plus the input that
  /// grew since the last step (the history is sent again on every step).
  int _used(_Reply reply, String system, List<ChatMessage> history) {
    final usage = reply.usage;
    final input =
        usage?.inputTokens ??
        ((system.length +
                    jsonEncode([for (final m in history) m.toJson()]).length) /
                4)
            .ceil();
    final output = usage?.outputTokens ?? (reply.text.length / 4).ceil();
    // The next request repeats this input and this output, so only what
    // comes on top of both (tool results) is new. The first step counts its
    // output only: the thread's history is not this run's spending.
    final previous = _lastInputTokens;
    _lastInputTokens = input + output;
    final growth = previous == null ? 0 : input - previous;
    return output + (growth > 0 ? growth : 0);
  }

  /// Runs one tool call, after approval when it needs one, and stores its
  /// result. Null when cancelled first.
  Future<ToolFinished?> _runTool(ToolCall call) async {
    if (call.name == toolSearchName && session._toolSearchOn) {
      return _searchTools(call);
    }
    if (session._toolSearchOn && !_offered.contains(call.name)) {
      emit(ToolStarted(callId: call.id, name: call.name, args: call.arguments));
      return _record(
        call,
        ToolFinished(
          callId: call.id,
          name: call.name,
          content: jsonEncode({
            'error': 'tool_not_available',
            'message':
                'This tool is not available in this step. Call '
                '$toolSearchName to find it first.',
          }),
          isError: true,
          errorCode: 'tool_not_available',
        ),
        const [],
      );
    }
    var arguments = call.arguments;
    final needsApproval =
        arguments != null &&
        session.registry.requiresApproval(call.name, arguments);
    // Always-allow counts only for an action that permits it.
    final allowAlways = session.registry.find(call.name)?.allowAlways ?? false;
    var approved =
        needsApproval &&
        allowAlways &&
        session.approvals.isAlwaysAllowed(call.name);
    if (arguments != null && needsApproval && !approved) {
      final decision = await _approval(call, arguments);
      switch (decision) {
        case null:
          return null;
        case Reject():
          emit(ToolStarted(callId: call.id, name: call.name, args: arguments));
          return _record(
            call,
            ToolFinished(
              callId: call.id,
              name: call.name,
              content: jsonEncode({'error': 'declined', 'message': _declined}),
              isError: true,
              errorCode: 'declined',
            ),
            const [],
          );
        case Approve(:final always):
          if (always && allowAlways) {
            await session.approvals.setAlwaysAllowed(call.name, true);
          }
        case Edit(:final args):
          arguments = args;
      }
      approved = true;
    }

    emit(ToolStarted(callId: call.id, name: call.name, args: arguments));
    final outcome = _call(call, arguments, approved: approved);
    // A write that started runs to its end, so Stop never hides a change.
    final writes = session.registry.find(call.name)?.readOnly == false;
    final winner = writes
        ? await outcome
        : await Future.any([outcome, cancel.whenCancelled.then((_) => null)]);
    if (winner == null) return null;
    final (finished, receipts) = winner;
    return _record(call, finished, receipts);
  }

  /// Handles `tool_search` in the loop: lists matches and activates them.
  Future<ToolFinished> _searchTools(ToolCall call) {
    emit(ToolStarted(callId: call.id, name: call.name, args: call.arguments));
    final query = call.arguments?['query'];
    if (query is! String || query.trim().isEmpty) {
      return _record(
        call,
        ToolFinished(
          callId: call.id,
          name: call.name,
          content: jsonEncode({
            'error': 'invalid_input',
            'message': 'Give a query: words describing what you want to do.',
          }),
          isError: true,
          errorCode: 'invalid_input',
        ),
        const [],
      );
    }
    final found = searchTools(session.registry.tools, query);
    session._activate(threadId, found.map((t) => t.name));
    return _record(
      call,
      ToolFinished(
        callId: call.id,
        name: call.name,
        content: jsonEncode([
          for (final tool in found)
            {'name': tool.name, 'description': cutText(tool.description, 120)},
        ]),
      ),
      const [],
    );
  }

  /// Waits for the person's decision on [call]; null when cancelled first.
  Future<ApprovalDecision?> _approval(
    ToolCall call,
    Map<String, Object?> arguments,
  ) async {
    final info = await session.registry.approvalInfo(call.name, arguments);
    if (cancel.isCancelled) return null;
    final answer = Completer<ApprovalDecision>();
    session._pending[call.id] = (action: call.name, answer: answer);
    emit(
      ApprovalRequired(
        callId: call.id,
        action: call.name,
        args: arguments,
        summary: info.summary,
        allowAlways: info.allowAlways,
      ),
    );
    try {
      return await Future.any([
        answer.future,
        cancel.whenCancelled.then((_) => null),
      ]);
    } finally {
      session._pending.remove(call.id);
    }
  }

  /// Stores and reports a finished call.
  Future<ToolFinished> _record(
    ToolCall call,
    ToolFinished finished,
    List<Receipt> receipts,
  ) async {
    await _result(call, finished.content, isError: finished.isError);
    emit(finished);
    _calls.add(finished);
    for (final receipt in receipts) {
      _receipts.add(receipt);
      emit(ChangeReceipt(receipt));
    }
    return finished;
  }

  Future<(ToolFinished, List<Receipt>)> _call(
    ToolCall call,
    Map<String, Object?>? arguments, {
    bool approved = false,
  }) async {
    try {
      if (arguments == null) {
        throw const ActionFailure(
          'invalid_input',
          'The arguments are not a JSON object.',
        );
      }
      final result = await session.registry.call(
        call.name,
        arguments,
        caller: Caller.assistant,
        approved: approved,
        cancel: cancel,
      );
      return (
        ToolFinished(callId: call.id, name: call.name, content: result.content),
        result.receipts,
      );
    } on ActionFailure catch (f) {
      return (
        ToolFinished(
          callId: call.id,
          name: call.name,
          content: const Redactor().redact(
            jsonEncode({
              'error': f.code,
              'message': f.message,
              'details': ?f.details,
            }),
          ),
          isError: true,
          errorCode: f.code,
        ),
        // A partial write still shows what was saved.
        f.receipts,
      );
    }
  }

  Future<void> _result(ToolCall call, String content, {bool isError = false}) {
    _open.remove(call);
    return _store(
      ToolResultMessage(
        callId: call.id,
        name: call.name,
        content: content,
        isError: isError,
      ),
    );
  }

  Future<void> _store(
    ChatMessage message, {
    List<Receipt> receipts = const [],
  }) => session.threads.append(
    threadId,
    StoredMessage(message, receipts: List.of(receipts)),
  );

  /// Keeps the thread valid: every stored call gets a result, and receipts
  /// of a run that ended early still reach storage.
  Future<void> _finish(AgentEvent end) async {
    // Calls a loop limit left open were not stopped by the person.
    final code = end is LoopLimit ? 'loop_limit' : 'cancelled';
    final content = '{"error":"$code"}';
    for (final call in List.of(_open)) {
      await _result(call, content, isError: true);
      emit(
        ToolFinished(
          callId: call.id,
          name: call.name,
          content: content,
          isError: true,
          errorCode: code,
        ),
      );
    }
    if (!_repliedLast && _receipts.isNotEmpty) {
      await _store(AssistantMessage(''), receipts: _receipts);
    }
  }

  /// [value] as JSON with map keys sorted, so equal arguments compare equal.
  static String? _canonical(Object? value) {
    if (value == null) return null;
    Object? sort(Object? v) => switch (v) {
      Map() => {
        for (final key in v.keys.map((k) => '$k').toList()..sort())
          key: sort(v[key]),
      },
      List() => [for (final item in v) sort(item)],
      _ => v,
    };
    return jsonEncode(sort(value));
  }
}
