import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Reusable Widget for AppBar Title with Logo
class AppTitle extends StatelessWidget {
  const AppTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/travel_logo.png',
          height: 30,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.image_not_supported, size: 30),
        ),
        const SizedBox(width: 8),
        Text(
          'TravelMouse',
          style: GoogleFonts.inter(
            color: Colors.black, 
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
} 