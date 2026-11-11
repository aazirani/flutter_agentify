import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';

import 'assistant_controller.dart';
import 'assistant_inspector.dart';
import 'assistant_strings.dart';
import 'widgets/approval_card.dart';
import 'widgets/composer.dart';
import 'widgets/message_bubble.dart';
import 'widgets/model_status.dart';
import 'widgets/receipt_chips.dart';
import 'widgets/thinking_dots.dart';
import 'widgets/tool_row.dart';

/// Errors that a change in the app's model settings may fix.
const _settingsKinds = {
  LlmErrorKind.connection,
  LlmErrorKind.auth,
  LlmErrorKind.notFound,
  LlmErrorKind.request,
  LlmErrorKind.badReply,
};

/// The assistant's chat: messages that follow the newest one, a thinking
/// indicator while the model works, tool progress, approval cards, receipts,
/// past conversations, and a composer with a stop button. Colors come from
/// the theme and text from [strings].
class AssistantChat extends StatefulWidget {
  const AssistantChat({
    super.key,
    required this.controller,
    this.strings = const AssistantStrings(),
    this.inspect,
    this.onOpenSettings,
    this.onClose,
    this.modelStatus,
  });

  final AssistantController controller;
  final AssistantStrings strings;

  /// When set, debug builds show a button that opens the
  /// [AssistantInspector] for this session.
  final AgentSession? inspect;

  /// When set, errors that the model settings may fix offer a button that
  /// calls it.
  final VoidCallback? onOpenSettings;

  /// When set, the header shows a close button that calls it (for a chat in
  /// a sheet).
  final VoidCallback? onClose;

  /// Which model answers and the in-app model's state; null for an app with
  /// only a server. With no model to answer, the state replaces the input.
  final ModelStatus? modelStatus;

  @override
  State<AssistantChat> createState() => _AssistantChatState();
}

class _AssistantChatState extends State<AssistantChat> {
  final _scroll = ScrollController();
  var _showJump = false;
  var _wasRunning = false;

  /// Where the model inside the app took over: the thread and how many items
  /// came before.
  ({String? thread, int at})? _deviceFrom;

  AssistantController get controller => widget.controller;
  AssistantStrings get strings => widget.strings;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    controller.addListener(_onChange);
    _wasRunning = controller.isRunning;
  }

  @override
  void didUpdateWidget(AssistantChat old) {
    super.didUpdateWidget(old);
    if (old.controller != controller) {
      old.controller.removeListener(_onChange);
      controller.addListener(_onChange);
    }
    // The old controller still holds the conversation; a new one is loading.
    if (old.modelStatus?.answeredBy == AnsweredBy.server &&
        widget.modelStatus?.answeredBy == AnsweredBy.device &&
        old.controller.items.isNotEmpty) {
      _deviceFrom = (
        thread: old.controller.threadId,
        at: old.controller.items.length,
      );
    }
  }

  @override
  void dispose() {
    controller.removeListener(_onChange);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scroll.offset > 200;
    if (show != _showJump) setState(() => _showJump = show);
  }

  /// Tells a screen reader the reply once a run ends, not every piece. An
  /// error is not announced here: its banner is a live region.
  void _onChange() {
    // A new chat unmounts the list; the next one starts at the newest message.
    if (controller.items.isEmpty) _showJump = false;
    final running = controller.isRunning;
    if (_wasRunning && !running && mounted && controller.error == null) {
      final reply = controller.items.lastOrNull;
      final message = reply is AssistantItem && reply.text.isNotEmpty
          ? reply.text
          : null;
      if (message != null) {
        SemanticsService.sendAnnouncement(
          View.of(context),
          message,
          textDirectionOf(message) ?? Directionality.of(context),
        );
      }
    }
    _wasRunning = running;
  }

  void _toLatest() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _send(String text) {
    controller.send(text);
    _toLatest();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final items = controller.items;
        final waiting = controller.isWaiting;
        final line = _deviceFrom;
        final at = line != null && line.thread == controller.threadId
            ? line.at
            : null;
        final total = items.length + (at != null && at <= items.length ? 1 : 0);
        final count = total + (waiting ? 1 : 0);
        Widget row(int k) {
          if (at != null && total > items.length) {
            if (k == at) return _Line(text: strings.onDeviceNowAnswering);
            if (k > at) k--;
          }
          return _item(context, items[k]);
        }

        final status = widget.modelStatus;
        final noModel = status?.answeredBy == AnsweredBy.none;
        return Column(
          children: [
            _header(context),
            Expanded(
              child: items.isEmpty
                  ? noModel
                        ? _Empty(
                            title: strings.notReadyTitle,
                            body: strings.notReadyBody,
                          )
                        : _Empty(
                            title: strings.emptyTitle,
                            body: strings.emptyBody,
                          )
                  : Stack(
                      children: [
                        ListView.builder(
                          controller: _scroll,
                          reverse: true,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: count,
                          itemBuilder: (context, i) {
                            if (waiting && i == 0) {
                              return ThinkingDots(label: strings.thinking);
                            }
                            return row(count - 1 - i);
                          },
                        ),
                        if (_showJump && _scroll.hasClients)
                          PositionedDirectional(
                            end: 12,
                            bottom: 8,
                            child: IconButton.filledTonal(
                              onPressed: _toLatest,
                              tooltip: strings.jumpToLatest,
                              icon: const Icon(Icons.arrow_downward),
                            ),
                          ),
                      ],
                    ),
            ),
            if (_status() case final banner?) banner,
            if (controller.answerOnly)
              _Banner(icon: Icons.info_outline, text: strings.answerOnlyNotice),
            if (status != null)
              ModelStatusView(status: status, strings: strings),
            if (!noModel)
              Composer(
                running: controller.isRunning,
                stopping: controller.isStopping,
                strings: strings,
                onSend: _send,
                onStop: controller.stop,
              ),
          ],
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    final running = controller.isRunning;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            strings.title,
            style: Theme.of(context).textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (widget.modelStatus?.label(strings) case final label?)
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
    final buttons = _headerButtons(context, running);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Each button is 48 wide; the title and model name need room.
        final titleRoom = constraints.maxWidth - 20 - buttons.length * 48;
        final scale = MediaQuery.textScalerOf(context).scale(1);
        if (titleRoom >= 160 * scale) {
          return Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
            child: Row(
              children: [
                Expanded(child: title),
                ...buttons,
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              Wrap(alignment: WrapAlignment.end, children: buttons),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _headerButtons(BuildContext context, bool running) {
    return [
      if (widget.modelStatus?.menu(strings) case final items?
          when items.isNotEmpty)
        PopupMenuButton<VoidCallback>(
          tooltip: strings.onDeviceMenu,
          icon: const Icon(Icons.memory),
          onSelected: (action) => action(),
          itemBuilder: (_) => [
            for (final (label, action) in items)
              PopupMenuItem(value: action, child: Text(label)),
          ],
        ),
      if (widget.inspect case final session? when kDebugMode)
        IconButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => FractionallySizedBox(
              heightFactor: 0.85,
              child: AssistantInspector(session: session, strings: strings),
            ),
          ),
          tooltip: strings.inspectorOpen,
          icon: const Icon(Icons.bug_report_outlined),
        ),
      IconButton(
        onPressed: running ? null : () => _showConversations(context),
        tooltip: strings.conversations,
        icon: const Icon(Icons.history),
      ),
      IconButton(
        onPressed: running ? null : controller.newThread,
        tooltip: strings.newChat,
        icon: const Icon(Icons.add_comment_outlined),
      ),
      if (widget.onClose case final close?)
        IconButton(
          onPressed: close,
          tooltip: strings.close,
          icon: const Icon(Icons.close),
        ),
    ];
  }

  Future<void> _showConversations(BuildContext context) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.7,
        child: _Conversations(controller: controller, strings: strings),
      ),
    );
    if (id != null && id != controller.threadId) {
      await controller.open(threadId: id);
    }
  }

  Widget _item(BuildContext context, ChatItem item) => switch (item) {
    UserItem(:final text) => MessageBubble(fromUser: true, text: text),
    AssistantItem() => _reply(context, item),
  };

  Widget _reply(BuildContext context, AssistantItem item) {
    final approval = item.approval;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final tool in item.tools)
          // Tool search is the loop's own bookkeeping, not an app action.
          if (tool.name != toolSearchName)
            ToolRow(tool: tool, strings: strings),
        if (item.text.isNotEmpty)
          MessageBubble(fromUser: false, text: item.text, selectable: true),
        if (approval != null)
          ApprovalCard(
            approval: approval,
            strings: strings,
            // No decision while stopping: the run ends on its own.
            onApprove: controller.isStopping
                ? null
                : () => controller.approve(approval.callId),
            onAlwaysAllow: controller.isStopping
                ? null
                : () => controller.approve(approval.callId, always: true),
            onReject: controller.isStopping
                ? null
                : () => controller.reject(approval.callId),
          ),
        if (item.receipts.isNotEmpty)
          ReceiptChips(receipts: item.receipts, strings: strings),
        if (item.cancelled)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              strings.cancelled,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Widget? _status() {
    if (controller.isRunning) return null;
    // Their own size: an app theme may make buttons full width.
    const size = Size(64, 40);
    if (controller.leavingDevice != null) {
      final server = widget.modelStatus?.serverLabel ?? strings.modelServer;
      return _Banner(
        icon: Icons.cloud_upload_outlined,
        text: strings.onDeviceLeaveBody.replaceAll('{server}', server),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: size),
            onPressed: controller.startNewChat,
            child: Text(strings.onDeviceLeaveNew),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: size),
            onPressed: controller.continueOnServer,
            child: Text(
              strings.onDeviceLeaveContinue.replaceAll('{server}', server),
            ),
          ),
        ],
      );
    }
    if (controller.error != null) {
      final kind = controller.errorKind;
      final settings = widget.onOpenSettings;
      final onDevice = widget.modelStatus?.answeredBy == AnsweredBy.device;
      return _Banner(
        icon: Icons.error_outline,
        text: onDevice ? strings.errorDevice : strings.error(kind),
        isError: true,
        actions: [
          if (settings != null && !onDevice && _settingsKinds.contains(kind))
            TextButton(
              style: TextButton.styleFrom(minimumSize: size),
              onPressed: settings,
              child: Text(strings.openSettings),
            ),
          if (controller.canRetry)
            TextButton(
              style: TextButton.styleFrom(minimumSize: size),
              onPressed: () {
                controller.retry();
                _toLatest();
              },
              child: Text(strings.retry),
            ),
        ],
      );
    }
    final text = switch (controller.limit) {
      LoopLimitReason.maxSteps => strings.limitMaxSteps,
      LoopLimitReason.tokenBudget => strings.limitTokenBudget,
      LoopLimitReason.repeatedCall => strings.limitRepeatedCall,
      LoopLimitReason.outputLimit => strings.limitOutput,
      null => null,
    };
    return text == null
        ? null
        : _Banner(
            icon: Icons.pause_circle_outline,
            text: text,
            actions: [
              TextButton(
                style: TextButton.styleFrom(minimumSize: size),
                onPressed: () => _send(strings.continueRun),
                child: Text(strings.continueRun),
              ),
            ],
          );
  }
}

/// Past conversations, newest first; picking one returns its id. The list
/// and each title load once per opening.
class _Conversations extends StatefulWidget {
  const _Conversations({required this.controller, required this.strings});

  final AssistantController controller;
  final AssistantStrings strings;

  @override
  State<_Conversations> createState() => _ConversationsState();
}

class _ConversationsState extends State<_Conversations> {
  late final _threads = widget.controller.threads.threads();

  // Every title once per opening, empty or failed ones too, so rows do not
  // reload while scrolling; the controller keeps found titles for good.
  final _titles = <String, Future<String?>>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = MaterialLocalizations.of(context);
    final strings = widget.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, bottom: 8),
          child: Semantics(
            header: true,
            child: Text(
              strings.conversations,
              style: theme.textTheme.titleMedium,
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder(
            future: _threads,
            builder: (context, snapshot) {
              if (snapshot.hasError) return _note(strings.errorOther);
              final threads = snapshot.data;
              if (threads == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (threads.isEmpty) return _note(strings.conversationsEmpty);
              return ListView.builder(
                itemCount: threads.length,
                itemBuilder: (context, i) {
                  final thread = threads[i];
                  final at = thread.createdAt.toLocal();
                  return ListTile(
                    selected: thread.id == widget.controller.threadId,
                    title: _ThreadTitle(
                      title: _titles.putIfAbsent(
                        thread.id,
                        () => widget.controller.threadTitle(thread),
                      ),
                      untitled: strings.conversationUntitled,
                    ),
                    subtitle: Text(
                      '${local.formatMediumDate(at)} · '
                      '${local.formatTimeOfDay(TimeOfDay.fromDateTime(at))}',
                    ),
                    onTap: () => Navigator.of(context).pop(thread.id),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _note(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

/// A thread's title once it has loaded; [untitled] when it has none.
class _ThreadTitle extends StatelessWidget {
  const _ThreadTitle({required this.title, required this.untitled});

  final Future<String?> title;
  final String untitled;

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: title,
    builder: (context, snapshot) {
      final text = snapshot.connectionState == ConnectionState.done
          ? snapshot.data ?? untitled
          : '';
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textDirection: textDirectionOf(text),
      );
    },
  );
}

/// A plain line between messages.
class _Line extends StatelessWidget {
  const _Line({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.text,
    this.isError = false,
    this.actions = const [],
  });

  final IconData icon;
  final String text;
  final bool isError;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = isError
        ? colors.onErrorContainer
        : colors.onSecondaryContainer;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: isError ? colors.errorContainer : colors.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: foreground),
                  ),
                ),
              ],
            ),
            if (actions.isNotEmpty)
              // The banner's own text color: primary on a container color
              // can be hard to read.
              TextButtonTheme(
                data: TextButtonThemeData(
                  style: TextButton.styleFrom(foregroundColor: foreground),
                ),
                child: Wrap(spacing: 4, children: actions),
              ),
          ],
        ),
      ),
    );
  }
}
