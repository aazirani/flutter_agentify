// Draws the screenshots in docs/images/ from the real app, with scripted
// model replies so they come out the same every time. After a UI change:
//
//   flutter test tool/docs_screenshots_test.dart --update-goldens
//
// The README's animated demo comes from the same app: tool/make_demo.sh.
//
// The template only: setup removes this file with docs/.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_agentify/data/repositories/in_memory_settings_repository.dart';
import 'package:flutter_agentify/domain/entities/app_theme_mode.dart';
import 'package:flutter_agentify/domain/entities/assistant_settings.dart';
import 'package:flutter_agentify/domain/entities/item.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/fakes.dart';
import '../test/support/test_app.dart';

/// Tests draw text with a placeholder font; these are the real ones.
Future<void> _loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '';
  final material = '$flutterRoot/bin/cache/artifacts/material_fonts';
  for (final (family, path) in [
    ('MaterialIcons', '$material/MaterialIcons-Regular.otf'),
    ('Roboto', '$material/Roboto-Regular.ttf'),
    ('Inter', 'assets/fonts/Inter[opsz,wght].ttf'),
    ('Vazirmatn', 'assets/fonts/Vazirmatn[wght].ttf'),
  ]) {
    final bytes = File(path).readAsBytesSync();
    await (FontLoader(
      family,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

final _day = DateTime(2026, 11, 10, 9);

List<Item> _items(List<String> titles) => [
  for (final (i, title) in titles.indexed)
    Item(
      id: 'seed_$i',
      title: title,
      createdAt: _day.subtract(Duration(minutes: i)),
    ),
];

const _seed = ['Renew passport', 'Call the dentist', 'Book flights to Lisbon'];

ToolCall _call(String id, String name, Map<String, Object?> input) =>
    ToolCall(id: id, name: name, rawArguments: jsonEncode(input));

/// The app at [size] logical pixels, drawn at [pixelRatio], talking to
/// [replies], with the assistant open.
Future<void> _app(
  WidgetTester tester, {
  required List<ScriptedStep> replies,
  Size size = const Size(1280, 800),
  double pixelRatio = 1.25,
  Locale locale = english,
  bool dark = false,
  List<String> items = _seed,
}) async {
  final settings = InMemorySettingsRepository();
  await settings.setAssistantSettings(
    const AssistantSettings(model: 'llama3.2'),
  );
  if (dark) await settings.setThemeMode(AppThemeMode.dark);
  await pumpFullApp(
    tester,
    provider: ScriptedProvider(replies),
    settings: settings,
    locale: locale,
    size: size,
    items: FakeItemsRepository(_items(items)),
  );
  tester.view.devicePixelRatio = pixelRatio;
  tester.view.physicalSize = size * pixelRatio;
  await openAssistant(tester);
}

/// Sends [text] and waits for the reply, or [frames] frames while a reply
/// still runs.
Future<void> _send(WidgetTester tester, String text, {int? frames}) async {
  await tester.enterText(find.byType(TextField).last, text);
  await tester.pump();
  await tester.testTextInput.receiveAction(TextInputAction.send);
  if (frames == null) {
    await tester.pumpAndSettle();
  } else {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

Future<void> _save(Finder finder, String name) =>
    expectLater(finder, matchesGoldenFile('../docs/images/$name.png'));

final _window = find.byType(MaterialApp).first;

/// Frames for the demo, written only when tool/make_demo.sh asks for them.
class _Frames {
  _Frames(this.dir);

  final Directory dir;
  final _list = StringBuffer();
  var _count = 0;

  /// Saves the window as it is now, shown for [ms] milliseconds.
  Future<void> add(WidgetTester tester, int ms) async {
    final name = '${(_count++).toString().padLeft(4, '0')}.png';
    final image = await captureImage(tester.element(_window));
    await tester.runAsync(() async {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('No PNG for $name.');
      File('${dir.path}/$name').writeAsBytesSync(png.buffer.asUint8List());
    });
    _list.writeln("file '$name'\nduration ${ms / 1000}");
    // ffmpeg's concat list needs the last file again for its duration.
    File('${dir.path}/frames.txt').writeAsStringSync(
      '$_list'
      "file '$name'\n",
    );
  }

  /// Types [text] a few letters per frame, then sends it.
  Future<void> type(WidgetTester tester, String text) async {
    final field = find.byType(TextField).last;
    for (var end = 3; end < text.length + 3; end += 3) {
      await tester.enterText(
        field,
        text.substring(0, end.clamp(0, text.length)),
      );
      await tester.pump();
      await add(tester, 70);
    }
    await add(tester, 400);
    await tester.testTextInput.receiveAction(TextInputAction.send);
  }
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('tool-call.png: one action and its receipt', (tester) async {
    await _app(
      tester,
      replies: [
        ScriptedStep.toolCalls([
          _call('1', 'create_item', {'title': 'Buy milk'}),
        ]),
        ScriptedStep.text('I have added an item called Buy milk.'),
      ],
    );
    await _send(tester, 'Add an item called Buy milk.');
    await _save(_window, 'tool-call');
  });

  testWidgets('approval.png: a delete waits for the person', (tester) async {
    await _app(
      tester,
      replies: [
        ScriptedStep.toolCalls([
          _call('1', 'create_item', {'title': 'Buy milk'}),
        ]),
        ScriptedStep.text('I have added an item called Buy milk.'),
        ScriptedStep.toolCalls([
          _call('2', 'delete_item', {'id': 'item_1'}),
        ]),
      ],
    );
    await _send(tester, 'Add an item called Buy milk.');
    await _send(tester, 'Delete the item Buy milk.', frames: 10);
    await _save(_window, 'approval');
  });

  testWidgets('persian-rtl.png: the app in Persian', (tester) async {
    await _app(
      tester,
      locale: const Locale('fa'),
      replies: [
        ScriptedStep.toolCalls([
          _call('1', 'create_item', {'title': 'خرید نان'}),
        ]),
        ScriptedStep.text('موردی به نام «خرید نان» اضافه شد.'),
      ],
    );
    await _send(tester, 'یک مورد به نام «خرید نان» اضافه کن.');
    await _save(_window, 'persian-rtl');
  });

  testWidgets('phone.png: the assistant as a sheet', (tester) async {
    await _app(
      tester,
      size: const Size(390, 800),
      pixelRatio: 1.5,
      items: ['Buy bread', ..._seed],
      replies: [
        ScriptedStep.toolCalls([_call('1', 'list_items', {})]),
        ScriptedStep.text(
          'You have 4 items on your list: "Buy bread", "Renew passport", '
          '"Call the dentist" and "Book flights to Lisbon".',
        ),
        ScriptedStep.toolCalls([
          _call('2', 'create_item', {'title': 'Water the plants'}),
        ]),
        ScriptedStep.text('I have added "Water the plants" to your list.'),
      ],
    );
    await _send(tester, 'What is on my list?');
    await _send(tester, 'Add an item called Water the plants.');
    await _save(_window, 'phone');
  });

  testWidgets('demo: add, approve a delete, switch to dark mode', (
    tester,
  ) async {
    final out = Platform.environment['DEMO_FRAMES'];
    if (out == null) return;
    final frames = _Frames(Directory(out)..createSync(recursive: true));
    await _app(
      tester,
      pixelRatio: 1,
      replies: [
        ScriptedStep.toolCalls([
          _call('1', 'create_item', {'title': 'Buy milk'}),
        ]),
        ScriptedStep.text('I have added an item called Buy milk.'),
        ScriptedStep.toolCalls([
          _call('2', 'delete_item', {'id': 'item_1'}),
        ]),
        ScriptedStep.text('The item Buy milk has been deleted.'),
        ScriptedStep.toolCalls([
          _call('3', 'set_theme_mode', {'mode': 'dark'}),
        ]),
        ScriptedStep.text('I have switched to dark mode.'),
      ],
    );
    await frames.add(tester, 1200);
    await frames.type(tester, 'Add an item called Buy milk.');
    await tester.pumpAndSettle();
    await frames.add(tester, 2200);
    await frames.type(tester, 'Delete the item Buy milk.');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await frames.add(tester, 2500);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    await frames.add(tester, 2200);
    await frames.type(tester, 'Switch to dark mode.');
    await tester.pumpAndSettle();
    await frames.add(tester, 3500);
  });
}
