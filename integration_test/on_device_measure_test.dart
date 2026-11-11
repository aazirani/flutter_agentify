// Measures the in-app model against the app's real actions on one device:
// ten fixed requests in one conversation, each checked against what it must
// change. Run it through tool/measure_on_device.sh, which prints the row.
//
//   flutter test integration_test/on_device_measure_test.dart -d macos
//   --dart-define=BACKEND=cpu runs on the processor instead of the GPU.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_agentify/domain/entities/app_theme_mode.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_on_device/flutter_agentify_on_device.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/actions_harness.dart';

const _backend = String.fromEnvironment('BACKEND', defaultValue: 'gpu');

/// Times each model request: how long to its first event, and whether it
/// carried a tool result.
class _Timed implements LlmProvider {
  _Timed(this._inner);

  final LlmProvider _inner;
  final firstMs = <({bool toolStep, int ms})>[];

  @override
  Stream<LlmEvent> stream({
    required String system,
    required List<ChatMessage> messages,
    List<ToolSpec> tools = const [],
    required ModelConfig config,
    CancelToken? cancel,
  }) async* {
    final watch = Stopwatch()..start();
    var first = true;
    await for (final event in _inner.stream(
      system: system,
      messages: messages,
      tools: tools,
      config: config,
      cancel: cancel,
    )) {
      if (first) {
        first = false;
        firstMs.add((
          toolStep: messages.last is ToolResultMessage,
          ms: watch.elapsedMilliseconds,
        ));
      }
      yield event;
    }
  }

  @override
  void close() => _inner.close();
}

typedef _Check = Future<bool> Function(ActionsHarness h, String reply);

Future<bool> _hasTitle(ActionsHarness h, String title) async =>
    (await h.items.getItems()).any((i) => i.title == title);

/// The ten fixed requests, in one conversation, and what each must cause.
/// Keep them as they are, so rows from different devices compare.
final _requests = <(String, _Check)>[
  ('Add an item called Buy milk', (h, _) => _hasTitle(h, 'Buy milk')),
  (
    'Add two more items: Eggs and Bread',
    (h, _) async => await _hasTitle(h, 'Eggs') && await _hasTitle(h, 'Bread'),
  ),
  (
    'What items do I have?',
    (h, r) async => r.contains('Eggs') && r.contains('Bread'),
  ),
  (
    'Rename Buy milk to Buy oat milk',
    (h, _) async =>
        await _hasTitle(h, 'Buy oat milk') && !await _hasTitle(h, 'Buy milk'),
  ),
  ('Delete the Bread item', (h, _) async => !await _hasTitle(h, 'Bread')),
  (
    'Switch the app to dark mode',
    (h, _) async => h.settings.getThemeMode() == AppThemeMode.dark,
  ),
  (
    'Change the language to Persian',
    (h, _) async => h.settings.getLocale() == 'fa',
  ),
  (
    'How many items are on my list now?',
    (h, r) async => r.contains('2') || r.toLowerCase().contains('two'),
  ),
  (
    'Add a description to Eggs: a dozen, free range',
    (h, _) async => (await h.items.getItems()).any(
      (i) =>
          i.title == 'Eggs' &&
          (i.description ?? '').toLowerCase().contains('dozen'),
    ),
  ),
  (
    'Thanks, that is all.',
    (h, r) async =>
        r.trim().isNotEmpty && (await h.items.getItems()).length == 2,
  ),
];

int _median(Iterable<int> values) {
  final sorted = values.toList()..sort();
  return sorted.isEmpty ? 0 : sorted[sorted.length ~/ 2];
}

String _seconds(int ms) => '${(ms / 1000).toStringAsFixed(2)} s';

void _say(String line) {
  // The script reads these lines from the test's output.
  // ignore: avoid_print
  print(line);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ten requests on the model inside the app', (tester) async {
    final engine = EdgeAiEngine(useGpu: _backend != 'cpu');
    final support = await engine.support(gemma4E2b);
    if (support.unsupported case final reason?) {
      _say('MEASURE CANNOT RUN ${reason.name}');
      return;
    }
    if (!await engine.isInstalled(gemma4E2b)) {
      var last = -1;
      await for (final (received, total) in engine.download(gemma4E2b)) {
        final percent = total == 0 ? 0 : received * 100 ~/ total;
        if (percent ~/ 10 != last) {
          last = percent ~/ 10;
          _say('MEASURE download $percent%');
        }
      }
    }
    final provider = _Timed(await engine.load(gemma4E2b));
    addTearDown(engine.unload);
    final h = ActionsHarness();
    final threads = InMemoryThreadStore();
    final session = AgentSession(
      registry: h.registry,
      appContext: AppContext(screens: const {}),
      provider: provider,
      model: gemma4E2b.config,
      threads: threads,
      memories: InMemoryMemoryStore(),
      appInstructions: await rootBundle.loadString(
        'assets/assistant/instructions.md',
      ),
      approvals: h.approvals,
    );
    final thread = await threads.createThread();
    var correct = 0;
    for (final (i, (text, check)) in _requests.indexed) {
      final reply = StringBuffer();
      await for (final e in session.send(thread.id, text)) {
        switch (e) {
          case TextDelta(:final text):
            reply.write(text);
          case ApprovalRequired(:final callId):
            session.resolveApproval(callId, const Approve());
          default:
            break;
        }
      }
      final ok = await check(h, reply.toString());
      if (ok) correct++;
      _say('MEASURE ${i + 1} ${ok ? 'OK' : 'WRONG'} ${jsonEncode(text)}');
    }
    final times = provider.firstMs;
    final user = _median([
      for (final t in times)
        if (!t.toolStep) t.ms,
    ]);
    final tool = _median([
      for (final t in times)
        if (t.toolStep) t.ms,
    ]);
    final worst = times.fold(0, (a, t) => t.ms > a ? t.ms : a);
    final peak = (ProcessInfo.maxRss / (1 << 30)).toStringAsFixed(1);
    // OS | backend | correct | first token median | worst | peak memory
    _say(
      'MEASURE ROW ${Platform.operatingSystem} '
      '${Platform.operatingSystemVersion}|$_backend|$correct/10|'
      '${_seconds(user)} / ${_seconds(tool)}|${_seconds(worst)}|$peak GB',
    );
  }, timeout: Timeout.none);
}
