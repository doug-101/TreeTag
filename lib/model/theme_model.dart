// theme_model.dart, retrieves and updates light and dark color themes.
// TreeTag, an information storage program with an automatic tree structure.
// Copyright (c) 2023, Douglas W. Bell.
// Free software, GPL v2 or later.

import 'package:flutter/foundation.dart';
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
      primary: Colors.teal[700]!,
      secondary: Colors.teal[500]!,
    ),
    iconTheme: IconThemeData(color: Colors.teal),
  );

  static final ThemeData darkTheme = ThemeData(
    colorScheme: ColorScheme.dark(
      primary: Colors.teal[700]!,
      secondary: Colors.teal[500]!,
      onSurface: Colors.teal[200]!,
    ),
    iconTheme: IconThemeData(color: Colors.teal),
  );
}
