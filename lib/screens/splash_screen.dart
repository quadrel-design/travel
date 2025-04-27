/**
 * Splash Screen
 *
 * Displays a simple loading indicator screen, typically shown during app
 * initialization while checking authentication state.
 */
import 'package:flutter/material.dart';

/// A stateless widget that shows a centered circular progress indicator.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
