import 'package:flutter/material.dart';
import 'package:travel/theme/antonetti_theme.dart'; // Import main theme for color scheme

// InputDecoration Theme (for TextFields)
final InputDecorationTheme antonettiInputDecorationTheme = InputDecorationTheme(
  // Default border
  border: OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: antonettiColorScheme.outline.withOpacity(0.5)), // Use withOpacity correctly
  ),
  // Border when the field is enabled (optional, often same as default)
  enabledBorder: OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: antonettiColorScheme.outline.withOpacity(0.5)), // Use withOpacity correctly
  ),
  // Border when the field has focus
  focusedBorder: OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: antonettiColorScheme.primary, width: 1.5), // Primary color, thicker
  ),
  // Border when the field has an error
  errorBorder: OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: antonettiColorScheme.error, width: 1.0), // Error color
  ),
  // Border when the field has focus AND an error
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: antonettiColorScheme.error, width: 1.5), // Error color, thicker
  ),
  // Style for the error text displayed below the field
  errorStyle: TextStyle(color: antonettiColorScheme.error, fontSize: 12),
  // Style for the label when it floats above the field (if using labels)
  labelStyle: TextStyle(color: antonettiColorScheme.onSurfaceVariant),
  // Style for the hint text inside the field
  hintStyle: TextStyle(color: antonettiColorScheme.onSurfaceVariant.withOpacity(0.6)), // Use withOpacity correctly
  // Padding inside the field
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  // Background fill
  filled: true,
  fillColor: antonettiColorScheme.surfaceContainerHighest, // Use a slightly different surface color for fill
); 