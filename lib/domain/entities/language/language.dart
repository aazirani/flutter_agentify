/// One language the app ships, with everything that differs per language.
/// Text direction is not here: Flutter derives it from [locale].
class Language {
  /// The locale code (en, fa); its strings are in `assets/lang/<locale>.json`.
  final String locale;

  /// The native name of the language (English, فارسی)
  final String language;

  /// The English name for sorting and accessibility
  final String englishName;

  /// Flag emoji for visual recognition
  final String flagEmoji;

  /// The font family for the language's text, declared in `pubspec.yaml`.
  final String fontFamily;

  /// Fonts tried, in order, for characters [fontFamily] lacks.
  final List<String> fontFallbacks;

  const Language({
    required this.locale,
    required this.language,
    required this.englishName,
    required this.flagEmoji,
    required this.fontFamily,
    required this.fontFallbacks,
  });
}
