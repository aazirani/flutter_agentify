# App context

The assistant sees what the person sees. `AppContext` holds where the person is (`NavigationState`: route pattern, location, params, selected ids) and a table that says what each screen shows.

## Smallest example

```dart
final appContext = AppContext(
  screens: {
    '/': ScreenContext((nav) => {'items': visibleItems.take(20).toList()}),
    '/items/:id': ScreenContext((nav) => itemSummary(nav.params['id'])),
    '/settings': const ScreenContext.nothing(),
  },
);

// The router adapter keeps it current and opens locations for the assistant:
appContext.setNavigation(NavigationState(route: '/items/:id', location: '/items/42', params: {'id': '42'}));
appContext.onNavigate = (location) async => router.go(location);
```

## Rules

- The table is keyed by route pattern and lives next to the router, so the parity check can see that every route has an entry. Use `ScreenContext.nothing()` for a route with nothing to report.
- A `viewScreen` callback returns a short, JSON-encodable summary of the visible records.
- Each message the person sends carries a `<current-screen>` block of at most 2,000 characters, tags included (`AgentConfig.currentScreenMaxChars`), with key-shaped text replaced by `[redacted]`. When the screen's callback throws, or the route has no callback, the block holds the navigation state alone, as it does when the callback takes longer than `viewTimeout` (2 seconds). A longer result is cut.
- The block goes on the person's message, never into the system text, so the system text stays the same from turn to turn.
- `appContext.setSelection(ids)` records the selected ids. Only the router adapter writes the rest of the navigation state. The assistant moves through the `navigate` action.

## Built-in actions

| Action | What it does |
|---|---|
| `view_screen` | A fresh, full read of the current screen (results up to 8,000 characters). |
| `navigate` | Opens a location through `onNavigate`. |
| `save_memory` | Keeps a short fact for later conversations; asks first. See storage-and-memory.md. |
| `delete_memory` | Forgets a fact by id; asks first. |

`builtInActions(appContext: ..., memories: ...)` returns all four.

## Failure codes

| Code | When |
|---|---|
| `unknown_route` | `navigate` got a location no route pattern matches (or one with a scheme or host). `details['routes']` lists the patterns. |
| `navigation_unavailable` | No router adapter has set `onNavigate`. |
