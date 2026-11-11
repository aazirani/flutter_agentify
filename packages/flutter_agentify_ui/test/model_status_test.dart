import 'package:flutter/material.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_agentify_ui/flutter_agentify_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

const _persian = AssistantStrings(
  onDevice: 'روی این دستگاه',
  onDeviceOfferTitle: 'اجرای دستیار روی این دستگاه',
  onDeviceOfferBody: 'دانلود مدل ({size})',
  onDeviceDownload: 'دانلود',
  onDeviceNotNow: 'حالا نه',
  onDeviceDownloading: 'در حال دانلود… {percent}٪',
  onDeviceLoading: 'در حال آماده شدن…',
);

Future<ChatFixture> _pump(
  WidgetTester tester,
  ModelStatus status, {
  AssistantStrings strings = const AssistantStrings(),
  TextDirection direction = TextDirection.ltr,
  ChatFixture? fixture,
}) async {
  final f = fixture ?? ChatFixture(const []);
  await f.controller.open();
  await tester.pumpWidget(_app(f, status, strings, direction));
  await tester.pumpAndSettle();
  return f;
}

Widget _app(
  ChatFixture f,
  ModelStatus status,
  AssistantStrings strings,
  TextDirection direction,
) => MaterialApp(
  home: Directionality(
    textDirection: direction,
    child: Scaffold(
      body: AssistantChat(
        controller: f.controller,
        strings: strings,
        modelStatus: status,
      ),
    ),
  ),
);

void main() {
  testWidgets('the offer names the size; Download and Not now call back', (
    tester,
  ) async {
    final calls = <String>[];
    await _pump(
      tester,
      ModelStatus(
        answeredBy: AnsweredBy.server,
        serverLabel: 'Ollama',
        deviceLabel: 'Gemma 4 E2B',
        state: const ModelNotDownloaded(),
        sizeBytes: 2588147712,
        onDownload: () => calls.add('download'),
        onNotNow: () => calls.add('not now'),
      ),
    );
    expect(find.text('Run the assistant on this device'), findsOneWidget);
    expect(find.textContaining('Download Gemma 4 E2B ('), findsOneWidget);
    expect(find.textContaining('2.6 GB'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Run the assistant on this device')),
      findsWidgets,
    );
    await tester.tap(find.text('Download'));
    await tester.tap(find.text('Not now'));
    expect(calls, ['download', 'not now']);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('without a model to answer, the state replaces the input', (
    tester,
  ) async {
    await _pump(
      tester,
      ModelStatus(
        answeredBy: AnsweredBy.none,
        state: const ModelNotDownloaded(),
        sizeBytes: 100,
        onDownload: () {},
      ),
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Not now'), findsNothing);
  });

  testWidgets('a dismissed offer is gone and Download is in the menu', (
    tester,
  ) async {
    var downloads = 0;
    await _pump(
      tester,
      ModelStatus(
        answeredBy: AnsweredBy.server,
        state: const ModelNotDownloaded(),
        sizeBytes: 100,
        offerDismissed: true,
        onDownload: () => downloads++,
      ),
    );
    expect(find.text('Run the assistant on this device'), findsNothing);
    await tester.tap(find.byTooltip('Model on this device'));
    await tester.pumpAndSettle();
    // The menu names the size before a large download.
    await tester.tap(find.textContaining('Download (\u20661 MB\u2069)'));
    await tester.pumpAndSettle();
    expect(downloads, 1);
  });

  testWidgets('downloading shows how much arrived and Cancel', (tester) async {
    var cancels = 0;
    await _pump(
      tester,
      ModelStatus(
        answeredBy: AnsweredBy.server,
        state: const ModelDownloading(958000000, 2588147712),
        onCancel: () => cancels++,
      ),
    );
    expect(
      find.text('Downloading… \u2066958 MB\u2069 of \u20662.6 GB\u2069'),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    expect(cancels, 1);
  });

  testWidgets('loading says it is getting ready', (tester) async {
    final f = ChatFixture(const []);
    await f.controller.open();
    await tester.pumpWidget(
      _app(
        f,
        const ModelStatus(answeredBy: AnsweredBy.none, state: ModelLoading()),
        const AssistantStrings(),
        TextDirection.ltr,
      ),
    );
    await tester.pump();
    expect(find.text('Getting ready…'), findsOneWidget);
  });

  testWidgets('unsupported and memory states explain themselves', (
    tester,
  ) async {
    await _pump(
      tester,
      const ModelStatus(
        answeredBy: AnsweredBy.none,
        state: ModelUnsupported(UnsupportedReason.platform),
      ),
    );
    expect(
      find.text('This device cannot run the on-device assistant.'),
      findsOneWidget,
    );
    await _pump(
      tester,
      const ModelStatus(
        answeredBy: AnsweredBy.none,
        state: ModelUnsupported(UnsupportedReason.notEnoughMemory),
      ),
    );
    expect(find.text('Not enough memory on this device.'), findsOneWidget);
    expect(find.text('Open settings'), findsNothing);
  });

  testWidgets('with no model, the chat says it is not ready and points to '
      'the server settings', (tester) async {
    var opened = 0;
    await _pump(
      tester,
      ModelStatus(
        answeredBy: AnsweredBy.none,
        state: const ModelUnsupported(UnsupportedReason.notEnoughMemory),
        onOpenSettings: () => opened++,
      ),
    );
    expect(find.text('Not ready yet'), findsOneWidget);
    expect(find.text('How can I help?'), findsNothing);
    await tester.tap(find.text('Open settings'));
    expect(opened, 1);
  });

  testWidgets('a failed download offers Retry only', (tester) async {
    await _pump(
      tester,
      ModelStatus(
        answeredBy: AnsweredBy.none,
        state: const ModelFailed(OnDeviceFailure.download),
        onRetry: () {},
        onDelete: () {},
      ),
    );
    expect(find.textContaining('The download failed.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    // Nothing is on disk to delete.
    expect(find.text('Delete model'), findsNothing);
  });

  testWidgets('a model that failed to start offers Retry and Delete model', (
    tester,
  ) async {
    final calls = <String>[];
    for (final (kind, text) in [
      (OnDeviceFailure.memory, 'The model did not fit in memory last time.'),
      (OnDeviceFailure.load, 'The model on this device could not start.'),
    ]) {
      await _pump(
        tester,
        ModelStatus(
          answeredBy: AnsweredBy.none,
          state: ModelFailed(kind),
          onRetry: () => calls.add('retry'),
          onDelete: () => calls.add('delete'),
        ),
      );
      expect(find.text(text), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.tap(find.text('Delete model'));
    }
    expect(calls, hasLength(4));
  });

  testWidgets('the header names who answers and which model', (tester) async {
    await _pump(
      tester,
      ModelStatus(
        answeredBy: AnsweredBy.device,
        state: ModelReady(ScriptedProvider(const [])),
      ),
    );
    expect(find.text('On this device'), findsOneWidget);
    await _pump(
      tester,
      ModelStatus(
        answeredBy: AnsweredBy.device,
        deviceLabel: 'Gemma 4 E2B',
        state: ModelReady(ScriptedProvider(const [])),
      ),
    );
    expect(find.text('Gemma 4 E2B · On this device'), findsOneWidget);
    await _pump(
      tester,
      const ModelStatus(answeredBy: AnsweredBy.server, serverLabel: 'Ollama'),
    );
    expect(find.text('Ollama'), findsOneWidget);
    expect(find.text('On this device'), findsNothing);
    await _pump(
      tester,
      const ModelStatus(
        answeredBy: AnsweredBy.server,
        serverLabel: 'Ollama',
        serverModel: 'llama3.2',
      ),
    );
    expect(find.text('Ollama · llama3.2'), findsOneWidget);
  });

  testWidgets('the menu switches between the device and the server', (
    tester,
  ) async {
    final chosen = <bool>[];
    final ready = ModelReady(ScriptedProvider(const []));
    await _pump(
      tester,
      ModelStatus(
        answeredBy: AnsweredBy.device,
        serverLabel: 'Ollama',
        state: ready,
        onUseDevice: chosen.add,
      ),
    );
    await tester.tap(find.byTooltip('Model on this device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Answer with Ollama'));
    await tester.pumpAndSettle();
    await _pump(
      tester,
      ModelStatus(
        answeredBy: AnsweredBy.server,
        serverLabel: 'Ollama',
        state: ready,
        usesDevice: false,
        onUseDevice: chosen.add,
      ),
    );
    await tester.tap(find.byTooltip('Model on this device'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Answer on this device'));
    await tester.pumpAndSettle();
    expect(chosen, [false, true]);
  });

  testWidgets('Persian texts read right to left', (tester) async {
    await _pump(
      tester,
      ModelStatus(
        answeredBy: AnsweredBy.server,
        state: const ModelNotDownloaded(),
        sizeBytes: 2588147712,
        onDownload: () {},
        onNotNow: () {},
      ),
      strings: _persian,
      direction: TextDirection.rtl,
    );
    expect(find.text('اجرای دستیار روی این دستگاه'), findsOneWidget);
    expect(find.text('حالا نه'), findsOneWidget);
    final title = find.text('اجرای دستیار روی این دستگاه');
    expect(Directionality.of(tester.element(title)), TextDirection.rtl);
    await _pump(
      tester,
      const ModelStatus(
        answeredBy: AnsweredBy.server,
        state: ModelDownloading(1, 2),
      ),
      strings: _persian,
      direction: TextDirection.rtl,
    );
    expect(find.text('در حال دانلود… 50٪'), findsOneWidget);
  });

  testWidgets('the leave card names the server and its buttons resolve it', (
    tester,
  ) async {
    final threads = InMemoryThreadStore();
    final thread = await threads.createThread();
    await threads.append(thread.id, StoredMessage(UserMessage('Hi')));
    await threads.setUnshared(thread.id, true);
    final f = ChatFixture([ScriptedStep.text('Ok.')], threads: threads);
    await _pump(
      tester,
      const ModelStatus(answeredBy: AnsweredBy.server, serverLabel: 'Ollama'),
      fixture: f,
    );
    await tester.enterText(find.byType(TextField), 'Next');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This conversation was answered on this device. Continue with '
        'Ollama? The whole conversation will be sent to it.',
      ),
      findsOneWidget,
    );
    expect(f.provider.requests, isEmpty);
    await tester.tap(find.text('Continue with Ollama'));
    await tester.pumpAndSettle();
    expect(f.provider.requests, hasLength(1));
    expect(find.text('Start a new chat'), findsNothing);
  });

  testWidgets(
    'server -> device adds the line "Now answered on this device" once',
    (tester) async {
      final f = ChatFixture([ScriptedStep.text('Ok.')]);
      await _pump(
        tester,
        const ModelStatus(answeredBy: AnsweredBy.server, serverLabel: 'Ollama'),
        fixture: f,
      );
      await f.controller.send('Hi');
      await tester.pumpAndSettle();
      const device = ModelStatus(answeredBy: AnsweredBy.device);
      await tester.pumpWidget(
        _app(f, device, const AssistantStrings(), TextDirection.ltr),
      );
      await tester.pumpAndSettle();
      expect(find.text('Now answered on this device'), findsOneWidget);
      await tester.pumpWidget(
        _app(f, device, const AssistantStrings(), TextDirection.ltr),
      );
      await tester.pumpAndSettle();
      expect(find.text('Now answered on this device'), findsOneWidget);
    },
  );

  testWidgets('without a server name the leave card says the model server', (
    tester,
  ) async {
    final threads = InMemoryThreadStore();
    final thread = await threads.createThread();
    await threads.append(thread.id, StoredMessage(UserMessage('Hi')));
    await threads.setUnshared(thread.id, true);
    final f = ChatFixture(const [], threads: threads);
    await _pump(
      tester,
      const ModelStatus(answeredBy: AnsweredBy.server),
      fixture: f,
    );
    await tester.enterText(find.byType(TextField), 'Next');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Continue with the model server'), findsOneWidget);
    expect(find.textContaining('Continue with ?'), findsNothing);
  });
}
