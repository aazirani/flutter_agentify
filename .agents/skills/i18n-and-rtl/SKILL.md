---
name: i18n-and-rtl
description: How text is translated and laid out here, with a key in every language file, placeholders, right-to-left layout with directional padding and alignment, the one list of languages and their fonts. Use when adding any visible text, adding or removing a language, or a layout that must work right to left.
---

# i18n and RTL

Don't load this for colors, states and spacing in general; see `ui-design`.

## Rule

- Every visible string is a key in every file in `assets/lang/` (one per language), read with `AppLocalizations.of(context)?.translate(key)`. No literal text in `Text`, `labelText`, `hintText`, `helperText`, `errorText`, `tooltip`, `message` or `semanticLabel`.
- The files have the same keys as the default language's file and no empty values.
- Layout works right-to-left: use directional classes (`EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlign.start`/`end`), not `left`/`right`.
- Languages are defined only in `kSupportedLanguages` (`lib/domain/entities/language/supported_languages.dart`). No code elsewhere checks for a language code.

Enforced by the lint rule `no_hardcoded_strings` and by `test/i18n/translations_test.dart`. The narrow-width layout tests run in every listed language and check the direction, so a right-to-left language in the list is covered; no test catches every `left`/`right` mistake.

## Why

`kSupportedLanguages` is the one place that defines the languages; the template starts with English and Persian. Each entry holds the code, names, flag and font. The first entry is the default. A missing key shows the raw key. Layout built with `left`/`right` stays left-aligned when the language flips.

## How

1. Add the key to every file in `assets/lang/` in the same change. Keys are `snake_case`.
2. That test also pins the total key count of the default language's file. Update the number in `test/i18n/translations_test.dart` when you add or remove keys.
3. Read it in a widget. `HomeScreen` wraps the call in a helper: `AppLocalizations.of(context)?.translate(key) ?? fallback`. Keep a fallback for tests that have no delegate.
4. Placeholders are a literal `{}` replaced with `replaceFirst`, for example `"selected_count": "{} selected"` used as `_tr('selected_count').replaceFirst('{}', '${selected.length}')` in `lib/presentation/home/home_screen.dart`. Use one `{}` per string and write each translation so it still reads correctly with the value in place.
5. Loading: `lib/utils/locale/app_localization.dart` loads `assets/lang/<languageCode>.json` and the delegate's supported locales come from `kSupportedLanguages`. Adding a language is its JSON file plus an entry (plus a font if the script needs one); removing one is deleting both. The tests iterate the list and need no edit. The code must be one Flutter's `GlobalMaterialLocalizations` supports; any other needs its own `MaterialLocalizations` delegate, or Material widgets fail. Steps: the Flutter Agentify guide *Add a language*.
6. Layout: `AlignmentDirectional.centerEnd` and `EdgeInsetsDirectional.only(end: 20)` in the dismiss background of `lib/presentation/home/home_screen.dart` are the pattern. Icons that point somewhere (back arrows) must mirror; Material icons do this automatically.
7. Fonts: `AppTheme.light(locale: ...)` passes the locale to `AppTypography.setLocale` in `lib/core/theme/app_typography.dart`, which uses the entry's `fontFamily` and `fontFallbacks`. Fonts are bundled in `assets/fonts/` and declared in `pubspec.yaml`. Another script needs its font bundled and declared there.
8. Direction: Flutter derives it from the locale (right to left for `fa`, `ar`, `he` and the like). Don't decide it in code; read `Directionality.of(context)`.
9. Receipts: each action writes an English `summary` in `lib/domain/actions/` and a `key` with `args`, such as `key: 'created_item', args: {'title': created.title}`. The chat shows `receipt_<key>` from the language file with `{title}` filled in, or the summary when the key is missing. Add `receipt_<key>` to every language file; `test/i18n/translations_test.dart` lists the receipts that must be there. The action names are translated with `action_<name>` keys.
10. Text typed by the person may be either direction. A `TextField` follows the app's direction by default; give it a `textDirection` only where a field must follow its content.

## Anti-patterns

- `Text('Save')` or `tooltip: 'Close'`.
- A key added to `en.json` only.
- `if (locale == 'fa')` or a `switch` on a language code outside `kSupportedLanguages`.
- `EdgeInsets.only(left: 16)` or `Alignment.centerLeft` for content that should follow the reading direction.
- Building a sentence by joining translated pieces; use one key with `{}`.
- Using `// ignore: flutter_agentify_lints/no_hardcoded_strings`.

## Verification

- `dart analyze --fatal-infos` reports `no_hardcoded_strings`.
- `flutter test test/i18n/translations_test.dart`
- Switch to a right-to-left language, such as Persian, in Settings (or run `dart run tool/action.dart set_language '{"locale":"fa"}'` against the scratch database) and look at the screen.
- `tool/check.sh` ends with `All checks passed.`

## Related skills

- `ui-design` — states, tokens and widths.
- `accessibility` — semantic labels are strings too and need keys.
- `adding-a-feature` — the full list for a new screen.
