import 'language.dart';

/// The languages the app ships translations for: the one place that defines
/// them. The first entry is the default, used when the device language is not
/// in the list. Each needs `assets/lang/<locale>.json`.
const List<Language> kSupportedLanguages = [
  Language(
    locale: 'en',
    language: 'English',
    englishName: 'English',
    flagEmoji: '🇺🇸',
    fontFamily: 'Inter',
    fontFallbacks: ['Inter', 'Roboto', 'sans-serif'],
  ),
  Language(
    locale: 'fa',
    language: 'فارسی',
    englishName: 'Persian',
    flagEmoji: '🇮🇷',
    fontFamily: 'Vazirmatn',
    fontFallbacks: ['Vazirmatn', 'Tahoma', 'sans-serif'],
  ),
];

/// The entry for [locale], or the default (first) one when it is not listed.
Language languageFor(String? locale) => kSupportedLanguages.firstWhere(
  (l) => l.locale == locale,
  orElse: () => kSupportedLanguages.first,
);
