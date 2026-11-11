---
name: routing
description: How navigation works with GoRouter, the single shell that holds the assistant, screen-context entries for new routes, and deep links. Use when adding a screen or route, navigating between screens, or changing the app shell.
---

# Routing

Don't load this for what the assistant is told about a screen; see `app-context`.

## Rule

- Navigate with GoRouter only: `context.go('/settings')` or `context.push(...)`. Never `Navigator.push…`. Popping dialogs and sheets with `Navigator.of(context).pop()` is fine.
- All routes live inside the one `ShellRoute` in `lib/utils/routes/app_router.dart`. Its builder returns `AssistantShell(child: child)` (`lib/presentation/assistant/assistant_shell.dart`), so the assistant is mounted once and keeps its conversation across navigation. Do not add a second shell or a route outside it.
- Every new `GoRoute` needs an entry in `buildScreenContexts` in `lib/ai/screen_contexts.dart`, keyed by the route's full path pattern.

Enforced by the lint rule `no_navigator_push` and by `test/ai/parity_test.dart`, which fails when a route has no screen entry.

## Why

The assistant reads `AppContext` navigation (route, location, params) to know where the person is, and `attachRouter` in `lib/ai/go_router_adapter.dart` keeps it in step with GoRouter. A screen opened with `Navigator.push` is invisible to that, and a second shell would rebuild and lose the chat.

## How

1. Write the screen under `lib/presentation/<feature>/`.
2. Add `GoRoute(path: '/thing/:id', builder: ...)` inside the shell's `routes` list. A screen opened from another goes in that screen's `routes` (Settings sits under `/` as `settings`), so `context.go` stacks it and back returns there. A nested path is joined to its parent; `routePatterns` in `lib/ai/go_router_adapter.dart` computes the full pattern that the parity test compares.
3. Add the same pattern to `buildScreenContexts`. Return a short summary with counts and the first rows, always with ids, never a key. `/` and `/settings` there are the models.
4. Link with `context.go('/thing/$id')`. Read path values from `state.pathParameters` in the route builder.
5. The assistant's `navigate` action calls `router.go(location)` through `appContext.onNavigate`, set in `attachRouter`. Anything it can reach must be a real route.
6. Deep links: a deep link is a route path, so `/thing/42` opens that screen if the route exists. The repo configures no platform URL scheme or app link (no intent filter in `android/`, no URL types in `ios/`); add that only when the task asks for it.

## Anti-patterns

- `Navigator.of(context).push(MaterialPageRoute(...))`.
- A route with no screen-context entry (the parity test names it).
- Putting an id or secret in a query string that is sent to the model as `location`.
- Building a second `MaterialApp.router` or shell for a "full screen" page.
- Mutating data inside a route builder.

## Verification

- `flutter test test/ai/parity_test.dart test/ai/go_router_adapter_test.dart test/ai/screen_contexts_test.dart`
- `dart analyze --fatal-infos` reports `no_navigator_push`.
- `test/presentation/assistant/assistant_shell_test.dart` covers the shell.
- `tool/check.sh` ends with `All checks passed.`

## Related skills

- `app-context` — how the screen summary is built and used.
- `adding-a-feature` — the full list for a new feature.
- `ui-design` — what the new screen must handle.
