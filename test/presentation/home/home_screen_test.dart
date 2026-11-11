import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_agentify/core/theme/app_theme.dart';
import 'package:flutter_agentify/core/widgets/states/states.dart';
import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/domain/actions/app_actions.dart';
import 'package:flutter_agentify/domain/actions/items_actions.dart';
import 'package:flutter_agentify/domain/entities/item.dart';
import 'package:flutter_agentify/domain/entities/language/supported_languages.dart';
import 'package:flutter_agentify/presentation/home/home_screen.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/test_app.dart';

/// An items stream that never emits, so the screen stays in its loading state.
class _NeverEmits extends FakeItemsRepository {
  @override
  Stream<List<Item>> watchItems() => StreamController<List<Item>>().stream;
}

Item _item(String id, String title) =>
    Item(id: id, title: title, createdAt: DateTime(2026, 1, 1));

Future<void> _fillDialog(WidgetTester tester, String title) async {
  await tester.enterText(find.byType(TextField).first, title);
  await tester.pump();
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('adding an item through the dialog shows it in the list', (
    tester,
  ) async {
    final items = FakeItemsRepository();
    await pumpTestApp(tester, locale: english, items: items);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await _fillDialog(tester, 'Milk');
    expect(find.text('Milk'), findsOneWidget);
    expect((await items.getItems()).single.title, 'Milk');
  });

  testWidgets('editing an item changes its title', (tester) async {
    final items = FakeItemsRepository([_item('a', 'Milk')]);
    await pumpTestApp(tester, locale: english, items: items);
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    await _fillDialog(tester, 'Bread');
    expect(find.text('Bread'), findsOneWidget);
    expect(find.text('Milk'), findsNothing);
  });

  testWidgets('confirming delete removes the item', (tester) async {
    final items = FakeItemsRepository([_item('a', 'Milk')]);
    await pumpTestApp(tester, locale: english, items: items);
    await tester.drag(find.text('Milk'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsNothing);
    expect(await items.getItemCount(), 0);
  });

  testWidgets(
    'saving an item that was deleted meanwhile shows the not-found message',
    (tester) async {
      final items = FakeItemsRepository([_item('a', 'Milk')]);
      await pumpTestApp(tester, locale: english, items: items);
      await tester.tap(find.text('Milk'));
      await tester.pumpAndSettle();
      await items.deleteItem('a');
      await _fillDialog(tester, 'Bread');
      expect(find.text('That no longer exists.'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    },
  );

  testWidgets('long press selects an item and reports it to AppContext', (
    tester,
  ) async {
    final items = FakeItemsRepository([
      _item('a', 'Milk'),
      _item('b', 'Bread'),
    ]);
    await pumpTestApp(tester, locale: english, items: items);
    await tester.longPress(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(ServiceLocator.getIt<AppContext>().navigation.selectedIds, ['a']);
    expect(find.text('1 selected'), findsOneWidget);
    // A real button, so a keyboard and a screen reader reach it too.
    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.byTooltip('Clear selection')),
      matchesSemantics(
        tooltip: 'Clear selection',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
    await tester.tap(find.byTooltip('Clear selection'));
    await tester.pumpAndSettle();
    expect(ServiceLocator.getIt<AppContext>().navigation.selectedIds, isEmpty);
    expect(find.text('1 selected'), findsNothing);
  });

  testWidgets('the empty state shows when there are no items', (tester) async {
    await pumpTestApp(tester, locale: english);
    expect(find.text('No items yet. Add one!'), findsOneWidget);
  });

  testWidgets('Save is disabled while the title is blank', (tester) async {
    await pumpTestApp(tester, locale: english);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    FilledButton save() =>
        tester.widget(find.widgetWithText(FilledButton, 'Save'));
    expect(save().onPressed, isNull);
    await tester.enterText(find.byType(TextField).first, 'Milk');
    await tester.pump();
    expect(save().onPressed, isNotNull);
  });

  // One grapheme of five code points, so the field's own limit (graphemes)
  // lets it through and only the code-point count can refuse it.
  const family = '👨‍👩‍👧';

  testWidgets('Save stays disabled while the title is over 200 code points', (
    tester,
  ) async {
    await pumpTestApp(tester, locale: english);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    FilledButton save() =>
        tester.widget(find.widgetWithText(FilledButton, 'Save'));
    await tester.enterText(find.byType(TextField).first, family * 41);
    await tester.pump();
    expect(save().onPressed, isNull);
    await tester.enterText(find.byType(TextField).first, family * 40);
    await tester.pump();
    expect(save().onPressed, isNotNull);
  });

  testWidgets('Save stays disabled while the description is too long', (
    tester,
  ) async {
    await pumpTestApp(tester, locale: english);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    FilledButton save() =>
        tester.widget(find.widgetWithText(FilledButton, 'Save'));
    await tester.enterText(find.byType(TextField).first, 'Milk');
    await tester.enterText(find.byType(TextField).last, family * 401);
    await tester.pump();
    expect(save().onPressed, isNull);
    await tester.enterText(find.byType(TextField).last, family * 400);
    await tester.pump();
    expect(save().onPressed, isNotNull);
  });

  testWidgets('the title field stops at 200 characters', (tester) async {
    await pumpTestApp(tester, locale: english);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'a' * 250);
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller?.text.length, 200);
  });

  testWidgets(
    'editing only the description leaves a title the assistant changed meanwhile',
    (tester) async {
      final items = FakeItemsRepository([_item('a', 'Milk')]);
      await pumpTestApp(tester, locale: english, items: items);
      await tester.tap(find.text('Milk'));
      await tester.pumpAndSettle();
      await ServiceLocator.getIt<ActionRegistry>().run(
        ServiceLocator.getIt<AppActions>().updateItem,
        const UpdateItemInput(id: 'a', title: 'Oat milk'),
      );
      await tester.enterText(find.byType(TextField).last, 'Cold');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect((await items.getItem('a'))?.title, 'Oat milk');
      expect((await items.getItem('a'))?.description, 'Cold');
    },
  );

  testWidgets('saving an unchanged dialog runs no action', (tester) async {
    final items = FakeItemsRepository([_item('a', 'Milk')]);
    final container = await pumpTestApp(tester, locale: english, items: items);
    final events = <Object>[];
    final sub = ServiceLocator.getIt<ActionRegistry>().changes.listen(
      events.add,
    );
    addTearDown(sub.cancel);
    expect(container, isNotNull);
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(events, isEmpty);
  });

  testWidgets("the row's delete button deletes after confirming", (
    tester,
  ) async {
    final items = FakeItemsRepository([_item('a', 'Milk')]);
    await pumpTestApp(tester, locale: english, items: items);
    await tester.tap(find.byTooltip('Delete Milk'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsNothing);
    expect(await items.getItemCount(), 0);
  });

  testWidgets("the row's edit button opens the dialog and saves", (
    tester,
  ) async {
    final items = FakeItemsRepository([_item('a', 'Milk')]);
    await pumpTestApp(tester, locale: english, items: items);
    await tester.tap(find.byTooltip('Edit Milk'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Oat');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await items.getItem('a'))?.description, 'Oat');
  });

  testWidgets('delete selected asks once, deletes them and clears', (
    tester,
  ) async {
    final items = FakeItemsRepository([
      _item('a', 'Milk'),
      _item('b', 'Bread'),
      _item('c', 'Tea'),
    ]);
    await pumpTestApp(tester, locale: english, items: items);
    expect(find.byTooltip('Delete selected'), findsNothing);
    await tester.longPress(find.text('Milk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bread'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete selected'));
    await tester.pumpAndSettle();
    expect(find.text('Delete 2 items?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect((await items.getItems()).map((i) => i.id), ['c']);
    expect(ServiceLocator.getIt<AppContext>().navigation.selectedIds, isEmpty);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('cancelling delete selected keeps items and selection', (
    tester,
  ) async {
    final items = FakeItemsRepository([_item('a', 'Milk')]);
    await pumpTestApp(tester, locale: english, items: items);
    await tester.longPress(find.text('Milk'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete selected'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await items.getItemCount(), 1);
    expect(ServiceLocator.getIt<AppContext>().navigation.selectedIds, ['a']);
  });

  testWidgets('leaving the home screen drops the selection', (tester) async {
    final items = FakeItemsRepository([_item('a', 'Milk')]);
    await pumpTestApp(tester, locale: english, items: items);
    await tester.longPress(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(ServiceLocator.getIt<AppContext>().navigation.selectedIds, ['a']);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(ServiceLocator.getIt<AppContext>().navigation.selectedIds, isEmpty);
  });

  testWidgets("each row's delete button names its item", (tester) async {
    final items = FakeItemsRepository([
      _item('a', 'Milk'),
      _item('b', 'Bread'),
    ]);
    await pumpTestApp(tester, locale: english, items: items);
    expect(find.byTooltip('Delete Milk'), findsOneWidget);
    expect(find.byTooltip('Delete Bread'), findsOneWidget);
  });

  testWidgets('while selecting, a tap toggles a row and opens no dialog', (
    tester,
  ) async {
    final items = FakeItemsRepository([
      _item('a', 'Milk'),
      _item('b', 'Bread'),
    ]);
    await pumpTestApp(tester, locale: english, items: items);
    await tester.longPress(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNWidgets(2));
    await tester.tap(find.text('Bread'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(ServiceLocator.getIt<AppContext>().navigation.selectedIds.toSet(), {
      'a',
      'b',
    });
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    expect(ServiceLocator.getIt<AppContext>().navigation.selectedIds, ['b']);
  });

  testWidgets('the delete confirmation reads onError on error in dark mode', (
    tester,
  ) async {
    final theme = AppTheme.dark();
    final items = FakeItemsRepository([_item('a', 'Milk')]);
    await pumpTestApp(
      tester,
      locale: english,
      items: items,
      home: Theme(data: theme, child: const HomeScreen()),
    );
    await tester.tap(find.byTooltip('Delete Milk'));
    await tester.pumpAndSettle();
    final label = tester.widget<RichText>(
      find.descendant(
        of: find.widgetWithText(FilledButton, 'Delete'),
        matching: find.byType(RichText),
      ),
    );
    expect(label.text.style?.color, theme.colorScheme.onError);
  });

  testWidgets('the add button does not cover the last row', (tester) async {
    final items = FakeItemsRepository([
      for (var i = 0; i < 30; i++) _item('$i', 'Item $i'),
    ]);
    await pumpTestApp(tester, locale: english, items: items);
    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    final row = tester.getRect(find.byType(Card).last);
    final fab = tester.getRect(find.byType(FloatingActionButton));
    expect(row.overlaps(fab), isFalse);
  });

  testWidgets('Enter in the title field saves the item', (tester) async {
    final items = FakeItemsRepository();
    await pumpTestApp(tester, locale: english, items: items);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Milk');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect((await items.getItems()).single.title, 'Milk');
  });

  testWidgets('the empty list shows its own hint', (tester) async {
    await pumpTestApp(tester, locale: english);
    expect(
      find.text('Items you or the assistant add show up here.'),
      findsOneWidget,
    );
  });

  for (final language in kSupportedLanguages) {
    testWidgets('dates follow the app language: ${language.englishName}', (
      tester,
    ) async {
      final date = DateTime(2026, 11, 9);
      final items = FakeItemsRepository([
        Item(id: 'a', title: 'Milk', createdAt: date),
      ]);
      await pumpTestApp(tester, items: items, locale: Locale(language.locale));
      final context = tester.element(find.byType(HomeScreen));
      expect(Localizations.localeOf(context).languageCode, language.locale);
      final shown = MaterialLocalizations.of(context).formatMediumDate(date);
      expect(find.text(shown), findsOneWidget);
    });
  }

  for (final language in kSupportedLanguages) {
    testWidgets('rows fit at 320 wide in ${language.englishName}, selecting '
        'too', (tester) async {
      final items = FakeItemsRepository([
        Item(
          id: 'a',
          title: 'A title long enough to need more than one line on a phone',
          description: 'And a description that wraps as well.',
          createdAt: DateTime(2026, 1, 1),
        ),
      ]);
      await pumpFullApp(
        tester,
        size: const Size(320, 640),
        locale: Locale(language.locale),
        items: items,
      );
      await tester.longPress(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the loading state shows a skeleton list', (tester) async {
    final container = setUpTestServices(items: _NeverEmits());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    expect(find.byType(SkeletonList), findsOneWidget);
    // Unmount so the shimmer's ticker stops before the test ends.
    await tester.pumpWidget(const SizedBox());
  });
}
