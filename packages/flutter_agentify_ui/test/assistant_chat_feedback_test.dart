import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_agentify_ui/flutter_agentify_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

const _strings = AssistantStrings();

Future<void> _pump(
  WidgetTester tester,
  ChatFixture f, {
  AssistantStrings strings = _strings,
  VoidCallback? onOpenSettings,
  VoidCallback? onClose,
  ThemeData? theme,
  TextDirection direction = TextDirection.ltr,
}) async {
  await f.controller.open();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: AssistantChat(
            controller: f.controller,
            strings: strings,
            onOpenSettings: onOpenSettings,
            onClose: onClose,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Types [text] and taps Send; frames run, but nothing waits to settle (the
/// thinking dots never settle).
Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.byTooltip(_strings.send));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

final _thinking = find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == _strings.thinking,
);

Finder _liveRegionAbove(Finder child) => find.ancestor(
  of: child,
  matching: find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.liveRegion == true,
  ),
);

void main() {
  group('thinking indicator', () {
    testWidgets('shows after send while the model is silent, and goes on '
        'stop', (tester) async {
      final f = ChatFixture([ScriptedStep.hang()]);
      await _pump(tester, f);
      await _send(tester, 'Hi');
      expect(_thinking, findsOneWidget);
      await tester.tap(find.byTooltip(_strings.stop));
      await tester.pumpAndSettle();
      expect(_thinking, findsNothing);
      expect(find.text(_strings.cancelled), findsOneWidget);
    });

    testWidgets('shows again after a tool finishes', (tester) async {
      final f = ChatFixture([
        ScriptedStep.toolCalls([call('c1', 'echo', '{"text":"a"}')]),
        ScriptedStep.hang(),
      ]);
      await _pump(tester, f);
      await _send(tester, 'Go');
      expect(find.text('Echo'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(_thinking, findsOneWidget);
      f.controller.stop();
      await tester.pumpAndSettle();
      expect(_thinking, findsNothing);
    });

    testWidgets('is gone once the reply arrives, and while an approval '
        'waits', (tester) async {
      final f = ChatFixture([
        ScriptedStep.toolCalls([
          call('c1', 'wipe', '{"folder":"a"}'),
        ], text: 'Checking.'),
        ScriptedStep.text('Done.'),
      ]);
      await _pump(tester, f);
      await _send(tester, 'Go');
      expect(find.text('Checking.'), findsOneWidget);
      expect(find.text(_strings.needsApprovalTitle), findsOneWidget);
      expect(_thinking, findsNothing);
      await tester.tap(find.text(_strings.approve));
      await tester.pumpAndSettle();
      expect(find.text('Checking.\n\nDone.'), findsOneWidget);
      expect(_thinking, findsNothing);
    });

    testWidgets('is gone after an error', (tester) async {
      final f = ChatFixture([
        ScriptedStep.error(const LlmError('Bad key', status: 401)),
      ]);
      await _pump(tester, f);
      await _send(tester, 'Hi');
      await tester.pumpAndSettle();
      expect(_thinking, findsNothing);
    });
  });

  group('errors', () {
    testWidgets('a refused key says so, offers settings and no retry', (
      tester,
    ) async {
      var opened = 0;
      final f = ChatFixture([
        ScriptedStep.error(const LlmError('invalid x-api-key', status: 401)),
      ]);
      await _pump(tester, f, onOpenSettings: () => opened++);
      await _send(tester, 'Hi');
      await tester.pumpAndSettle();
      expect(find.text(_strings.errorAuth), findsOneWidget);
      expect(find.textContaining('x-api-key'), findsNothing);
      expect(find.text(_strings.retry), findsNothing);
      await tester.tap(find.text(_strings.openSettings));
      expect(opened, 1);
    });

    testWidgets('an unknown model offers settings', (tester) async {
      final f = ChatFixture([
        ScriptedStep.error(const LlmError('model "x" not found', status: 404)),
      ]);
      await _pump(tester, f, onOpenSettings: () {});
      await _send(tester, 'Hi');
      await tester.pumpAndSettle();
      expect(find.text(_strings.errorNotFound), findsOneWidget);
      expect(find.text(_strings.openSettings), findsOneWidget);
    });

    testWidgets('a server that cannot be reached offers settings and retry', (
      tester,
    ) async {
      final f = ChatFixture([
        ScriptedStep.error(
          const LlmError(
            'The connection failed: SocketException: Connection refused',
            kind: LlmErrorKind.connection,
            retryable: true,
          ),
        ),
      ], config: const AgentConfig(maxRetries: 0));
      await _pump(tester, f, onOpenSettings: () {});
      await _send(tester, 'Hi');
      await tester.pumpAndSettle();
      expect(find.text(_strings.errorConnection), findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
      expect(find.text(_strings.openSettings), findsOneWidget);
      expect(find.text(_strings.retry), findsOneWidget);
      // Buttons use the banner's text color, readable on its background.
      final colors = Theme.of(tester.element(find.text(_strings.retry)))
          .colorScheme;
      final retry = tester.widget<RichText>(
        find.descendant(
          of: find.widgetWithText(TextButton, _strings.retry),
          matching: find.byType(RichText),
        ),
      );
      expect(retry.text.style?.color, colors.onErrorContainer);
    });

    testWidgets('a long HTML error body fits at 320 x 480', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final f = ChatFixture([
        ScriptedStep.error(LlmError('<html>${'x' * 5000}</html>', status: 404)),
      ]);
      await _pump(tester, f, onOpenSettings: () {});
      await _send(tester, 'Hi');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('<html>'), findsNothing);
    });

    testWidgets('the error banner is a live region', (tester) async {
      final f = ChatFixture([
        ScriptedStep.error(const LlmError('No', status: 401)),
      ]);
      await _pump(tester, f);
      await _send(tester, 'Hi');
      await tester.pumpAndSettle();
      expect(_liveRegionAbove(find.text(_strings.errorAuth)), findsWidgets);
    });
  });

  group('composer', () {
    testWidgets('keeps focus after sending with the keyboard action', (
      tester,
    ) async {
      final f = ChatFixture([ScriptedStep.text('ok')]);
      await _pump(tester, f);
      await tester.showKeyboard(find.byType(TextField));
      tester.testTextInput.enterText('Hi');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(find.text('ok'), findsOneWidget);
      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(TextField),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.focusNode.hasFocus, isTrue);
    });

    testWidgets('on desktop Enter sends and Shift+Enter does not', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        final f = ChatFixture([ScriptedStep.text('ok')]);
        await _pump(tester, f);
        await tester.showKeyboard(find.byType(TextField));
        tester.testTextInput.enterText('Hi');
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(f.provider.requests, isEmpty);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('ok'), findsOneWidget);
        final field = tester.widget<EditableText>(
          find.descendant(
            of: find.byType(TextField),
            matching: find.byType(EditableText),
          ),
        );
        expect(field.focusNode.hasFocus, isTrue);
        expect(field.textInputAction, TextInputAction.newline);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('tools, approvals and receipts', () {
    testWidgets('a rejected tool reads Declined, not Failed', (tester) async {
      final f = ChatFixture([
        ScriptedStep.toolCalls([call('c1', 'wipe', '{"folder":"d"}')]),
        ScriptedStep.text('ok'),
      ]);
      await _pump(tester, f);
      await _send(tester, 'wipe');
      await tester.tap(find.text(_strings.reject));
      await tester.pumpAndSettle();
      expect(find.text('Wipe'), findsOneWidget);
      expect(find.text(' · Declined'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('action labels replace action names', (tester) async {
      final f = ChatFixture([
        ScriptedStep.toolCalls([call('c1', 'wipe', '{"folder":"d"}')]),
        ScriptedStep.text('ok'),
      ]);
      await _pump(
        tester,
        f,
        strings: AssistantStrings(
          actionLabels: (a) => a == 'wipe' ? 'Empty a folder' : null,
        ),
      );
      await _send(tester, 'Clean up');
      expect(find.text('Empty a folder'), findsOneWidget);
      expect(find.text('wipe'), findsNothing);
      await tester.tap(find.text(_strings.approve));
      await tester.pumpAndSettle();
      expect(find.text('Empty a folder'), findsOneWidget);
    });

    testWidgets('tool_search rows are hidden', (tester) async {
      final f = ChatFixture([
        ScriptedStep.toolCalls([call('c1', 'tool_search', '{"query":"echo"}')]),
        ScriptedStep.text('ok'),
      ], config: const AgentConfig(forceToolSearch: true));
      await _pump(tester, f);
      await _send(tester, 'find');
      await tester.pumpAndSettle();
      expect(find.text('ok'), findsOneWidget);
      expect(find.textContaining('Tool search'), findsNothing);
      expect(find.textContaining('tool_search'), findsNothing);
    });

    testWidgets('an unconfirmed receipt shows a question mark', (tester) async {
      final f = ChatFixture([
        ScriptedStep.toolCalls([call('c1', 'wipe', '{"folder":"d"}')]),
        ScriptedStep.text('ok'),
      ]);
      await _pump(tester, f);
      await _send(tester, 'wipe');
      await tester.tap(find.text(_strings.approve));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
      expect(find.byTooltip(_strings.receiptUnverified), findsOneWidget);
    });

    testWidgets('the approval card is a live region with one row of buttons '
        'under an app theme', (tester) async {
      // The test font draws each letter 1 em wide: wider than a real font.
      tester.view.physicalSize = const Size(600, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const wide = Size(double.infinity, 48);
      final f = ChatFixture([
        ScriptedStep.toolCalls([call('c1', 'wipe', '{"folder":"d"}')]),
        ScriptedStep.text('ok'),
      ]);
      await _pump(
        tester,
        f,
        theme: ThemeData(
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(minimumSize: wide),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(minimumSize: wide),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(minimumSize: wide),
          ),
        ),
      );
      await _send(tester, 'Clean up');
      final ys = {
        for (final label in [
          _strings.approve,
          _strings.alwaysAllow,
          _strings.reject,
        ])
          tester.getCenter(find.text(label)).dy,
      };
      expect(ys, hasLength(1));
      expect(
        _liveRegionAbove(find.text(_strings.needsApprovalTitle)),
        findsWidgets,
      );
    });

    testWidgets('a destructive action colors Approve with the error colors', (
      tester,
    ) async {
      final f = ChatFixture([
        ScriptedStep.toolCalls([call('c1', 'wipe', '{"folder":"d"}')]),
        ScriptedStep.text('ok'),
      ], wipe: WipeAction(allowAlways: false));
      await _pump(tester, f);
      await _send(tester, 'wipe');
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, _strings.approve),
      );
      final colors = Theme.of(tester.element(find.text(_strings.approve)))
          .colorScheme;
      expect(button.style?.backgroundColor?.resolve({}), colors.error);
      expect(button.style?.foregroundColor?.resolve({}), colors.onError);
    });
  });

  group('layout', () {
    testWidgets('sending while scrolled up brings the newest message into '
        'view', (tester) async {
      final f = ChatFixture([ScriptedStep.text('ok')]);
      final thread = await f.threads.createThread();
      for (var i = 0; i < 30; i++) {
        await f.threads.append(thread.id, StoredMessage(UserMessage('Q$i')));
        await f.threads.append(
          thread.id,
          StoredMessage(AssistantMessage('A$i')),
        );
      }
      await _pump(tester, f);
      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.byTooltip(_strings.jumpToLatest), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Hi');
      await tester.pump();
      await tester.tap(find.byTooltip(_strings.send));
      await tester.pumpAndSettle();
      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.controller?.offset, 0);
      expect(find.byTooltip(_strings.jumpToLatest), findsNothing);
    });

    testWidgets('a new chat after scrolling up shows no jump button', (
      tester,
    ) async {
      final f = ChatFixture([
        ScriptedStep.text('ok'),
        ScriptedStep.text('ok 2'),
      ]);
      final thread = await f.threads.createThread();
      for (var i = 0; i < 30; i++) {
        await f.threads.append(thread.id, StoredMessage(UserMessage('Q$i')));
        await f.threads.append(
          thread.id,
          StoredMessage(AssistantMessage('A$i')),
        );
      }
      await _pump(tester, f);
      await tester.drag(find.byType(ListView), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.byTooltip(_strings.jumpToLatest), findsOneWidget);
      await tester.tap(find.byTooltip(_strings.newChat));
      await tester.pumpAndSettle();
      // Two messages, so the new list is built again once it has a position.
      for (final text in ['Hi', 'Again']) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump();
        await tester.tap(find.byTooltip(_strings.send));
        await tester.pumpAndSettle();
      }
      expect(find.text('ok 2'), findsOneWidget);
      expect(find.byTooltip(_strings.jumpToLatest), findsNothing);
    });

    testWidgets('right-to-left text in a left-to-right chat runs right to '
        'left', (tester) async {
      final f = ChatFixture([ScriptedStep.text('Hello')]);
      await _pump(tester, f);
      await tester.enterText(find.byType(TextField), 'سلام دنیا!');
      await tester.pump();
      await tester.tap(find.byTooltip(_strings.send));
      await tester.pumpAndSettle();
      final bubble = find.text('سلام دنیا!').last;
      expect(Directionality.of(tester.element(bubble)), TextDirection.rtl);
      expect(
        Directionality.of(tester.element(find.text('Hello'))),
        TextDirection.ltr,
      );
    });

    testWidgets('the header has a title and, when asked, a close button', (
      tester,
    ) async {
      var closed = 0;
      final f = ChatFixture([]);
      await _pump(tester, f, onClose: () => closed++);
      expect(find.text(_strings.title), findsOneWidget);
      await tester.tap(find.byTooltip(_strings.close));
      expect(closed, 1);
    });
  });

  group('review fixes', () {
    testWidgets('the dots go as soon as Stop is pressed', (tester) async {
      final f = ChatFixture([ScriptedStep.hang()]);
      await _pump(tester, f);
      await _send(tester, 'Hi');
      expect(_thinking, findsOneWidget);
      f.controller.stop();
      await tester.pump();
      expect(_thinking, findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('the end of a reply is announced in its own direction', (
      tester,
    ) async {
      final sent = <Map<Object?, Object?>>[];
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler(
        SystemChannels.accessibility,
        (message) async {
          sent.add(message as Map<Object?, Object?>);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler(SystemChannels.accessibility, null),
      );
      final f = ChatFixture([ScriptedStep.text('سلام دنیا')]);
      await _pump(tester, f);
      await _send(tester, 'Hi');
      await tester.pumpAndSettle();
      final announce = sent.lastWhere((m) => m['type'] == 'announce');
      final data = announce['data'] as Map<Object?, Object?>;
      expect(data['message'], 'سلام دنیا');
      expect(data['textDirection'], TextDirection.rtl.index);
    });

    testWidgets('an error is read once, by its live banner, not announced '
        'again', (tester) async {
      final sent = <Map<Object?, Object?>>[];
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler(
        SystemChannels.accessibility,
        (message) async {
          sent.add(message as Map<Object?, Object?>);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler(SystemChannels.accessibility, null),
      );
      final f = ChatFixture([
        ScriptedStep.error(const LlmError('No', status: 401)),
      ]);
      await _pump(tester, f);
      await _send(tester, 'Hi');
      await tester.pumpAndSettle();
      expect(find.text(_strings.errorAuth), findsOneWidget);
      expect(sent.where((m) => m['type'] == 'announce'), isEmpty);
    });

    testWidgets('numpad Enter does not send while a word is composing', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        final f = ChatFixture([ScriptedStep.text('ok')]);
        await _pump(tester, f);
        await tester.showKeyboard(find.byType(TextField));
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'Hi',
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange(start: 0, end: 2),
          ),
        );
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
        await tester.pumpAndSettle();
        expect(f.provider.requests, isEmpty);
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'Hi',
            selection: TextSelection.collapsed(offset: 2),
          ),
        );
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
        await tester.pumpAndSettle();
        expect(find.text('ok'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('English receipt text keeps its own direction in a '
        'right-to-left chat', (tester) async {
      final f = ChatFixture([
        ScriptedStep.toolCalls([call('c1', 'wipe', '{"folder":"d"}')]),
        ScriptedStep.text('ok'),
      ]);
      await _pump(tester, f, direction: TextDirection.rtl);
      await _send(tester, 'Clean up');
      await tester.tap(find.text(_strings.approve));
      await tester.pumpAndSettle();
      final chip = tester.widget<Text>(find.text('Emptied d'));
      expect(chip.textDirection, TextDirection.ltr);
      // The English fallback label keeps its own direction too, with clean
      // text (no hidden direction marks for screen readers).
      expect(
        tester.widget<Text>(find.text('Wipe')).textDirection,
        TextDirection.ltr,
      );
    });

    testWidgets('an argument line takes the direction of its value', (
      tester,
    ) async {
      final f = ChatFixture([
        ScriptedStep.toolCalls([call('c1', 'wipe', '{"folder":"پوشه ۱"}')]),
        ScriptedStep.text('ok'),
      ]);
      await _pump(tester, f, direction: TextDirection.rtl);
      await _send(tester, 'Clean up');
      expect(
        tester.widget<Text>(find.text('folder: پوشه ۱')).textDirection,
        TextDirection.rtl,
      );
      f.controller.stop();
      await tester.pumpAndSettle();
    });

    testWidgets('the title of an empty conversation is read once per opening', (
      tester,
    ) async {
      final store = _CountingStore();
      final f = ChatFixture([]);
      final controller = AssistantController(
        session: f.session,
        threads: store,
      );
      final empty = await store.createThread();
      await controller.open(threadId: empty.id);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AssistantChat(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(_strings.conversations));
      await tester.pumpAndSettle();
      expect(find.text(_strings.conversationUntitled), findsOneWidget);
      final reads = store.reads;
      // A size change rebuilds every row.
      tester.view.physicalSize = const Size(900, 700);
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();
      expect(store.reads, reads);
      expect(find.text(_strings.conversationUntitled), findsOneWidget);
    });
  });

  group('conversations', () {
    testWidgets('lists past conversations and opens one', (tester) async {
      final f = ChatFixture([ScriptedStep.text('ok')]);
      final old = await f.threads.createThread();
      await f.threads.append(old.id, StoredMessage(UserMessage('Old talk')));
      await f.threads.append(old.id, StoredMessage(AssistantMessage('Yes')));
      await f.threads.createThread();
      await _pump(tester, f);
      expect(find.text('Old talk'), findsNothing);
      await tester.tap(find.byTooltip(_strings.conversations));
      await tester.pumpAndSettle();
      expect(find.text(_strings.conversationUntitled), findsOneWidget);
      await tester.tap(find.text('Old talk'));
      await tester.pumpAndSettle();
      expect(f.controller.threadId, old.id);
      expect(find.text('Yes'), findsOneWidget);
    });

    testWidgets('New chat twice on an empty chat makes one thread', (
      tester,
    ) async {
      final f = ChatFixture([]);
      await _pump(tester, f);
      await tester.tap(find.byTooltip(_strings.newChat));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(_strings.newChat));
      await tester.pumpAndSettle();
      expect(await f.threads.threads(), hasLength(1));
    });
  });

  group('limits', () {
    testWidgets('a step limit offers Continue, which sends again', (
      tester,
    ) async {
      final f = ChatFixture([
        ScriptedStep.toolCalls([call('c1', 'echo', '{"text":"a"}')]),
        ScriptedStep.text('Finished.'),
      ], config: const AgentConfig(maxSteps: 1));
      await _pump(tester, f);
      await _send(tester, 'Go');
      await tester.pumpAndSettle();
      expect(find.text(_strings.limitMaxSteps), findsOneWidget);
      await tester.tap(find.text(_strings.continueRun));
      await tester.pumpAndSettle();
      expect(find.text('Finished.'), findsOneWidget);
      expect(
        f.provider.requests.last.messages.whereType<UserMessage>().last.text,
        _strings.continueRun,
      );
    });
  });
}

class _CountingStore extends InMemoryThreadStore {
  var reads = 0;

  @override
  Future<List<StoredMessage>> messages(String threadId) {
    reads++;
    return super.messages(threadId);
  }
}
