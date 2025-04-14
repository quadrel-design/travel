import 'package:flutter/material.dart';
import 'package:travel/theme/antonetti_theme.dart'; // Import main theme for color scheme

// InputDecoration Theme (for TextFields)
final InputDecorationTheme antonettiInputDecorationTheme = InputDecorationTheme(
  border: OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: const Color(0xFF6F7979).withAlpha(128)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: antonettiColorScheme.primary, width: 1.5),
  ),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  filled: true,
  fillColor: antonettiColorScheme.surface,
  hintStyle: TextStyle(color: const Color(0xFF3F4949).withAlpha(153)),
); 