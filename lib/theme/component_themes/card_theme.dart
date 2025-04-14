import 'package:flutter/material.dart';

// Card Theme
final CardTheme antonettiCardTheme = CardTheme(
  elevation: 0, // Minimal elevation
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(8.0)), // Use 8.0 radius
    // No border side needed
  ),
  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  color: Colors.white, // Use white color
); 