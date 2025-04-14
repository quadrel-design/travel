import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Import component theme files
import 'component_themes/app_bar_theme.dart';
import 'component_themes/card_theme.dart';
import 'component_themes/elevated_button_theme.dart';
import 'component_themes/input_decoration_theme.dart';
import 'component_themes/list_tile_theme.dart';

// --- Color Scheme Definition ---
const ColorScheme antonettiColorScheme = ColorScheme(
  brightness: Brightness.light,
  // Define your primary brand color
  primary: Color(0xFF006A6A), // Example: Teal
  onPrimary: Colors.white,
  // Define secondary/accent color
  secondary: Color(0xFF4A6363),
  onSecondary: Colors.white,
  // Error color
  error: Color(0xFFBA1A1A),
  onError: Colors.white,
  // Background/Surface colors
  surface: Color(0xFFFAFDFC),
  onSurface: Color(0xFF191C1C),
  // Add other variants if needed (surfaceVariant, outline, etc.)
  surfaceContainerHighest: Color(0xFFDAE5E5),
  outline: Color(0xFF6F7979),
  onSurfaceVariant: Color(0xFF3F4949),
);

// --- Text Theme Definition ---
// Start with default Material text theme and apply Inter font
final TextTheme defaultTextTheme = ThemeData.light().textTheme;
final TextTheme antonettiTextTheme = GoogleFonts.interTextTheme(defaultTextTheme).copyWith(
  // Optionally override specific styles further
  bodyMedium: GoogleFonts.inter(fontSize: 14), // Example: ensure specific size
  labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold), // Example: Button text
);

// --- Main ThemeData Definition ---
final ThemeData antonettiTheme = ThemeData(
  useMaterial3: true, // Recommended for new apps
  colorScheme: antonettiColorScheme,
  textTheme: antonettiTextTheme,
  scaffoldBackgroundColor: antonettiColorScheme.surface, // Use surface for main background
  // Use imported component themes
  elevatedButtonTheme: antonettiElevatedButtonTheme,
  cardTheme: antonettiCardTheme,
  inputDecorationTheme: antonettiInputDecorationTheme,
  appBarTheme: antonettiAppBarTheme,
  listTileTheme: antonettiListTileTheme,
  // Apply font globally as well
  fontFamily: GoogleFonts.inter().fontFamily,
  // Customize other component themes as needed (TextButton, OutlinedButton, etc.)
); 