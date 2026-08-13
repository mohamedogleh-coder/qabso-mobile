import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utill/app_constants.dart';

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppConstants.lightBackground,
  colorScheme: const ColorScheme(
    brightness: Brightness.light,

    primary: AppConstants.primary,
    onPrimary: Colors.white,

    secondary: AppConstants.secondary,
    onSecondary: Colors.white,

    tertiary: AppConstants.tertiary,
    onTertiary: Colors.white,

    error: AppConstants.error,
    onError: Colors.white,

    surface: AppConstants.lightSurface,
    onSurface: AppConstants.lightTextPrimary,

    surfaceContainerHighest: AppConstants.lightBackground,

    outline: AppConstants.lightBorder,

    primaryContainer: AppConstants.primaryTint,
    onPrimaryContainer: Colors.white,

    secondaryContainer: Color(0xFFE2E8F0),
    onSecondaryContainer: AppConstants.lightTextPrimary,

    tertiaryContainer: Color(0xFFDFF3FF),
    onTertiaryContainer: AppConstants.lightTextPrimary,

    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: AppConstants.error,

    inverseSurface: AppConstants.secondary,
    onInverseSurface: Colors.white,

    inversePrimary: AppConstants.primaryHover,
    shadow: Colors.black26,
    scrim: Colors.black54,
    surfaceTint: AppConstants.primary,
  ),

  appBarTheme: const AppBarTheme(
    titleSpacing: 2,
    titleTextStyle: TextStyle(
      fontSize: 18,
      color: Colors.black,
      letterSpacing: .4,
    ),
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppConstants.lightBackground,
      systemNavigationBarIconBrightness: Brightness.dark,
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
    bodySmall: TextStyle(
      fontSize: 12,
      color: Colors.grey.shade800,
      fontWeight: FontWeight.normal,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      color: Colors.grey.shade800,
      fontWeight: FontWeight.normal,
    ),
  ),

  cardTheme: CardThemeData(
    elevation: 1,
    color: AppConstants.lightSurface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),

  hintColor: Colors.grey.shade800,
  iconTheme: const IconThemeData(color: AppConstants.darkSurface),
  dividerTheme: DividerThemeData(thickness: 0.4, color: Colors.grey.shade400),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      iconSize: 18,
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      foregroundColor: AppConstants.primary,
    ),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppConstants.primary,
      foregroundColor: AppConstants.lightSurface,
      minimumSize: const Size(double.infinity, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
    ),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppConstants.lightSurface,

    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppConstants.lightBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppConstants.primary, width: 1.5),
    ),
  ),

  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return AppConstants.tertiary.withValues(alpha: 0.2);
      }
      if (states.contains(WidgetState.selected)) {
        return AppConstants.primary;
      }
      return AppConstants.tertiary;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return AppConstants.lightSurface.withValues(alpha: 0.2);
      }
      if (states.contains(WidgetState.selected)) {
        return AppConstants.primary.withValues(alpha: 0.35);
      }
      return AppConstants.lightSurface;
    }),
  ),

  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      disabledForegroundColor: AppConstants.lightTextPrimary,
      minimumSize: const Size(32, 32),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),

  listTileTheme: const ListTileThemeData(
    titleTextStyle: TextStyle(
      fontWeight: FontWeight.bold,
      color: AppConstants.lightTextPrimary,
    ),
    subtitleTextStyle: TextStyle(
      fontSize: 12,
      color: AppConstants.lightTextPrimary,
    ),
  ),
);
