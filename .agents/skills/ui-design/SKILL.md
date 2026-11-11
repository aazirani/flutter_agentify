---
name: ui-design
description: How screens are built here, with Material 3 tokens from the theme, loading, empty, error, success and narrow-width states, matching skeletons, and response timing. Use when building or restyling a screen or widget.
---

# UI design

Don't load this for string keys and right-to-left layout; see `i18n-and-rtl`.

## Rule

- Colors, spacing, shapes and type come from the theme: `Theme.of(context).colorScheme`, `textTheme`, and the tokens in `lib/core/theme/` (`app_spacing.dart`, `app_shapes.dart`, `app_animations.dart`). No `Color(0xFF...)` and no `Colors.red` outside `lib/core/theme/`.
- Every screen that loads data handles five cases: loading, empty, error, success, and a narrow width (a phone at 320 dp wide, and the side-panel case at 840 dp and up).
- A skeleton has the same layout as the final content.
- Respond to a tap within 100 ms. Show a pending state if the work takes more than 400 ms.

Enforced by the lint rule `no_hardcoded_colors` for colors. No automated check covers the five states, skeleton shape or timing; review them.

## Why

Theme tokens keep light, dark and custom themes consistent. Missing states are what people see first when something is slow or wrong. A skeleton that does not match makes the layout jump when data arrives.

## How

- **States:** import `package:flutter_agentify/core/widgets/states/states.dart`. It exports `LoadingState`, `EmptyState`, `ErrorState` and the shimmer skeletons (`SkeletonListItem`, `SkeletonCard`, `SkeletonList`). `lib/presentation/home/home_screen.dart` is the model: `itemsAsync.when(loading: ..., error: ... onRetry: () => ref.invalidate(...), data: ...)`, and an `EmptyState` with an action when the list is empty.
- **Skeletons:** build the placeholder from the same row widget shape (`SkeletonListItem` for list rows). Wrap in `Shimmer` / `SkeletonList`.
- **Status colors:** success, warning, info, muted and disabled come from the `SemanticColors` theme extension in `lib/core/theme/app_colors.dart`: `Theme.of(context).extension<SemanticColors>()`. Errors use `colorScheme.error`.
- **Timing:** `AppAnimations.durationInstant` is 100 ms and `durationModerate` is 400 ms in `lib/core/theme/app_animations.dart`. Press feedback uses the 100–150 ms tokens. For work that may run long, show nothing until 400 ms have passed, then a progress or skeleton state, so quick results do not flash.
- **Width:** the breakpoint is `assistantPanelBreakpoint` (840) in `lib/presentation/assistant/assistant_shell.dart`. Use `Expanded`, `Flexible` and `maxLines` with `TextOverflow.ellipsis`, not fixed widths on text.
- **Failures from actions:** show them with `showActionFailure` from `lib/presentation/action_failure_message.dart`.
- Dialogs close with `Navigator.of(context).pop()`; open screens with GoRouter.
- Theme values live in `lib/core/theme/app_theme.dart` (light, dark). Add a token there before using a new raw value.

## Anti-patterns

- `color: Colors.grey` or a hex color in a widget.
- A bare `CircularProgressIndicator` for a list that has a skeleton available.
- An empty list that shows a blank screen, or an error that shows a stack trace.
- A fixed `SizedBox(width: 400)` around text.
- Showing a spinner for every call, even one that returns in 50 ms.
- `// ignore: flutter_agentify_lints/no_hardcoded_colors` to avoid adding a token.

## Verification

- `dart analyze --fatal-infos` reports `no_hardcoded_colors`.
- Widget tests: `test/widgets/loading_state_test.dart`, `test/widgets/error_state_test.dart`, `test/presentation/home/home_screen_test.dart`.
- Run the app at a narrow width and in dark mode and look.
- `tool/check.sh` ends with `All checks passed.`

## Related skills

- `i18n-and-rtl` — strings and mirrored layout.
- `accessibility` — touch targets, contrast and labels.
- `state-management` — where the loading and error values come from.
- `performance` — long lists and smooth frames.
