import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Use cached image provider

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onDelete; // Callback to trigger deletion

  const FullScreenImageViewer({ 
    super.key,
    required this.imageUrl,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get theme
    final dividerColor = theme.dividerColor; // Use theme divider color

    return Scaffold(
      // Use default background color
      // backgroundColor: Colors.black.withOpacity(0.85),
      appBar: AppBar(
        // backgroundColor: Colors.transparent, // Change to white
        backgroundColor: theme.colorScheme.surface, // Use theme surface color (usually white)
        foregroundColor: theme.colorScheme.onSurface, // Ensure icons are visible
        elevation: 0, // Keep shadow off
        // Add bottom border
        shape: Border(bottom: BorderSide(color: dividerColor, width: 1.0)),
      ),
      body: PhotoView(
        imageProvider: CachedNetworkImageProvider(imageUrl), 
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorBuilder: (context, error, stackTrace) => const Center(
          // Use a theme-appropriate color for the icon
          child: Icon(Icons.broken_image, color: Colors.grey),
        ),
        minScale: PhotoViewComputedScale.contained * 0.8,
        maxScale: PhotoViewComputedScale.covered * 2.0,
        heroAttributes: PhotoViewHeroAttributes(tag: imageUrl), // Match Hero tag from grid
      ),
      bottomNavigationBar: Container(
        // Add top border using Container decoration
        decoration: BoxDecoration(
           border: Border(top: BorderSide(color: dividerColor, width: 1.0)),
        ),
        child: BottomAppBar(
          // color: Colors.black.withOpacity(0.7), // Change to white
          color: theme.colorScheme.surface,
          elevation: 0, // Remove shadow if desired
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                // color: Colors.white, // Change to red
                color: theme.colorScheme.error, // Use error color from theme
                tooltip: 'Delete Image', // TODO: Localize
                onPressed: () {
                  print('[DEBUG] Delete IconButton pressed in FullScreenImageViewer');
                  onDelete(); // Call the callback passed in
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
} 