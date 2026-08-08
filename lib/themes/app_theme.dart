import 'package:flutter/material.dart';

import '../utill/app_constants.dart';
import 'app_color_schemes.dart';
import 'app_component_themes.dart';

abstract class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme => _build(AppColorSchemes.light);

  static ThemeData get darkTheme => _build(AppColorSchemes.dark);

  static ThemeData _build(ColorScheme colorScheme) {
    final bool isLight = colorScheme.brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isLight
          ? AppConstants.lightBackground
          : AppConstants.darkBackground,
      appBarTheme: AppComponentThemes.appBarTheme(colorScheme),
      cardTheme: AppComponentThemes.cardTheme(colorScheme),
      inputDecorationTheme: AppComponentThemes.inputDecorationTheme(
        colorScheme,
      ),
      elevatedButtonTheme: AppComponentThemes.elevatedButtonTheme(colorScheme),
      filledButtonTheme: AppComponentThemes.filledButtonTheme(colorScheme),
      outlinedButtonTheme: AppComponentThemes.outlinedButtonTheme(colorScheme),
      textButtonTheme: AppComponentThemes.textButtonTheme(colorScheme),
      iconButtonTheme: AppComponentThemes.iconButtonTheme(colorScheme),
      navigationBarTheme: AppComponentThemes.navigationBarTheme(colorScheme),
      bottomSheetTheme: AppComponentThemes.bottomSheetTheme(colorScheme),
      dialogTheme: AppComponentThemes.dialogTheme(colorScheme),
      dividerTheme: AppComponentThemes.dividerTheme(colorScheme),
      chipTheme: AppComponentThemes.chipTheme(colorScheme),
    );
  }
}
