import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:logger/logger.dart'; // Import logger
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import '../models/journey_image_info.dart'; // Add import for the model
import 'package:http/http.dart' as http; // Add http import for http.get
// import 'photo_app_bar.dart'; // Remove import
// import 'full_screen_image_viewer.dart'; // Not needed anymore

class GalleryDetailView extends StatefulWidget {
  const GalleryDetailView({
    super.key,
    this.initialIndex = 0,
    required this.images,
  })
  // Removed redundant pageController initialization here
  ;

  final int initialIndex;
  final List<JourneyImageInfo> images;

  @override
  State<StatefulWidget> createState() {
    return _GalleryDetailViewState(); // Rename State class reference
  }
}

class _GalleryDetailViewState extends State<GalleryDetailView> { // Rename State class
  late PageController pageController;
  late int currentIndex;
  bool _isDeleting = false; // Track deletion state

  // --- State for Signed URLs ---
  List<String?> _signedUrls = []; // Store signed URLs (nullable for errors)
  bool _isLoadingSignedUrls = true;
  String? _signedUrlError;
  // --- End State for Signed URLs ---

  // --- Scan Logic ---
  // Add state for scanning
  bool _isScanning = false; 

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    // Initialize pageController here where widget is accessible
    pageController = PageController(initialPage: widget.initialIndex);
    // Fetch signed URLs when the widget initializes
    _fetchSignedUrls();
  }

  @override
  void dispose() {
    pageController.dispose();
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
      // Use widget.images.length
      _signedUrls = List.filled(widget.images.length, null); 
    });

    List<String?> results = [];
    bool hadError = false;
    // Iterate over the JourneyImageInfo objects
    for (final imageInfo in widget.images) {
      // Extract path from imageInfo.url
      final path = _extractPath(imageInfo.url); 
      if (path == null) {
        widget.logger.w('Could not extract path for ${imageInfo.url}');
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
    // Use widget.images list for checks and getting URL
    if (_isDeleting || widget.images.isEmpty || currentIndex >= widget.images.length) return;
    final imageToDelete = widget.images[currentIndex]; // Get JourneyImageInfo
    final imageUrlToDelete = imageToDelete.url; // Get URL from object
    final currentSignedUrlIndex = currentIndex;

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
        if (mounted) setState(() { _isDeleting = false; });
    }
  }

  // --- Scan Logic ---
  Future<void> _handleScan() async {
    // Check state and index validity
    if (_isScanning || widget.images.isEmpty || currentIndex >= widget.images.length) return;

    final imageInfo = widget.images[currentIndex]; // Get current image info
    widget.logger.i('Triggering scan for image ID: ${imageInfo.id}');
    setState(() { _isScanning = true; });

    try {
      // 1. Get Image Data (Re-download)
      final httpResponse = await http.get(Uri.parse(imageInfo.url)); // Assumes http import
      if (httpResponse.statusCode != 200) {
        throw Exception('Failed to download image: ${httpResponse.statusCode}');
      }
      final imageBytes = httpResponse.bodyBytes;
      final base64Image = base64Encode(imageBytes); // Assumes dart:convert import
      widget.logger.d('Image downloaded and encoded for scan (ID: ${imageInfo.id})');

      // 2. Call Edge Function
      final response = await Supabase.instance.client.functions.invoke(
        'detect-invoice-text', 
        body: {
          'imageData': base64Image,
          'recordId': imageInfo.id
        },
      );

      if (response.status != 200) {
        widget.logger.e(
          'Error calling edge function for scan (ID ${imageInfo.id}): Status ${response.status}, Data: ${response.data}',
        );
        throw Exception('Text detection failed: ${response.status}');
      } else {
        widget.logger.i('Edge function call successful for scan (ID ${imageInfo.id}). DB should update.');
        // No UI update needed here - parent screen's Realtime listener handles it
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Analysis initiated.')), // TODO: Localize
          );
        }
      }
    } catch (e) {
      widget.logger.e('Error during scan for ID ${imageInfo.id}', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting analysis: $e')), // TODO: Localize
        );
      }
    } finally {
      if (mounted) setState(() { _isScanning = false; });
    }
  }
  // --- End Scan Logic ---

  void onPageChanged(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Access l10n for title localization
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context); // Access theme for styling

    // Get the current image info based on the page index
    // Ensure index is within bounds, handle potential empty list
    final JourneyImageInfo? currentImageInfo =
        widget.images.isNotEmpty && currentIndex < widget.images.length
            ? widget.images[currentIndex]
            : null;

    // Check if signedUrls is empty before building Scaffold content
    // This prevents errors if all images are deleted while viewing
    if (_signedUrls.isEmpty) {
      // Optionally return a different scaffold or an empty container
      // Or, if the pop logic handles this, it might be okay, but safer to check.
      widget.logger.w('GalleryPageView build called with empty _signedUrls. Returning empty Scaffold.');
      return Scaffold(
        // Change background and text color for empty state
        backgroundColor: theme.colorScheme.background, // Use theme background
        appBar: AppBar(title: const Text('Gallery')), // Simple AppBar
        body: Center(
          child: Text(
            'No images left.', 
            style: TextStyle(color: theme.colorScheme.onBackground) // Use theme text color
          ),
        ),
      );
    }
    
    // Ensure currentIndex is valid for the potentially reduced _signedUrls list
    final safeCurrentIndex = currentIndex.clamp(0, _signedUrls.length - 1);

    return Scaffold(
      // Change Scaffold background
      backgroundColor: theme.colorScheme.background, // Use theme background 
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface, 
        foregroundColor: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface,
        elevation: 0, 
        // Explicitly remove any border shape
        shape: const Border(), 
        title: Text(l10n.galleryDetailTitle(safeCurrentIndex + 1, widget.images.length), style: theme.textTheme.titleMedium),
        centerTitle: true,
        // Use AppBar specific icon theme or fallback
        iconTheme: theme.appBarTheme.iconTheme ?? theme.iconTheme, 
        actions: [
          // Add Download Button
          if (currentImageInfo != null && currentImageInfo.url != null)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () async {
                 // Placeholder for download logic
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text(l10n.downloadingImage)),
                 );
                 try {
                   // Simulate download
                   await Future.delayed(const Duration(seconds: 1)); 
                   // Replace with actual download logic using image_downloader or similar
                   print('Download requested for: ${currentImageInfo.url}');
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text(l10n.downloadComplete)),
                   );
                 } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text(l10n.downloadFailed)),
                   );
                 }
              },
            ),
        ],
      ),
      body: _isLoadingSignedUrls
        ? const Center(child: CircularProgressIndicator())
        : _signedUrlError != null && _signedUrls.every((url) => url == null)
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  // Error text color (red) should be fine on white
                  child: Text(_signedUrlError!, style: const TextStyle(color: Colors.red)),
                ),
              )
            : PhotoViewGallery.builder(
                scrollPhysics: const BouncingScrollPhysics(),
                builder: (BuildContext context, int index) {
                   if (index >= widget.images.length) {
                     // Handle potential index out of bounds error gracefully
                     return const Center(child: Text("Error: Image not found"));
                   }
                   final imageInfo = widget.images[index];
                   final imageUrl = imageInfo.url;

                   // Determine if the overlay should be shown
                   final bool showOverlay =
                       imageInfo.hasPotentialText == true ||
                       (imageInfo.detectedText != null && imageInfo.detectedText!.isNotEmpty);

                  return PhotoViewGalleryPageOptions(
                    imageProvider: imageUrl != null
                        ? CachedNetworkImageProvider(_signedUrls[index]!)
                        : imageInfo.localPath != null
                            ? FileImage(File(imageInfo.localPath!)) // Use FileImage for local paths
                            : const AssetImage('assets/placeholder.png') as ImageProvider, // Fallback placeholder
                    initialScale: PhotoViewComputedScale.contained,
                    heroAttributes: PhotoViewHeroAttributes(tag: imageInfo.id ?? "image_$index"), // Use image ID or index as tag
                    minScale: PhotoViewComputedScale.contained * 0.8,
                    maxScale: PhotoViewComputedScale.covered * 2,
                    // Wrap with Stack to potentially add overlay
                    child: Stack(
                      children: [
                         // The actual image is implicitly handled by PhotoViewGalleryPageOptions
                         // Add the overlay conditionally
                         if (showOverlay)
                           Positioned.fill(
                             child: Container(
                               decoration: BoxDecoration(
                                 shape: BoxShape.circle,
                                 color: Colors.white.withOpacity(0.7), // Semi-transparent white circle
                               ),
                               child: const Icon(
                                 Icons.check_circle,
                                 color: Colors.green,
                                 size: 50.0, // Adjust size as needed
                               ),
                             ),
                           ),
                      ],
                    ),
                  );
                },
                itemCount: widget.images.length,
                loadingBuilder: (context, event) => Center(
                  child: SizedBox(
                    width: 20.0,
                    height: 20.0,
                    child: CircularProgressIndicator(
                      value: event == null
                          ? 0
                          : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                    ),
                  ),
                ),
                pageController: pageController,
                onPageChanged: onPageChanged,
                backgroundDecoration: BoxDecoration(
                  color: theme.canvasColor, // Use theme background color
                ),
              ),
      bottomNavigationBar: Container(
            color: theme.bottomAppBarTheme.color ?? theme.colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 8.0), 
            child: SafeArea( 
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  // --- Add Scan Button --- 
                  _isScanning
                    ? const SizedBox(width: 48, height: 48, child: Center(child: CircularProgressIndicator(strokeWidth: 2.0)))
                    : IconButton(
                        icon: const Icon(Icons.document_scanner_outlined),
                        tooltip: 'Scan for Text', // TODO: Localize
                        onPressed: _handleScan,
                      ),
                  // --- Keep Delete Button --- 
                  _isDeleting 
                    ? const SizedBox(width: 48, height: 48, child: Center(child: CircularProgressIndicator(strokeWidth: 2.0))) 
                    : IconButton(
                        icon: Icon(Icons.delete_outline, color: theme.colorScheme.error), 
                        tooltip: 'Delete Image', 
                        onPressed: _handleDelete,
                      ),
                ],
              ),
            ),
          ),
    );
  }
} 