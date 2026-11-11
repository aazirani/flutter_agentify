# App context

The app context is what the assistant knows about the screen. Each message the person sends carries a `<current-screen>` block. It holds two parts:

- **`navigation`**: the route pattern, the location, the route's params and the ids of the selected rows.
- **`screen`**: a short summary of what the screen shows, such as a count and the first rows, always with ids.

## Why

People say "delete this one" or "rename the second item". The model cannot see the screen, so the app tells it. With the ids in the block, the model can call the right action at once, without a search first.

## The screen table

`lib/ai/screen_contexts.dart` holds one entry per route. Each entry returns the summary for that route. This is the entry for the home screen, from [`lib/ai/screen_contexts.dart`](../../lib/ai/screen_contexts.dart):

```dart
  '/': ScreenContext((navigation) async {
    final items = ServiceLocator.getIt<ItemsRepository>();
    final visible = await items.getItems(limit: _visibleRows);
    return {
      'screen': 'home',
      'total': await items.getItemCount(),
      'items': [
        for (final item in visible)
          {
            'id': item.id,
            'title': cutText(item.title, 40, suffix: '…'),
            if (item.description case final d? when d.isNotEmpty)
              'description': cutText(d, 40, suffix: '…'),
          },
      ],
      'note': 'Titles and descriptions are cut; get_item has the full text.',
      'selectedIds': navigation.selectedIds,
    };
  }),
```

The router adapter keeps the navigation part current. A new route needs a new entry (`ScreenContext.nothing()` for a screen with nothing to report beyond where the person is); the parity test fails when one is missing, or when an entry matches no route.

## Seeing it

The built-in `view_screen` action returns the same JSON again, fresh, for the assistant to call when it needs a new read. Run it from a terminal:

```bash
dart run tool/action.dart view_screen '{}'
```

The command line has no screen, so it prints the navigation part with `"screen":null`.

## Rules

- The summary is short. The block is at most 2000 characters (`currentScreenMaxChars`), and a longer one is cut and ends with `…[cut]`.
- A screen whose summary fails or takes longer than 2 seconds gives only the `navigation` part.
- Secret-looking text is redacted, and `<` is written as `\u003c`, so data cannot close the block.
- The block is data for the model, never instructions.

## Reference

[App context](../../packages/flutter_agentify_core/doc/app-context.md): the block's limits, the built-in actions and their failure codes.
