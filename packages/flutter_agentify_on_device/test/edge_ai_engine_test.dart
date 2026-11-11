import 'dart:async';

import 'package:flutter_agentify_on_device/flutter_agentify_on_device.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a failed initialize is not kept, so the next call tries again',
    () async {
      var calls = 0;
      final engine = EdgeAiEngine(
        initializer: () async {
          if (++calls == 1) throw StateError('no engine');
        },
        isInstalledFile: (_) async => true,
      );
      await expectLater(engine.isInstalled(gemma4E2b), throwsStateError);
      expect(await engine.isInstalled(gemma4E2b), isTrue);
      expect(calls, 2);
    },
  );

  test('load() throws when the model is not downloaded', () async {
    final engine = EdgeAiEngine(
      initializer: () async {},
      isInstalledFile: (_) async => false,
    );
    await expectLater(engine.load(gemma4E2b), throwsStateError);
  });

  test(
    'a cancelled download does not remove the file of a newer one',
    () async {
      final uninstalled = <String>[];
      final installs = <Completer<void>>[];
      final engine = EdgeAiEngine(
        initializer: () async {},
        uninstallFile: (file) async => uninstalled.add(file),
        install: (spec, onProgress, cancel) {
          final c = Completer<void>();
          installs.add(c);
          return c.future;
        },
      );
      final first = engine.download(gemma4E2b).listen((_) {});
      await pumpEventQueue();
      await first.cancel();
      final second = engine.download(gemma4E2b).listen((_) {});
      await pumpEventQueue();
      // The old install ends in its cancellation after the new one started.
      installs[0].completeError(StateError('cancelled'));
      await pumpEventQueue();
      expect(uninstalled, isEmpty);
      // The newest one failing still cleans up.
      final failed = second.asFuture<void>();
      installs[1].completeError(StateError('network'));
      await expectLater(failed, throwsStateError);
      expect(uninstalled, ['gemma-4-E2B-it.litertlm']);
    },
  );

  test(
    'a cancelled download with no newer one removes its partial file',
    () async {
      final uninstalled = <String>[];
      final install = Completer<void>();
      final engine = EdgeAiEngine(
        initializer: () async {},
        uninstallFile: (file) async => uninstalled.add(file),
        install: (spec, onProgress, cancel) => install.future,
      );
      final sub = engine.download(gemma4E2b).listen((_) {});
      await pumpEventQueue();
      await sub.cancel();
      install.completeError(StateError('cancelled'));
      await pumpEventQueue();
      expect(uninstalled, ['gemma-4-E2B-it.litertlm']);
    },
  );

  test(
    'a new download waits until a failed one has removed its file',
    () async {
      final events = <String>[];
      final removed = Completer<void>();
      var installs = 0;
      final engine = EdgeAiEngine(
        initializer: () async {},
        uninstallFile: (file) async {
          events.add('remove started');
          await removed.future;
          events.add('removed');
        },
        install: (spec, onProgress, cancel) async {
          events.add('install');
          if (++installs == 1) throw StateError('network');
        },
      );
      final first = engine.download(gemma4E2b).listen((_) {}, onError: (_) {});
      await pumpEventQueue();
      final second = engine.download(gemma4E2b).listen((_) {});
      await pumpEventQueue();
      expect(events, ['install', 'remove started']);
      removed.complete();
      await pumpEventQueue();
      expect(events, ['install', 'remove started', 'removed', 'install']);
      await first.cancel();
      await second.cancel();
    },
  );
}
