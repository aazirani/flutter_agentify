import 'package:flutter/material.dart';
import 'package:flutter_agentify/domain/entities/language/language.dart';
import 'package:flutter_agentify/domain/entities/language/supported_languages.dart';

/// Complete typography system for app.
/// Each language's font comes from its entry in `kSupportedLanguages`.
///
/// Typography Scale:
/// - Display: Hero headlines (57, 45, 36px)
/// - Headline: Screen/Section titles (32, 28, 24px)
/// - Title: List items, navigation (22, 16, 14px)
/// - Body: Content text (16, 14, 12px)
/// - Label: Buttons, tags, hints (14, 12, 11px)
class AppTypography {
  AppTypography._();

  // ═══════════════════════════════════════════════════════════════════════════
  // LOCALE-AWARE FONT SYSTEM
  // ═══════════════════════════════════════════════════════════════════════════

  /// The language whose font the styles use. Defaults to the app's default
  /// language (the first in `kSupportedLanguages`).
  static Language _language = languageFor(null);

  /// Set the current locale for font selection; an unlisted or null one
  /// means the default language. Call this when the language changes.
  static void setLocale(String? locale) {
    _language = languageFor(locale);
  }

  /// Get the current locale
  static String get currentLocale => _language.locale;

  /// Primary font family for UI text - locale-aware
  static TextStyle get _interBase =>
      TextStyle(fontFamily: _language.fontFamily);

  /// Get fallback fonts for the current locale
  static List<String> get _currentFallbacks => _language.fontFallbacks;

  // ═══════════════════════════════════════════════════════════════════════════
  // DISPLAY SCALE - Hero headlines
  // ═══════════════════════════════════════════════════════════════════════════

  /// Display Large - 57px / 64px / w600
  /// Use for: Hero headlines, splash screens
  static TextStyle displayLarge([Color? color]) => _interBase.copyWith(
    fontSize: 57,
    height: 1.12, // 64/57
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    color: color,
    fontFamilyFallback: _currentFallbacks,
  );

  /// Display Medium - 45px / 52px / w600
  /// Use for: Section heroes, feature highlights
  static TextStyle displayMedium([Color? color]) => _interBase.copyWith(
    fontSize: 45,
    height: 1.16, // 52/45
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: color,
    fontFamilyFallback: _currentFallbacks,
  );

  /// Display Small - 36px / 44px / w600
  /// Use for: Large titles, onboarding headers
  static TextStyle displaySmall([Color? color]) => _interBase.copyWith(
    fontSize: 36,
    height: 1.22, // 44/36
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: color,
    fontFamilyFallback: _currentFallbacks,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADLINE SCALE - Screen/Section titles
  // ═══════════════════════════════════════════════════════════════════════════

  /// Headline Large - 32px / 40px / w600
  /// Use for: Screen titles, major section headers
  static TextStyle headlineLarge([Color? color]) => _interBase.copyWith(
    fontSize: 32,
    height: 1.25, // 40/32
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: color,
    fontFamilyFallback: _currentFallbacks,
  );

  /// Headline Medium - 28px / 36px / w600
  /// Use for: Card titles, secondary section headers
  static TextStyle headlineMedium([Color? color]) => _interBase.copyWith(
    fontSize: 28,
    height: 1.29, // 36/28
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: color,
    fontFamilyFallback: _currentFallbacks,
  );

  /// Headline Small - 24px / 32px / w600
  /// Use for: Section headers, dialog titles
  static TextStyle headlineSmall([Color? color]) => _interBase.copyWith(
    fontSize: 24,
    height: 1.33, // 32/24
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: color,
    fontFamilyFallback: _currentFallbacks,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // TITLE SCALE - List items, navigation
  // ═══════════════════════════════════════════════════════════════════════════

  /// Title Large - 22px / 28px / w500
  /// Use for: List item titles, navigation items
  static TextStyle titleLarge([Color? color]) => _interBase.copyWith(
    fontSize: 22,
    height: 1.27, // 28/22
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    color: color,
    fontFamilyFallback: _currentFallbacks,
  );

  /// Title Medium - 16px / 24px / w500
  /// Use for: Card subtitles, tab labels
  static TextStyle titleMedium([Color? color]) => _interBase.copyWith(
    fontSize: 16,
    height: 1.50, // 24/16
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
    color: color,
    fontFamilyFallback: _currentFallbacks,
  );

  /// Title Small - 14px / 20px / w500
  /// Use for: Navigation labels, small section headers
  static TextStyle titleSmall([Color? color]) => _interBase.copyWith(
    fontSize: 14,
    height: 1.43, // 20/14
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: color,
    fontFamilyFallback: _currentFallbacks,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // BODY SCALE - Content text
  // ═══════════════════════════════════════════════════════════════════════════

  /// Body Large - 16px / 24px / w400
  /// Use for: Primary content, chat messages
  static TextStyle bodyLarge([Color? color]) => _interBase.copyWith(
    fontSize: 16,
    height: 1.50, // 24/16
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    color: color,
    fontFamilyFallback: _currentFallbacks,
  );

  /// Body Medium - 14px / 20px / w400
  /// Use for: Secondary content, descriptions
  static TextStyle bodyMedium([Color? color]) => _interBase.copyWith(
    fontSize: 14,
    height: 1.43, // 20/14
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    color: color,
    fontFamilyFallback: _currentFallbacks,
  );

  /// Body Small - 12px / 16px / w400
  /// Use for: Captions, hints, metadata
  static TextStyle bodySmall([Color? color]) => _interBase.copyWith(
    fontSize: 12,
    height: 1.33, // 16/12
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    color: color,
    fontFamilyFallback: _currentFallbacks,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // LABEL SCALE - Buttons, tags, hints
  // ═══════════════════════════════════════════════════════════════════════════

  /// Label Large - 14px / 20px / w500
  /// Use for: Button text, prominent labels
  static TextStyle labelLarge([Color? color]) => _interBase.copyWith(
    fontSize: 14,
    height: 1.43, // 20/14
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: color,
    fontFamilyFallback: _currentFallbacks,
  );

  /// Label Medium - 12px / 16px / w500
  /// Use for: Tags, chips, input labels
  static TextStyle labelMedium([Color? color]) => _interBase.copyWith(
    fontSize: 12,
    height: 1.33, // 16/12
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: color,
    fontFamilyFallback: _currentFallbacks,
  );

  /// Label Small - 11px / 16px / w500
  /// Use for: Overlines, status labels, timestamps
  static TextStyle labelSmall([Color? color]) => _interBase.copyWith(
    fontSize: 11,
    height: 1.45, // 16/11
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: color,
    fontFamilyFallback: _currentFallbacks,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // TEXT THEME BUILDER
  // ═══════════════════════════════════════════════════════════════════════════

  /// Creates a complete TextTheme using the app's typography system
  static TextTheme textTheme([Color? defaultColor]) {
    return TextTheme(
      displayLarge: displayLarge(defaultColor),
      displayMedium: displayMedium(defaultColor),
      displaySmall: displaySmall(defaultColor),
      headlineLarge: headlineLarge(defaultColor),
      headlineMedium: headlineMedium(defaultColor),
      headlineSmall: headlineSmall(defaultColor),
      titleLarge: titleLarge(defaultColor),
      titleMedium: titleMedium(defaultColor),
      titleSmall: titleSmall(defaultColor),
      bodyLarge: bodyLarge(defaultColor),
      bodyMedium: bodyMedium(defaultColor),
      bodySmall: bodySmall(defaultColor),
      labelLarge: labelLarge(defaultColor),
      labelMedium: labelMedium(defaultColor),
      labelSmall: labelSmall(defaultColor),
    );
  }

  /// Creates a primary text theme with colors from the color scheme
  static TextTheme primaryTextTheme(ColorScheme colorScheme) {
    return textTheme(colorScheme.onPrimary);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SPECIALTY STYLES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Quote style - for quoted/referenced text
  static TextStyle quote([Color? color]) => _interBase.copyWith(
    fontSize: 14,
    height: 1.43,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    letterSpacing: 0.25,
    color: color,
    fontFamilyFallback: _currentFallbacks,
  );

  /// Link style - for URLs and clickable text
  static TextStyle link([Color? color]) => _interBase.copyWith(
    fontSize: 14,
    height: 1.43,
    fontWeight: FontWeight.w500,
    decoration: TextDecoration.underline,
    decorationColor: color,
    color: color,
    fontFamilyFallback: _currentFallbacks,
  );

  /// Overline style - for category labels
  static TextStyle overline([Color? color]) => _interBase.copyWith(
    fontSize: 10,
    height: 1.60, // 16/10
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    color: color,
    fontFamilyFallback: _currentFallbacks,
  );
}
