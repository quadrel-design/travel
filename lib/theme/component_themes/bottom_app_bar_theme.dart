import 'package:flutter/material.dart';
import '../antonetti_theme.dart'; // Re-add import for color scheme access

/// Defines the custom BottomAppBarTheme for the Antonetti theme.
final BottomAppBarTheme antonettiBottomAppBarTheme = BottomAppBarTheme(
  // Use the theme's surface color (typically white or near-white)
  color: antonettiColorScheme.surface,
  // Keep it flat
  elevation: 0.0,
  // Use the default rectangular shape
  shape: null,
  // Remove horizontal padding, keep vertical if desired
  padding: EdgeInsets.symmetric(vertical: 8.0), // Only vertical padding
  // Set height to match typical AppBar height
  height: 64.0,
  // Let surface tint be handled by M3 defaults based on color
  // surfaceTintColor: Colors.transparent, // Remove explicit transparent tint
); 