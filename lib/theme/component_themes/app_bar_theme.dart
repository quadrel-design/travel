import 'package:flutter/material.dart';
import 'package:travel/theme/antonetti_theme.dart'; // Import main theme for color scheme
import 'package:travel/constants/app_colors.dart'; // Import app colors for border

// AppBar Theme
final AppBarTheme antonettiAppBarTheme = AppBarTheme(
  backgroundColor: antonettiColorScheme.surface,
  foregroundColor: antonettiColorScheme.onSurface,
  elevation: 0,
  centerTitle: true,
  shape: Border(
    bottom: BorderSide(
      color: AppColors.borderGrey,
      width: 1.0,
    ),
  ),
); 