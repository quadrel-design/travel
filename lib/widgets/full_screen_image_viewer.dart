import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Use cached image provider
import 'package:logger/logger.dart'; // Import logger

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onDelete; // Callback to trigger deletion
  final Logger logger; // Accept logger instance
  // final Logger _logger = Logger(); // Remove local instance

  const FullScreenImageViewer({ 
    super.key,
    required this.imageUrl,
    required this.onDelete,
    required this.logger, // Require logger in constructor
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get theme
    final dividerColor = theme.dividerColor; // Use theme divider color

    return Scaffold(
      // Use default background color (usually white)
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface, // Ensure back icon is visible
        elevation: 0,
        shape: Border(bottom: BorderSide(color: dividerColor, width: 1.0)),
      ),
      body: PhotoView(
        imageProvider: CachedNetworkImageProvider(imageUrl), 
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
        minScale: PhotoViewComputedScale.contained * 0.8,
        maxScale: PhotoViewComputedScale.covered * 2.0,
        heroAttributes: PhotoViewHeroAttributes(tag: imageUrl), // Match Hero tag from grid
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
           border: Border(top: BorderSide(color: dividerColor, width: 1.0)),
        ),
        child: BottomAppBar(
          color: theme.colorScheme.surface,
          elevation: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: theme.colorScheme.error,
                tooltip: 'Delete Image', // TODO: Localize
                onPressed: () {
                  logger.d('Delete IconButton pressed in FullScreenImageViewer');
                  onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
} 