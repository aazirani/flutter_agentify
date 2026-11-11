import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Light ──────────────────────────────────────────────
  static const Color lightPrimary = Color(0xFF6750A4);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFFEADDFF);
  static const Color lightOnPrimaryContainer = Color(0xFF21005D);

  static const Color lightSecondary = Color(0xFF625B71);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightSecondaryContainer = Color(0xFFE8DEF8);
  static const Color lightOnSecondaryContainer = Color(0xFF1D192B);

  static const Color lightTertiary = Color(0xFF7D5260);
  static const Color lightOnTertiary = Color(0xFFFFFFFF);
  static const Color lightTertiaryContainer = Color(0xFFFFD8E4);
  static const Color lightOnTertiaryContainer = Color(0xFF31111D);

  static const Color lightError = Color(0xFFB3261E);
  static const Color lightOnError = Color(0xFFFFFFFF);
  static const Color lightErrorContainer = Color(0xFFF9DEDC);
  static const Color lightOnErrorContainer = Color(0xFF410E0B);

  static const Color lightSurface = Color(0xFFFFFBFE);
  static const Color lightOnSurface = Color(0xFF1C1B1F);
  static const Color lightSurfaceContainer = Color(0xFFF3EDF7);
  static const Color lightSurfaceContainerHigh = Color(0xFFECE6F0);
  static const Color lightSurfaceContainerHighest = Color(0xFFE6E0E9);
  static const Color lightSurfaceContainerLow = Color(0xFFF7F2FA);
  static const Color lightSurfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color lightOnSurfaceVariant = Color(0xFF49454F);

  static const Color lightOutline = Color(0xFF79747E);
  static const Color lightOutlineVariant = Color(0xFFCAC4D0);
  static const Color lightInverseSurface = Color(0xFF313033);
  static const Color lightInverseOnSurface = Color(0xFFF4EFF4);
  static const Color lightInversePrimary = Color(0xFFD0BCFF);

  static const Color lightShadow = Color(0xFF000000);
  static const Color lightScrim = Color(0xFF000000);

  // ─── Dark ──────────────────────────────────────────────
  static const Color darkPrimary = Color(0xFFD0BCFF);
  static const Color darkOnPrimary = Color(0xFF381E72);
  static const Color darkPrimaryContainer = Color(0xFF4F378B);
  static const Color darkOnPrimaryContainer = Color(0xFFEADDFF);

  static const Color darkSecondary = Color(0xFFCCC2DC);
  static const Color darkOnSecondary = Color(0xFF332D41);
  static const Color darkSecondaryContainer = Color(0xFF4A4458);
  static const Color darkOnSecondaryContainer = Color(0xFFE8DEF8);

  static const Color darkTertiary = Color(0xFFEFB8C8);
  static const Color darkOnTertiary = Color(0xFF492532);
  static const Color darkTertiaryContainer = Color(0xFF633B48);
  static const Color darkOnTertiaryContainer = Color(0xFFFFD8E4);

  static const Color darkError = Color(0xFFF2B8B5);
  static const Color darkOnError = Color(0xFF601410);
  static const Color darkErrorContainer = Color(0xFF8C1D18);
  static const Color darkOnErrorContainer = Color(0xFFF9DEDC);

  static const Color darkSurface = Color(0xFF1C1B1F);
  static const Color darkOnSurface = Color(0xFFE6E1E5);
  static const Color darkSurfaceContainer = Color(0xFF211F26);
  static const Color darkSurfaceContainerHigh = Color(0xFF2B2930);
  static const Color darkSurfaceContainerHighest = Color(0xFF36343B);
  static const Color darkSurfaceContainerLow = Color(0xFF1D1B20);
  static const Color darkSurfaceContainerLowest = Color(0xFF0F0D13);
  static const Color darkOnSurfaceVariant = Color(0xFFCAC4D0);

  static const Color darkOutline = Color(0xFF938F99);
  static const Color darkOutlineVariant = Color(0xFF49454F);
  static const Color darkInverseSurface = Color(0xFFE6E1E5);
  static const Color darkInverseOnSurface = Color(0xFF313033);
  static const Color darkInversePrimary = Color(0xFF6750A4);

  static const Color darkShadow = Color(0xFF000000);
  static const Color darkScrim = Color(0xFF000000);

  // ─── Light Scheme ──────────────────────────────────────
  static ColorScheme lightScheme = const ColorScheme.light(
    primary: lightPrimary,
    onPrimary: lightOnPrimary,
    primaryContainer: lightPrimaryContainer,
    onPrimaryContainer: lightOnPrimaryContainer,
    secondary: lightSecondary,
    onSecondary: lightOnSecondary,
    secondaryContainer: lightSecondaryContainer,
    onSecondaryContainer: lightOnSecondaryContainer,
    tertiary: lightTertiary,
    onTertiary: lightOnTertiary,
    tertiaryContainer: lightTertiaryContainer,
    onTertiaryContainer: lightOnTertiaryContainer,
    error: lightError,
    onError: lightOnError,
    errorContainer: lightErrorContainer,
    onErrorContainer: lightOnErrorContainer,
    surface: lightSurface,
    onSurface: lightOnSurface,
    surfaceContainerHighest: lightSurfaceContainerHighest,
    surfaceContainerHigh: lightSurfaceContainerHigh,
    surfaceContainer: lightSurfaceContainer,
    surfaceContainerLow: lightSurfaceContainerLow,
    surfaceContainerLowest: lightSurfaceContainerLowest,
    onSurfaceVariant: lightOnSurfaceVariant,
    outline: lightOutline,
    outlineVariant: lightOutlineVariant,
    inverseSurface: lightInverseSurface,
    onInverseSurface: lightInverseOnSurface,
    inversePrimary: lightInversePrimary,
    shadow: lightShadow,
    scrim: lightScrim,
  );

  // ─── Dark Scheme ───────────────────────────────────────
  static ColorScheme darkScheme = const ColorScheme.dark(
    primary: darkPrimary,
    onPrimary: darkOnPrimary,
    primaryContainer: darkPrimaryContainer,
    onPrimaryContainer: darkOnPrimaryContainer,
    secondary: darkSecondary,
    onSecondary: darkOnSecondary,
    secondaryContainer: darkSecondaryContainer,
    onSecondaryContainer: darkOnSecondaryContainer,
    tertiary: darkTertiary,
    onTertiary: darkOnTertiary,
    tertiaryContainer: darkTertiaryContainer,
    onTertiaryContainer: darkOnTertiaryContainer,
    error: darkError,
    onError: darkOnError,
    errorContainer: darkErrorContainer,
    onErrorContainer: darkOnErrorContainer,
    surface: darkSurface,
    onSurface: darkOnSurface,
    surfaceContainerHighest: darkSurfaceContainerHighest,
    surfaceContainerHigh: darkSurfaceContainerHigh,
    surfaceContainer: darkSurfaceContainer,
    surfaceContainerLow: darkSurfaceContainerLow,
    surfaceContainerLowest: darkSurfaceContainerLowest,
    onSurfaceVariant: darkOnSurfaceVariant,
    outline: darkOutline,
    outlineVariant: darkOutlineVariant,
    inverseSurface: darkInverseSurface,
    onInverseSurface: darkInverseOnSurface,
    inversePrimary: darkInversePrimary,
    shadow: darkShadow,
    scrim: darkScrim,
  );

  // ─── Theme Extensions ──────────────────────────────────
  static SemanticColors lightSemanticColors = const SemanticColors(
    success: Color(0xFF4CAF50),
    warning: Color(0xFFFF9800),
    info: Color(0xFF2196F3),
    muted: Color(0xFF9E9E9E),
    disabled: Color(0xFFBDBDBD),
  );

  static SemanticColors darkSemanticColors = const SemanticColors(
    success: Color(0xFF66BB6A),
    warning: Color(0xFFFFA726),
    info: Color(0xFF42A5F5),
    muted: Color(0xFF757575),
    disabled: Color(0xFF616161),
  );
}

class SemanticColors extends ThemeExtension<SemanticColors> {
  final Color success;
  final Color warning;
  final Color info;
  final Color muted;
  final Color disabled;

  const SemanticColors({
    required this.success,
    required this.warning,
    required this.info,
    required this.muted,
    required this.disabled,
  });

  @override
  SemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? info,
    Color? muted,
    Color? disabled,
  }) {
    return SemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      muted: muted ?? this.muted,
      disabled: disabled ?? this.disabled,
    );
  }

  @override
  SemanticColors lerp(covariant SemanticColors? other, double t) {
    if (other is! SemanticColors) return this;
    return SemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      disabled: Color.lerp(disabled, other.disabled, t)!,
    );
  }
}
