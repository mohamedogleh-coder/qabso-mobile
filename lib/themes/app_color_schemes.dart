import 'package:flutter/material.dart';

import '../utill/app_constants.dart';

/// Builds the light and dark Material 3 [ColorScheme]s for the app.
///
/// Each brand color family (primary / secondary / tertiary / error) is run
/// through [ColorScheme.fromSeed] on its own, so its container and "on"
/// colors are tonally harmonized with that color's own hue instead of the
/// primary hue. The resulting scheme's `primary` slot is then borrowed into
/// the matching role below, which is what lets [ColorScheme.secondary] stay
/// slate-toned and [ColorScheme.tertiary] stay sky-toned rather than both
/// collapsing into muted greens.
abstract class AppColorSchemes {
  const AppColorSchemes._();

  static ColorScheme get light => _build(Brightness.light);

  static ColorScheme get dark => _build(Brightness.dark);

  static ColorScheme _build(Brightness brightness) {
    final bool isLight = brightness == Brightness.light;

    final ColorScheme primaryFamily = ColorScheme.fromSeed(
      seedColor: AppConstants.primary,
      brightness: brightness,
    );
    final ColorScheme secondaryFamily = ColorScheme.fromSeed(
      seedColor: AppConstants.secondary,
      brightness: brightness,
    );
    final ColorScheme tertiaryFamily = ColorScheme.fromSeed(
      seedColor: AppConstants.tertiary,
      brightness: brightness,
    );
    final ColorScheme errorFamily = ColorScheme.fromSeed(
      seedColor: AppConstants.error,
      brightness: brightness,
    );

    return primaryFamily.copyWith(
      // Primary: pinned to the exact brand color in light mode. In dark
      // mode the tone-adjusted value from `fromSeed` is kept instead, since
      // a flat re-use of the light-mode green falls short of AA contrast
      // against dark surfaces.
      primary: isLight ? AppConstants.primary : primaryFamily.primary,
      onPrimary: primaryFamily.onPrimary,
      primaryContainer: primaryFamily.primaryContainer,
      onPrimaryContainer: isLight
          ? AppConstants.primaryTint
          : primaryFamily.onPrimaryContainer,

      // Secondary: the brand's dark-slate color, with its container family
      // borrowed from a scheme seeded on that same slate hue.
      secondary: isLight ? AppConstants.secondary : secondaryFamily.primary,
      onSecondary:
          isLight ? AppConstants.lightSurface : secondaryFamily.onPrimary,
      secondaryContainer: isLight
          ? AppConstants.lightBorder
          : secondaryFamily.primaryContainer,
      onSecondaryContainer: isLight
          ? AppConstants.lightTextPrimary
          : secondaryFamily.onPrimaryContainer,

      // Tertiary: the existing sky-blue accent already defined in
      // AppConstants, which reads as a natural complement to the green
      // primary and slate secondary without competing with either.
      tertiary: isLight ? AppConstants.tertiary : tertiaryFamily.primary,
      onTertiary: tertiaryFamily.onPrimary,
      tertiaryContainer: tertiaryFamily.primaryContainer,
      onTertiaryContainer: tertiaryFamily.onPrimaryContainer,

      // Error: the brand's red, harmonized the same way as secondary/tertiary.
      error: isLight ? AppConstants.error : errorFamily.primary,
      onError: errorFamily.onPrimary,
      errorContainer: errorFamily.primaryContainer,
      onErrorContainer: errorFamily.onPrimaryContainer,

      // Surface: the existing light/dark surface constants already encode
      // the intended elevation strategy, so they take priority over the
      // algorithmically tinted defaults.
      surface: isLight ? AppConstants.lightSurface : AppConstants.darkSurface,
      onSurface: isLight
          ? AppConstants.lightTextPrimary
          : AppConstants.darkTextPrimary,
      onSurfaceVariant: isLight
          ? AppConstants.lightTextMuted
          : AppConstants.darkTextMuted,
      outline: isLight ? AppConstants.lightBorder : AppConstants.darkBorder,
      surfaceContainer: primaryFamily.surfaceContainer,
      surfaceContainerHighest: primaryFamily.surfaceContainerHighest,
    );
  }
}
