import 'package:flutter/material.dart';

/// A reusable footer widget typically placed in Scaffold.bottomNavigationBar.
class AppFooterBar extends StatelessWidget {
  const AppFooterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Remove hardcoded grey
    // final lightGrey = Colors.grey.shade300; 

    // BottomAppBar automatically uses the BottomAppBarTheme defined in the main theme
    return BottomAppBar(
      // Wrap child in a Container to apply the top border
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            // Use the new theme color for the border
            top: BorderSide(color: theme.colorScheme.outlineVariant, width: 1.0),
          ),
        ),
        // Use a SizedBox or keep the Row if content might be added later
        // If keeping Row, adjust alignment/children
        child: const SizedBox.shrink(), // Empty content for now
        // Example with Row (if you plan to add content):
        // child: Row(
        //   mainAxisAlignment: MainAxisAlignment.center, // Or other alignment
        //   children: [
        //     // Future content goes here
        //   ],
        // ),
      ),
    );
  }
} 