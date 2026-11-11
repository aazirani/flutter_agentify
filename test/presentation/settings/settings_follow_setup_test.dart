// @on-device:begin
import 'dart:async';

// @on-device:end
import 'package:flutter/material.dart';
import 'package:flutter_agentify/data/repositories/in_memory_settings_repository.dart';
import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/domain/entities/assistant_settings.dart';
// @on-device:begin
import 'package:flutter_agentify/domain/repositories/settings_repository.dart';
// @on-device:end
import 'package:flutter_agentify/presentation/providers/assistant_settings_provider.dart';
import 'package:flutter_agentify/presentation/settings/assistant_settings_section.dart';
import 'package:flutter_agentify/presentation/settings/settings_screen.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
// @on-device:begin
import 'package:flutter_agentify_core/testing.dart';
// @on-device:end
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// @on-device:begin
import '../../support/on_device_fixture.dart';
// @on-device:end
import '../../support/test_app.dart';

const _locked = ServerSetup(
  presetId: 'custom',
  baseUrl: 'https://proxy.example.com/v1',
  model: 'house-model',
  userEditable: false,
);

/// Saved settings that name another server than the setup file.
Future<InMemorySettingsRepository> _saved() async {
  final settings = InMemorySettingsRepository();
  await settings.setAssistantSettings(
    const AssistantSettings(presetId: 'ollama', model: 'saved-model'),
  );
  return settings;
}

/// Shows the Settings screen over [container], tall enough that every tile
/// is on screen.
Future<void> _show(WidgetTester tester, ProviderContainer container) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpTestAppWith(
    tester,
    locale: english,
    container,
    const SettingsScreen(),
  );
}

/// The Settings screen under [setup], over saved settings.
Future<ProviderContainer> _pump(
  WidgetTester tester,
  AssistantSetup setup,
) async {
  final container = setUpTestServices(settings: await _saved(), setup: setup);
  await _show(tester, container);
  return container;
}

void main() {
  testWidgets('a locked server: no server section and no server actions', (
    tester,
  ) async {
    final container = await _pump(
      tester,
      const AssistantSetup(mode: ModelMode.server, server: _locked),
    );
    expect(find.byType(AssistantSettingsSection), findsNothing);
    final registry = ServiceLocator.getIt<ActionRegistry>();
    for (final name in ['set_assistant_provider', 'set_api_key']) {
      expect(registry.find(name), isNull, reason: name);
    }
    // Saved settings are ignored; the setup's values are final.
    final used = container.read(assistantSettingsProvider);
    expect(used.presetId, 'custom');
    expect(used.baseUrl, 'https://proxy.example.com/v1');
    expect(used.model, 'house-model');
  });

  testWidgets('an editable server keeps its section and its actions', (
    tester,
  ) async {
    final container = await _pump(
      tester,
      const AssistantSetup(mode: ModelMode.server),
    );
    expect(find.byType(AssistantSettingsSection), findsOneWidget);
    expect(
      ServiceLocator.getIt<ActionRegistry>().all.map((a) => a.name),
      containsAll(['set_assistant_provider', 'set_api_key']),
    );
    expect(container.read(assistantSettingsProvider).model, 'saved-model');
  });

  testWidgets('server mode shows nothing about the in-app model', (
    tester,
  ) async {
    await _pump(tester, const AssistantSetup(mode: ModelMode.server));
    expect(find.text('Model on this device'), findsNothing);
    expect(find.text('Delete model'), findsNothing);
  });

  // @on-device:begin
  testWidgets(
    'with the in-app model, Settings shows its state and its buttons',
    (tester) async {
      final gate = Completer<void>();
      final engine = FakeOnDeviceEngine()..downloadGate = gate;
      await _show(
        tester,
        setUpTestServices(
          settings: await _saved(),
          setup: const AssistantSetup(
            mode: ModelMode.both,
            onDevice: OnDeviceSetup(model: testModelSpec),
          ),
          onDeviceEngine: engine,
        ),
      );
      expect(find.text('Model on this device'), findsOneWidget);
      // The model's name and size, then its state.
      expect(find.text('Test model'), findsOneWidget);
      expect(find.text('\u20661 MB\u2069 · Not downloaded'), findsOneWidget);

      // Download asks first, naming the model.
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      expect(find.text('Download Test model?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(engine.downloadCalls, 0);

      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Downloading…'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Not downloaded'), findsOneWidget);
      expect(engine.downloadCancelled, isTrue);

      engine.downloadGate = null;
      await tester.tap(find.text('Download'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Download').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Ready'), findsOneWidget);
      await tester.tap(find.text('Delete model'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Test model?'), findsOneWidget);
      await tester.tap(find.text('Delete model').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Not downloaded'), findsOneWidget);
      expect(engine.installed, isFalse);
    },
  );

  testWidgets('a failed download offers Retry, not Delete', (tester) async {
    final engine = FakeOnDeviceEngine()..downloadError = Exception('offline');
    await _show(
      tester,
      setUpTestServices(
        setup: const AssistantSetup(
          mode: ModelMode.onDevice,
          onDevice: OnDeviceSetup(model: testModelSpec),
        ),
        onDeviceEngine: engine,
      ),
    );
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('The download failed.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Delete model'), findsNothing);
  });

  Finder segment(String text) => find.descendant(
    of: find.byType(SegmentedButton<bool>),
    matching: find.text(text),
  );

  testWidgets('both: "Answers with" chooses the device or the server', (
    tester,
  ) async {
    await _show(
      tester,
      setUpTestServices(
        settings: await _saved(),
        setup: const AssistantSetup(
          mode: ModelMode.both,
          onDevice: OnDeviceSetup(model: testModelSpec),
        ),
        onDeviceEngine: FakeOnDeviceEngine(),
      ),
    );
    final settings = ServiceLocator.getIt<SettingsRepository>();
    expect(find.text('Answers with'), findsOneWidget);
    expect(settings.getUseOnDeviceModel(), isTrue);
    await tester.tap(segment('Model server'));
    await tester.pumpAndSettle();
    expect(settings.getUseOnDeviceModel(), isFalse);
    expect(
      tester
          .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
          .selected,
      {false},
    );
    expect(
      find.text('The model server answers every message.'),
      findsOneWidget,
    );
  });

  testWidgets('both without a server: the choice is off limits', (
    tester,
  ) async {
    await _show(
      tester,
      setUpTestServices(
        setup: const AssistantSetup(
          mode: ModelMode.both,
          onDevice: OnDeviceSetup(model: testModelSpec),
        ),
        onDeviceEngine: FakeOnDeviceEngine(),
      ),
    );
    expect(
      find.text('Set up a model server to choose between them.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
          .onSelectionChanged,
      isNull,
    );
  });

  testWidgets('both on a device that cannot run the model: no choice', (
    tester,
  ) async {
    await _show(
      tester,
      setUpTestServices(
        settings: await _saved(),
        setup: const AssistantSetup(
          mode: ModelMode.both,
          onDevice: OnDeviceSetup(model: testModelSpec),
        ),
        onDeviceEngine: FakeOnDeviceEngine()
          ..deviceSupport = const DeviceSupport(
            unsupported: UnsupportedReason.platform,
          ),
      ),
    );
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    expect(
      find.text('This device cannot run the on-device assistant.'),
      findsOneWidget,
    );
  });

  testWidgets('both where the app leaves the model off on the web: '
      'nothing about it', (tester) async {
    await _show(
      tester,
      setUpTestServices(
        settings: await _saved(),
        setup: const AssistantSetup(
          mode: ModelMode.both,
          onDevice: OnDeviceSetup(model: testModelSpec),
        ),
        onDeviceEngine: FakeOnDeviceEngine()
          ..deviceSupport = const DeviceSupport(
            unsupported: UnsupportedReason.webDisabled,
          ),
      ),
    );
    expect(find.text('Model on this device'), findsNothing);
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    expect(find.byType(AssistantSettingsSection), findsOneWidget);
  });

  testWidgets('onDevice mode shows no choice and no server', (tester) async {
    await _show(
      tester,
      setUpTestServices(
        setup: const AssistantSetup(
          mode: ModelMode.onDevice,
          onDevice: OnDeviceSetup(model: testModelSpec),
        ),
        onDeviceEngine: FakeOnDeviceEngine(),
      ),
    );
    expect(find.text('Model on this device'), findsOneWidget);
    expect(find.byType(SegmentedButton<bool>), findsNothing);
    // No server answers in this mode: nothing to set up, nothing to call.
    expect(find.byType(AssistantSettingsSection), findsNothing);
    final registry = ServiceLocator.getIt<ActionRegistry>();
    for (final name in ['set_assistant_provider', 'set_api_key']) {
      expect(registry.find(name), isNull, reason: name);
    }
  });
  // @on-device:end
}
