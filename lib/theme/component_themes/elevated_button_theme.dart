import 'package:flutter/material.dart';
import 'package:travel/theme/antonetti_theme.dart'; // Import main theme for color scheme and text theme

// ElevatedButton Theme
final ElevatedButtonThemeData antonettiElevatedButtonTheme = ElevatedButtonThemeData(
  style: ElevatedButton.styleFrom(
    backgroundColor: antonettiColorScheme.primary, // Reference ColorScheme
    foregroundColor: antonettiColorScheme.onPrimary,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    textStyle: antonettiTextTheme.labelLarge, // Reference TextTheme
  ),
); 