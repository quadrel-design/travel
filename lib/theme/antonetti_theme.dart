import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:travel/constants/app_colors.dart'; // Use our defined colors

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

// --- Component Theme Definitions ---

// ElevatedButton Theme
final ElevatedButtonThemeData antonettiElevatedButtonTheme = ElevatedButtonThemeData(
  style: ElevatedButton.styleFrom(
    backgroundColor: antonettiColorScheme.primary,
    foregroundColor: antonettiColorScheme.onPrimary,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    textStyle: antonettiTextTheme.labelLarge, // Use defined text style
  ),
);

// Card Theme
final CardTheme antonettiCardTheme = CardTheme(
  elevation: 0, // Minimal elevation
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    side: BorderSide(color: Color(0xFFDAE5E5)), // Can be const if color is const
  ),
  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  color: antonettiColorScheme.surface, // Non-const color
);

// InputDecoration Theme (for TextFields)
final InputDecorationTheme antonettiInputDecorationTheme = InputDecorationTheme(
  // Use theme outline color for default border
  border: OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: const Color(0xFF6F7979).withAlpha(128)),
  ),
  // Keep focused border as primary color
  focusedBorder: OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: antonettiColorScheme.primary, width: 1.5),
  ),
  // Adjust padding slightly?
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  filled: true,
  fillColor: antonettiColorScheme.surface,
  // Ensure hint style is subtle
  hintStyle: TextStyle(color: const Color(0xFF3F4949).withAlpha(153)), // Hardcode onSurfaceVariant color with alpha
);

// AppBar Theme (can reuse some from previous setup)
final AppBarTheme antonettiAppBarTheme = AppBarTheme(
   backgroundColor: antonettiColorScheme.surface, // Use surface color
   foregroundColor: antonettiColorScheme.onSurface, // Text/icon color
   elevation: 0,
   // titleTextStyle: antonettiTextTheme.headlineSmall, // Apply specific style if needed
   centerTitle: true, // Keep centered based on previous setup
   shape: Border(
     bottom: BorderSide(
       color: AppColors.borderGrey,
       width: 1.0,
     ),
   ),
 );

// ListTile Theme
const ListTileThemeData antonettiListTileTheme = ListTileThemeData(
  // Customize tile appearance if needed
  // iconColor: antonettiColorScheme.primary,
  // dense: true, 
  contentPadding: EdgeInsets.symmetric(horizontal: 24),
);

// --- Main ThemeData Definition ---
final ThemeData antonettiTheme = ThemeData(
  useMaterial3: true, // Recommended for new apps
  colorScheme: antonettiColorScheme,
  textTheme: antonettiTextTheme,
  scaffoldBackgroundColor: antonettiColorScheme.surface, // Use surface for main background
  elevatedButtonTheme: antonettiElevatedButtonTheme,
  cardTheme: antonettiCardTheme,
  inputDecorationTheme: antonettiInputDecorationTheme,
  appBarTheme: antonettiAppBarTheme,
  listTileTheme: antonettiListTileTheme,
  // Apply font globally as well
  fontFamily: GoogleFonts.inter().fontFamily,
  // Customize other component themes as needed (TextButton, OutlinedButton, etc.)
); 