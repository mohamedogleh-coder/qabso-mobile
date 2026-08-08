import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utill/app_constants.dart';

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppConstants.darkBackground,
  colorScheme: const ColorScheme(
    brightness: Brightness.dark,

    primary: AppConstants.primaryHover,
    onPrimary: Colors.white,

    secondary: AppConstants.secondary,
    onSecondary: Colors.white,

    tertiary: AppConstants.tertiary,
    onTertiary: Colors.white,

    error: AppConstants.error,
    onError: Colors.white,

    surface: AppConstants.darkSurface,
    onSurface: AppConstants.darkTextPrimary,

    surfaceContainerHighest: AppConstants.darkBackground,

    outline: AppConstants.darkBorder,

    primaryContainer: AppConstants.primaryTint,
    onPrimaryContainer: AppConstants.darkTextPrimary,

    secondaryContainer: Color(0xFF334155),
    onSecondaryContainer: AppConstants.darkTextPrimary,

    tertiaryContainer: Color(0xFF0C4A6E),
    onTertiaryContainer: AppConstants.darkTextPrimary,

    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: AppConstants.darkTextPrimary,

    inverseSurface: AppConstants.lightSurface,
    onInverseSurface: AppConstants.lightTextPrimary,

    inversePrimary: AppConstants.primary,

    shadow: Colors.black,
    scrim: Colors.black,

    surfaceTint: AppConstants.primaryHover,
  ),

  appBarTheme: const AppBarTheme(
    titleTextStyle: TextStyle(
      fontSize: 18,
      color: Colors.white,
      letterSpacing: .4,
    ),
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppConstants.darkBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
    actionsPadding: EdgeInsets.symmetric(horizontal: 12),
  ),

  textTheme: TextTheme(
    headlineLarge: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      letterSpacing: .4,
    ),
    headlineMedium: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: .4,
    ),
    bodySmall: TextStyle(fontSize: 12, color: Colors.grey.shade300),
    labelMedium: TextStyle(
      fontSize: 12,
      color: Colors.grey.shade300,
      fontWeight: FontWeight.normal,
    ),
  ),

  cardTheme: CardThemeData(
    elevation: 1,
    color: AppConstants.darkSurface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      iconSize: 18,
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      foregroundColor: AppConstants.primary,
    ),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      minimumSize: const Size(double.infinity, 45),
      backgroundColor: AppConstants.primary,
      foregroundColor: AppConstants.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
    ),
  ),

  hintColor: Colors.grey.shade300,
  iconTheme: const IconThemeData(color: AppConstants.lightSurface),
  dividerTheme: DividerThemeData(thickness: 0.4, color: Colors.grey.shade800),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppConstants.darkSurface,
    // labelStyle: const TextStyle(
    //   color: AppConstants.darkTextPrimary,
    //   fontSize: 13,
    // ),
    // helperStyle: const TextStyle(
    //   fontSize: 13,
    //   color: AppConstants.lightTextMuted,
    // ),
    // hintStyle: const TextStyle(
    //   color: AppConstants.darkTextPrimary,
    //   fontSize: 13,
    // ),

    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppConstants.primary, width: 1.5),
    ),
  ),

  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return AppConstants.tertiary.withValues(alpha: 0.5);
      }
      if (states.contains(WidgetState.selected)) {
        return AppConstants.primary;
      }
      return AppConstants.tertiary;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return AppConstants.lightSurface.withValues(alpha: 0.5);
      }
      if (states.contains(WidgetState.selected)) {
        return AppConstants.primary.withValues(alpha: 0.35);
      }
      return AppConstants.lightSurface;
    }),
  ),

  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      // backgroundColor: AppConstants.tertiary,
      // foregroundColor: AppConstants.lightSurface,
      // disabledBackgroundColor: AppConstants.darkSurface,
      // disabledForegroundColor: AppConstants.darkTextPrimary,
      minimumSize: const Size(32, 32),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),

  listTileTheme: const ListTileThemeData(
    titleTextStyle: TextStyle(fontWeight: FontWeight.bold),
    subtitleTextStyle: TextStyle(fontSize: 12),
  ),
);
