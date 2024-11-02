// theme_model.dart, retrieves and updates light and dark color themes.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2024, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/material.dart';
import '../main.dart' show prefs;

/// This class is used to retrieve and update theme data.
class ThemeModel extends ChangeNotifier {
  ThemeModel();

  /// Return the theme based on the current light/dark setting.
  ThemeData getTheme() {
    final isDark = prefs.getBool('darktheme') ?? false;
    return isDark ? darkTheme : lightTheme;
  }

  /// Update the themes throughout the app.
  void updateTheme() {
    notifyListeners();
  }

  static final ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme.light(
      // Primary is used for highlighted text and other accents.
      primary: Colors.teal,
      onPrimary: Colors.black,
      // Secondary is used for the tree selection indicator.
      secondary: Colors.orange,
      // Tertiary is used for the drawer header.
      tertiary: Colors.blueGrey.shade900,
      onTertiary: Colors.teal.shade300,
      // Surface is the default view background.
      surface: Colors.grey.shade50,
      onSurface: Colors.black,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.teal.shade700,
      foregroundColor: Colors.white,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: Colors.blueGrey.shade100,
    ),
    cardTheme: CardTheme(
      color: Colors.grey.shade100,
    ),
    listTileTheme: ListTileThemeData(
      tileColor: Colors.grey.shade100,
      textColor: Colors.black,
      selectedTileColor: Colors.grey.shade400,
      selectedColor: Colors.black,
    ),
    useMaterial3: true,
  );

  static final ThemeData darkTheme = ThemeData(
    colorScheme: ColorScheme.dark(
      // Primary is used for highlighted text and other accents.
      primary: Colors.teal,
      onPrimary: Colors.white,
      // Secondary is used for the tree selection indicator.
      secondary: Colors.orange,
      // Tertiary is used for the drawer header.
      tertiary: Colors.teal.shade700,
      onTertiary: Colors.black,
      // Surface is the default view background.
      surface: Colors.grey.shade900,
      onSurface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white12,
      foregroundColor: Colors.teal,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: Colors.blueGrey.shade600,
    ),
    cardTheme: CardTheme(
      color: Colors.grey.shade800,
    ),
    listTileTheme: ListTileThemeData(
      tileColor: Colors.grey.shade800,
      textColor: Colors.white,
      selectedTileColor: Colors.grey.shade600,
      selectedColor: Colors.white,
    ),
    useMaterial3: true,
  );
}
