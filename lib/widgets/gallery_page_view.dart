import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:logger/logger.dart'; // Import logger
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import '../models/journey_image_info.dart'; // Add import for the model
import 'package:http/http.dart' as http; // Add http import for http.get
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Add import for AppLocalizations

class GalleryDetailView extends ConsumerStatefulWidget {
  final List<JourneyImageInfo> images;
  final int initialIndex;
  final bool showDeleteButton;
  final bool showScanButton;
  final Logger logger;
  final Future<void> Function(String imageUrl) onDeleteImage;
  final void Function(String imageUrl) onImageDeletedSuccessfully;

  const GalleryDetailView({
    super.key,
    required this.images,
    required this.initialIndex,
    this.showDeleteButton = true,
    this.showScanButton = true,
    required this.logger,
    required this.onDeleteImage,
    required this.onImageDeletedSuccessfully,
  });

  @override
  ConsumerState<GalleryDetailView> createState() => _GalleryDetailViewState();
}

class _GalleryDetailViewState extends ConsumerState<GalleryDetailView> { // Rename State class
  late PageController pageController;
  late int currentIndex;
  bool _isDeleting = false; // Track deletion state
  bool showAppBar = true;

  // --- State for Signed URLs ---
  List<String?> _signedUrls = []; // Store signed URLs (nullable for errors)
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
      const bucketName = 'journey_images'; // Ensure this matches
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
      // _isLoadingSignedUrls = true;
      // _signedUrlError = null;
      // Use widget.images.length
      _signedUrls = List.filled(widget.images.length, null); 
    });

    List<String?> results = [];
    // bool hadError = false;
    
    // Iterate over the JourneyImageInfo objects
    for (final imageInfo in widget.images) {
      // Extract path from imageInfo.url
      final path = _extractPath(imageInfo.url); 
      if (path == null) {
        widget.logger.w('Could not extract path for ${imageInfo.url}');
        results.add(null); // Mark as error
        // hadError = true;
        continue;
      }
      try {
        final signedUrl = await _generateSignedUrl(path);
        results.add(signedUrl);
      } catch (e) {
        results.add(null); // Mark as error
        // hadError = true;
      }
    }

    if (!mounted) return;
    setState(() {
      _signedUrls = results;
      // _isLoadingSignedUrls = false;
      // if (hadError) {
      //   _signedUrlError = 'Some images could not be loaded.'; // TODO: Localize
      // }
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
    // Initialize these at the beginning of build to avoid multiple lookups
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    
    // Get current index as a reactive value
    final currentImageIndex = pageController.page?.round() ?? widget.initialIndex;
    final currentImage = currentImageIndex >= 0 && currentImageIndex < widget.images.length 
        ? widget.images[currentImageIndex] 
        : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (currentImage != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _handleDelete(),
              tooltip: l10n?.deleteImage ?? 'Delete image',
            ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (BuildContext context, int index) {
              if (index < 0 || index >= widget.images.length) {
                // Return placeholder for invalid indices
                widget.logger.w('Invalid index $index requested in PhotoViewGallery');
                return PhotoViewGalleryPageOptions(
                  imageProvider: const AssetImage('assets/images/image_error.png'),
                  errorBuilder: (context, error, stackTrace) {
                    widget.logger.e('Error loading image: $error');
                    return const Center(
                      child: Icon(Icons.error_outline, color: Colors.red, size: 42),
                    );
                  },
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                );
              }

              final imageInfo = widget.images[index];
              final signedUrl = _signedUrls[index];
              
              return PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(signedUrl!),
                errorBuilder: (context, error, stackTrace) {
                  widget.logger.e('Error loading image ${imageInfo.id}: $error');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 42),
                        const SizedBox(height: 16),
                        Text(
                          l10n?.imageLoadError ?? 'Could not load image',
                          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red),
                        ),
                      ],
                    ),
                  );
                },
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
                heroAttributes: PhotoViewHeroAttributes(tag: imageInfo.id),
              );
            },
            itemCount: widget.images.length,
            loadingBuilder: (BuildContext context, ImageChunkEvent? event) {
              // Handle null case properly
              double? progress;
              if (event != null && event.expectedTotalBytes != null) {
                progress = event.cumulativeBytesLoaded / event.expectedTotalBytes!;
              }
              
              return Center(
                child: CircularProgressIndicator(
                  value: progress,
                ),
              );
            },
            pageController: pageController,
            onPageChanged: onPageChanged,
            backgroundDecoration: BoxDecoration(
              color: theme.canvasColor, // Use theme background color
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
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
          ),
        ],
      ),
    );
  }
} 