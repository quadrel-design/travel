import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:logger/logger.dart'; // Import logger
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
// import 'photo_app_bar.dart'; // Remove import
// import 'full_screen_image_viewer.dart'; // Not needed anymore

class GalleryPageView extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final Future<void> Function(String) onDeleteImage; // Expects original URL
  final Function(String) onImageDeletedSuccessfully; // Callback with original URL
  final Logger logger; // Receive logger instance

  const GalleryPageView({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
    required this.onDeleteImage,
    required this.onImageDeletedSuccessfully,
    required this.logger, // Add logger to constructor
  });

  @override
  State<GalleryPageView> createState() => _GalleryPageViewState();
}

class _GalleryPageViewState extends State<GalleryPageView> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isDeleting = false; // Track deletion state

  // --- State for Signed URLs ---
  List<String?> _signedUrls = []; // Store signed URLs (nullable for errors)
  bool _isLoadingSignedUrls = true;
  String? _signedUrlError;
  // --- End State for Signed URLs ---

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    // Fetch signed URLs when the widget initializes
    _fetchSignedUrls();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- Signed URL Logic Start ---
  // Helper to extract path from URL (same as in gallery screen)
  String? _extractPath(String url) {
    try {
      final uri = Uri.parse(url);
      final bucketName = 'journey_images'; // Ensure this matches
      final pathStartIndex = uri.path.indexOf(bucketName) + bucketName.length + 1;
      if (pathStartIndex <= bucketName.length) return null;
      return uri.path.substring(pathStartIndex);
    } catch (e) {
      widget.logger.e('Failed to parse path from URL: $url', error: e);
      return null;
    }
  }

  // Function to generate signed URL
  Future<String> _generateSignedUrl(String imagePath) async {
    try {
      final result = await Supabase.instance.client.storage
          .from('journey_images')
          .createSignedUrl(imagePath, 3600); // 1 hour expiry
      return result;
    } catch (e) {
       widget.logger.e('Error generating signed URL for $imagePath', error: e);
       rethrow; // Re-throw to be caught by _fetchSignedUrls
    }
  }

  // Fetch all signed URLs upfront
  Future<void> _fetchSignedUrls() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSignedUrls = true;
      _signedUrlError = null;
      _signedUrls = List.filled(widget.imageUrls.length, null); // Initialize with nulls
    });

    List<String?> results = [];
    bool hadError = false;
    for (final originalUrl in widget.imageUrls) {
      final path = _extractPath(originalUrl);
      if (path == null) {
        widget.logger.w('Could not extract path for $originalUrl');
        results.add(null); // Mark as error
        hadError = true;
        continue;
      }
      try {
        final signedUrl = await _generateSignedUrl(path);
        results.add(signedUrl);
      } catch (e) {
        results.add(null); // Mark as error
        hadError = true;
      }
    }

    if (!mounted) return;
    setState(() {
      _signedUrls = results;
      _isLoadingSignedUrls = false;
      if (hadError) {
         _signedUrlError = 'Some images could not be loaded.'; // TODO: Localize
      }
    });

  }
  // --- Signed URL Logic End ---

  void _handleDelete() async {
    if (_isDeleting || widget.imageUrls.isEmpty || _currentIndex >= widget.imageUrls.length) return; // Add boundary check
    final imageUrlToDelete = widget.imageUrls[_currentIndex]; // Get original URL
    final currentSignedUrlIndex = _currentIndex; // Store index before potential async gaps

    setState(() { _isDeleting = true; });
    widget.logger.i('Attempting delete via callback for: $imageUrlToDelete');
    try {
      await widget.onDeleteImage(imageUrlToDelete); // Pass original URL
      widget.logger.i('Delete callback successful for: $imageUrlToDelete');

      // Call success callback BEFORE removing from local state/closing
      widget.onImageDeletedSuccessfully(imageUrlToDelete);

      // --- Remove from local state BEFORE popping ---
      if (mounted && currentSignedUrlIndex < _signedUrls.length) { // Check index validity
        setState(() {
          // Remove the entry from the local signed URLs list as well
          _signedUrls.removeAt(currentSignedUrlIndex);
          widget.logger.d('Removed deleted image from local _signedUrls at index $currentSignedUrlIndex');
          // Note: We don't remove from widget.imageUrls as that's handled by the parent
        });
      }
      // --- End local state removal ---

      if (mounted) {
         // If it was the last image (based on the updated local list), pop the screen
         if (_signedUrls.isEmpty) { // Check the local list length
             Navigator.of(context).pop();
         } else {
             // Pop after deletion (parent handles grid update)
             Navigator.of(context).pop();
         }
      }
    } catch (e) {
        widget.logger.e('Error during delete callback for $imageUrlToDelete', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting image: ${e.toString()}')) // TODO: Localize
          );
        }
    } finally {
        // Only set _isDeleting false if we didn't pop
        // Since we always pop now, this might not be reached often, but good practice
        if (mounted) setState(() { _isDeleting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Allow body content behind AppBar
      backgroundColor: Colors.black, // Black background for gallery view
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), // White back button
      ),
      // --- Loading/Error Handling for Signed URLs ---
      body: _isLoadingSignedUrls
        ? const Center(child: CircularProgressIndicator())
        : _signedUrlError != null && _signedUrls.every((url) => url == null) // Show error only if ALL failed
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_signedUrlError!, style: const TextStyle(color: Colors.red)),
                ),
              )
            : PhotoViewGallery.builder(
                pageController: _pageController,
                itemCount: _signedUrls.length, // Use count of signed URLs
                builder: (context, index) {
                  final originalImageUrl = widget.imageUrls[index]; // Still needed for tag/delete
                  final signedUrl = _signedUrls[index];

                  // Handle case where specific signed URL failed
                  if (signedUrl == null) {
                     return PhotoViewGalleryPageOptions.customChild(
                        child: const Center(child: Icon(Icons.error_outline, color: Colors.white, size: 50)),
                        heroAttributes: PhotoViewHeroAttributes(tag: originalImageUrl),
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.contained,
                     );
                  }

                  // If successful, create PageOptions with the signed URL
                  return PhotoViewGalleryPageOptions(
                    imageProvider: CachedNetworkImageProvider(signedUrl),
                    heroAttributes: PhotoViewHeroAttributes(tag: originalImageUrl),
                    minScale: PhotoViewComputedScale.contained * 0.8,
                    maxScale: PhotoViewComputedScale.covered * 2,
                  );
                },
                loadingBuilder: (context, event) => const Center(
                  child: SizedBox(
                    width: 20.0,
                    height: 20.0,
                    child: CircularProgressIndicator(),
                  ),
                ),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
              ),
      bottomNavigationBar: _isDeleting
        ? const LinearProgressIndicator() // Show progress bar while deleting
        : Container(
            // Semi-transparent black background for the delete button
            color: Colors.black.withOpacity(0.5),
            padding: const EdgeInsets.all(8.0),
            child: SafeArea( // Ensure button is not under system UI
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                    tooltip: 'Delete Image', // TODO: Localize
                    onPressed: _handleDelete,
                  ),
                ],
              ),
            ),
          ),
    );
  }
} 