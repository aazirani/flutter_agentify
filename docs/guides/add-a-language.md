# Add or remove a language

One list defines the app's languages: `kSupportedLanguages` in `lib/domain/entities/language/supported_languages.dart`. Each language also has a strings file, `assets/lang/<code>.json`. The app starts with English (`en`) and Persian (`fa`).

The list feeds the app's supported locales, the language picker in Settings, the `set_language` action, the fonts, and the tests. The first entry is the default: the app uses it when the device language is not in the list.

## Add a language

This adds German (`de`). The steps are the same for any language.

### 1. The strings

Copy the default language's file and translate each value. Keep the keys as they are.

```bash
cp assets/lang/en.json assets/lang/de.json
```

A `{}` or a named `{title}` in a value is a placeholder the code fills in, such as `"page_not_found": "Page not found: {}"`. Keep it in the translation.

The chat's texts are here too, under the `assistant_*` keys.

The action names the chat shows are here too, under the `action_*` keys, and so are the receipt texts, under the `receipt_*` keys. A receipt whose key is missing in a language shows its English summary.

### 2. The entry

Add an entry to `kSupportedLanguages`:

```dart
  Language(
    locale: 'de',
    language: 'Deutsch',
    englishName: 'German',
    flagEmoji: '🇩🇪',
    fontFamily: 'Inter',
    fontFallbacks: ['Inter', 'Roboto', 'sans-serif'],
  ),
```

Put it first to make it the default.

Flutter's own widgets, such as date pickers, come translated for most languages. The code must be one that [Flutter's Material widgets support](https://api.flutter.dev/flutter/flutter_localizations/GlobalMaterialLocalizations-class.html). For any other code, the app needs its own `MaterialLocalizations` delegate, or its Material widgets fail. Text direction comes from the language code: a right-to-left language, such as Arabic or Hebrew, needs no extra code. Flutter mirrors the layout for it.

### 3. The font

The app bundles Inter for Latin, Greek and Cyrillic scripts, and Vazirmatn for Persian. German uses Inter and needs nothing more.

For another script, such as Hindi or Japanese:

1. Put the font file in `assets/fonts/`.
2. Declare it under `fonts:` in `pubspec.yaml`, next to Inter and Vazirmatn.
3. Name its family in the entry's `fontFamily` and `fontFallbacks`.

### 4. Check

The tests read the list, so they cover the new language without changes. They check that every language has a strings file with the same keys as the default and no empty values, that it uses its font, and that its screens fit at 320 wide in the right direction.

```bash
flutter test test/i18n
tool/check.sh
```

Then run the app, open Settings and choose Deutsch. You can also ask the assistant to switch the language.

A key you add must go into every file in `assets/lang/`, or the translations test fails.

## Remove a language

This removes Persian (`fa`).

1. Delete its entry from `kSupportedLanguages`.
2. Delete its strings file:

   ```bash
   git rm assets/lang/fa.json
   ```

3. If no other language uses its font, you can delete the font too: remove the family from `fonts:` in `pubspec.yaml`, then delete the files.

   ```bash
   git rm "assets/fonts/Vazirmatn[wght].ttf" assets/fonts/OFL-Vazirmatn.txt
   ```

   If a README names the font in its licence line, take the font out of that line too. This lists the places:

   ```bash
   git grep -n Vazirmatn
   ```

4. Check:

   ```bash
   tool/check.sh
   ```

A person who chose the removed language gets the device language, or the default, the next time the app starts.

The widget tests that look for English text pump the app in English (`english` in `test/support/test_app.dart`). To remove English, change those tests to look for text in a language you keep. Everything else, including the smoke check in `tool/check.sh`, follows the list.
