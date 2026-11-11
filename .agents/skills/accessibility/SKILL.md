---
name: accessibility
description: What a screen needs so everyone can use it, such as semantic labels on icon-only buttons, 48-point touch targets, contrast from theme roles, text scaling and focus order. Use when adding a button, icon, list row, dialog or form.
---

# Accessibility

Don't load this for translating text or mirrored layout; see `i18n-and-rtl`.

## Rule

- Every icon-only control has a label: `tooltip:` on `IconButton`, or a `Semantics(label: ...)` wrapper. The label is a translated string.
- Touch targets are at least 48 by 48 points.
- Text and icon colors come from paired theme roles (`onSurface` on `surface`, `onError` on `error`), never a picked shade.
- Text grows with the system text scale; nothing clips or overflows at 200 percent.
- Focus order follows reading order, and a dialog puts focus on its first field.

No automated check exists for these. `no_hardcoded_strings` does cover `tooltip` and `semanticLabel` text, and `no_hardcoded_colors` blocks literal colors, which helps contrast indirectly. The rest is review plus a manual pass.

## Why

Screen readers announce what has a label and skip what does not. Paired theme roles keep contrast correct in light and dark. People who raise the text size, or use a keyboard, need the same screen to work.

## How

- Look at `lib/presentation/home/home_screen.dart`: the app bar buttons carry `tooltip: _tr('settings', 'Settings')` and `tooltip: _tr('clear_selection', ...)`; the floating action button has `tooltip: _tr('add_item', ...)`. Copy that for every new `IconButton`.
- `IconButton` and the Material buttons already give a 48-point target. If you build a tap area from `GestureDetector` or `InkWell` around a small icon, wrap it in `ConstrainedBox(constraints: BoxConstraints(minWidth: 48, minHeight: 48))`. The theme sets `minimumSize` for its buttons in `lib/core/theme/app_theme.dart`.
- Contrast: use `colorScheme.onX` with `X`, as the delete background in `lib/presentation/home/home_screen.dart` does (`error` with `onError`). For secondary text use `onSurfaceVariant`, not a custom grey.
- Text scale: use `Theme.of(context).textTheme` styles, allow wrapping (`maxLines` with ellipsis only where truncation is safe), and avoid fixed heights on rows that hold text. Put a long form in a scrollable.
<!-- @example:begin -->
- Focus: keep widgets in reading order in the tree. Use `autofocus: true` on the first field of a dialog, as `_ItemDialog` does.
<!-- @example:end -->
<!-- @empty: - Focus: keep widgets in reading order in the tree. Use `autofocus: true` on the first field of a dialog, as `_ItemDialog` in .agents/example/lib/presentation/home/home_screen.dart does. -->
- State must not rely on color alone: the selected row in `lib/presentation/home/home_screen.dart` also sets `ListTile.selected`.
<!-- @example:begin -->
- Dismiss-to-delete gestures need a button path too; the row's delete goes through `_confirmDelete` and the same `delete_item` action.
<!-- @example:end -->
<!-- @empty: - Dismiss-to-delete gestures need a button path too; in the example, the row's delete goes through `_confirmDelete` (.agents/example/lib/presentation/home/home_screen.dart) and the same `delete_item` action. -->

## Anti-patterns

- `IconButton(icon: Icon(Icons.add), onPressed: ...)` with no `tooltip`.
- A 24-point tappable icon with no padding.
- `Text(..., style: TextStyle(color: Colors.grey))`.
- `SizedBox(height: 56)` around a text row.
- A gesture-only action (swipe, long press) with no visible control.
- Error or success shown only as a color change.

## Verification

- No lint rule or doctor check. Check by hand: turn on a screen reader, set the system text size to the largest, tab through with a keyboard, switch to dark mode.
- In a widget test, `tester.getSemantics(find.byTooltip(...))` or `find.byTooltip` proves a label exists; see `test/presentation/home/home_screen_test.dart` for the harness.
- `tool/check.sh` ends with `All checks passed.`

## Related skills

- `ui-design` — the five states and tokens.
- `i18n-and-rtl` — keys for every label.
