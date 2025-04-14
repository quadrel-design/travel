import 'package:flutter/material.dart';

class FullScreenConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final String cancelText;

  const FullScreenConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmText = 'Delete', // Default texts
    this.cancelText = 'Cancel',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      // Use default background color (usually white)
      backgroundColor: theme.colorScheme.surface,
      body: Center( // Center the main content column
        child: Padding(
          padding: const EdgeInsets.all(32.0), // Add padding around content
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Center vertically
            mainAxisSize: MainAxisSize.min, // Take minimum space needed
            children: [
              Text(
                title,
                // Use default text colors
                style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                content,
                // Use default text colors
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      // Use Persistent Footer Buttons for bottom alignment
      persistentFooterButtons: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end, // Align buttons to the right
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Return false on cancel
              child: Text(cancelText),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // Return true on confirm
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error, // Error color for delete
              ),
              child: Text(confirmText),
            ),
          ],
        )
      ],
      persistentFooterAlignment: AlignmentDirectional.bottomEnd,
    );
  }
} 