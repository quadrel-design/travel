import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math'; // Add import for max
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:logger/logger.dart'; // Import logger
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import '../models/journey_image_info.dart'; // Add import for the model
import 'package:http/http.dart' as http; // Add http import for http.get
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import AppLocalizations
import '../providers/gallery_detail_provider.dart'; // Import the new provider

// Change to ConsumerStatefulWidget
class GalleryDetailView extends ConsumerStatefulWidget {
  const GalleryDetailView({
    super.key,
    this.initialIndex = 0,
    required this.images, // Keep initial images passed via constructor
    required this.logger,
    required this.onDeleteImage,
    required this.onImageDeletedSuccessfully,
  });

  final int initialIndex;
  final List<JourneyImageInfo> images; // Initial list
  final Logger logger;
  final Future<void> Function(String imageUrl) onDeleteImage;
  final Function(String deletedUrl) onImageDeletedSuccessfully;

  @override
  // Change return type
  ConsumerState<GalleryDetailView> createState() {
    return _GalleryDetailViewState();
  }
}

// Change to ConsumerState
class _GalleryDetailViewState extends ConsumerState<GalleryDetailView> {
  late PageController pageController;
  late int currentIndex;
  bool _isDeleting = false; // Keep local UI state

  // --- State for Signed URLs ---
  List<String?> _signedUrls = []; // Keep local UI state for URLs
  bool _isLoadingSignedUrls = true;
  String? _signedUrlError;
  // --- End State for Signed URLs ---

  // --- Scan Logic State ---
  bool _isScanning = false; // Keep local UI state

  // REMOVE Realtime channel state
  // REMOVE _stateImages (will use provider)
  // REMOVE _currentSessionScanStatus (will use provider state directly)


  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    pageController = PageController(initialPage: widget.initialIndex);
    // Fetch initial signed URLs
    _fetchSignedUrls(widget.images.length, images: widget.images);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Optional: Could potentially re-initialize provider if needed, but .family should handle it.
  }

  @override
  void dispose() {
    // REMOVE channel unsubscription
    pageController.dispose();
    super.dispose();
  }

  // REMOVE _setupRealtimeListener method
  // REMOVE _handleRealtimeUpdate method

  // --- Signed URL Logic Start ---
  String? _extractPath(String url) {
    try {
      final uri = Uri.parse(url);
      final bucketName = 'journey_images';
      final pathStartIndex = uri.path.indexOf(bucketName) + bucketName.length + 1;
      if (pathStartIndex <= bucketName.length) return null;
      return uri.path.substring(pathStartIndex);
    } catch (e) {
      widget.logger.e('Failed to parse path from URL: $url', error: e);
      return null;
    }
  }
  Future<String> _generateSignedUrl(String imagePath) async {
    try {
      final result = await Supabase.instance.client.storage
          .from('journey_images')
          .createSignedUrl(imagePath, 3600); // 1 hour expiry
      return result;
    } catch (e) {
      widget.logger.e('Error generating signed URL for $imagePath', error: e);
      rethrow;
    }
  }

  // fetchSignedUrls remains mostly the same, called by initState and ref.listen
  Future<void> _fetchSignedUrls(int imageCount, {required List<JourneyImageInfo> images}) async {
     if (!mounted) return;
      // Prevent refetch if already loading
     if (_isLoadingSignedUrls && _signedUrls.isNotEmpty) {
        widget.logger.d('Skipping signed URL fetch, already in progress.');
        return;
     }
     widget.logger.d('Fetching signed URLs for $imageCount images.');
     setState(() {
       _isLoadingSignedUrls = true;
       _signedUrlError = null;
       // Ensure _signedUrls list size matches imageCount before filling
       if (_signedUrls.length != imageCount) {
         _signedUrls = List.filled(imageCount, null);
       }
     });

     List<String?> results = [];
     bool hadError = false;
     final imageList = images;

     // Use indexed loop to handle potential mismatches more gracefully
     for (int i = 0; i < imageCount; i++) {
        if (i >= imageList.length) {
            widget.logger.w('Index $i out of bounds for imageList (length ${imageList.length}) during signed URL fetch.');
            results.add(null);
            hadError = true;
            continue;
        }
        final imageInfo = imageList[i];
        final path = _extractPath(imageInfo.url);
        if (path == null) {
          widget.logger.w('Could not extract path for ${imageInfo.url}');
          results.add(null);
          hadError = true;
          continue;
        }
        try {
          final signedUrl = await _generateSignedUrl(path);
          results.add(signedUrl);
        } catch (e) {
          results.add(null);
          hadError = true;
        }
      }

     if (!mounted) return;
     setState(() {
       // Now results list should match imageCount
       _signedUrls = results;
       _isLoadingSignedUrls = false;
       if (hadError) {
         _signedUrlError = 'Some images could not be loaded.'; // TODO: Localize
       }
     });
   }
  // --- Signed URL Logic End ---


  void _handleDelete() async {
    // Get images from provider
    final images = ref.read(galleryDetailProvider(widget.images)).images;
    // Check mount status early
    if (!mounted) return; 
    if (_isDeleting || images.isEmpty || currentIndex >= images.length) return;

    final imageToDelete = images[currentIndex];
    final imageUrlToDelete = imageToDelete.url;
    final imageIdToDelete = imageToDelete.id; // Get ID

    setState(() { _isDeleting = true; }); // Use local state for loading indicator
    widget.logger.i('Attempting delete via callback for: $imageUrlToDelete');

    try {
      // 1. Call parent delete function (handles DB/Storage)
      await widget.onDeleteImage(imageUrlToDelete);
      widget.logger.i('Parent delete callback successful for: $imageUrlToDelete');

      // 2. Call parent success callback
      widget.onImageDeletedSuccessfully(imageUrlToDelete);

      // 3. Update Riverpod state AFTER parent callbacks succeed
      // Check mounted again after await
      if (mounted) {
          ref.read(galleryDetailProvider(widget.images).notifier).handleDeletion(imageIdToDelete);
          widget.logger.i('Called handleDeletion on notifier for ID: $imageIdToDelete');
          // No need to pop here - build method's empty check handles it
          // No need to manually update _signedUrls - ref.listen handles it
      }

    } catch (e) {
        widget.logger.e('Error during delete callback for $imageUrlToDelete', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting image: ${e.toString()}')) // TODO: Localize
          );
        }
    } finally {
        // Only set _isDeleting false if UI didn't get removed by build method's empty check
        if (mounted) setState(() { _isDeleting = false; });
    }
  }

  // --- Scan Logic ---
  Future<void> _handleScan() async {
     // Get images from provider
    final images = ref.read(galleryDetailProvider(widget.images)).images;
     // Check mount status early
    if (!mounted) return; 
    if (_isScanning || images.isEmpty || currentIndex >= images.length) return;

    final currentImageIndex = currentIndex; // Store index
    final imageInfo = images[currentImageIndex];
    final imageId = imageInfo.id;
    widget.logger.i('Triggering scan for image ID: $imageId');

    // --- Reset status in provider state --- 
    ref.read(galleryDetailProvider(widget.images).notifier).resetScanStatus(imageId);
    // Start local loading indicator
    setState(() { _isScanning = true; });
    // --- End Reset --- 

    try {
      // Ensure signed URLs are available before trying to download
      if (_isLoadingSignedUrls || _signedUrls.length <= currentImageIndex || _signedUrls[currentImageIndex] == null) {
          widget.logger.w('Scan attempted before signed URL was ready for index $currentImageIndex. Trying public URL.');
          // Optionally try fetching signed URLs again or just use public URL
      }
      
      // Use signed URL if available, otherwise fallback to original URL
      final urlToDownload = _signedUrls.length > currentImageIndex && _signedUrls[currentImageIndex] != null 
                            ? _signedUrls[currentImageIndex]! 
                            : imageInfo.url;
      widget.logger.d('Attempting to download from: $urlToDownload');

      final httpResponse = await http.get(Uri.parse(urlToDownload));
      if (httpResponse.statusCode != 200) {
        throw Exception('Failed to download image: ${httpResponse.statusCode}');
      }
      final imageBytes = httpResponse.bodyBytes;
      final base64Image = base64Encode(imageBytes);
      widget.logger.d('Image downloaded and encoded for scan (ID: $imageId)');

      final response = await Supabase.instance.client.functions.invoke(
        'detect-invoice-text',
        body: {'imageData': base64Image, 'recordId': imageId},
      );

      if (response.status != 200) {
        widget.logger.e('Error calling edge function for scan (ID $imageId): Status ${response.status}, Data: ${response.data}');
        // Let the Realtime listener handle the actual state based on DB, but show user error
         if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Analysis request failed (${response.status}).')) // TODO: Localize
            );
         }
        // Do not throw exception here, allow finally block to run
      } else {
        widget.logger.i('Edge function call successful for scan (ID $imageId). DB update pending.');
        // Wait for Realtime update to set provider state and show chip
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Analysis initiated.')), // TODO: Localize
          );
        }
      }
    } catch (e) {
      widget.logger.e('Error during scan for ID $imageId', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting analysis: $e')), // TODO: Localize
        );
      }
      // No need to update provider state on error - rely on Realtime if function partially succeeded
      // or let the lack of update leave hasPotentialText as null.
    } finally {
      if (mounted) setState(() { _isScanning = false; });
    }
  }
  // --- End Scan Logic ---

  void onPageChanged(int index) {
    setState(() {
      currentIndex = index;
      // Potential place to reset session scan status if needed when swiping?
    });
  }

  @override
  Widget build(BuildContext context) {
    // *** Watch the Provider ***
    // Pass the initial list from the widget to the provider family
    final galleryState = ref.watch(galleryDetailProvider(widget.images));
    final images = galleryState.images; // Get the current image list from state
    final scanInitiatedInSession = galleryState.scanInitiatedInSession; // Get the set

    // *** Listen for changes in image count to refetch signed URLs ***
    ref.listen<GalleryDetailState>(galleryDetailProvider(widget.images), (previous, next) {
        final previousCount = previous?.images.length ?? widget.images.length;
        final nextCount = next.images.length;
        // Refetch if count changes (e.g., after deletion)
        if (previousCount != nextCount) {
            widget.logger.i('Image count changed from $previousCount to $nextCount, refetching signed URLs.');
            _fetchSignedUrls(nextCount, images: next.images);
        }
        // Optional: Show snackbar on error state change
        if (previous?.error == null && next.error != null) {
           ScaffoldMessenger.of(context).hideCurrentSnackBar();
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error: ${next.error}')) // TODO: Localize
           );
        }
    });

    // Access l10n for title localization
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context); // Access theme for styling

    // Ensure currentIndex is valid for the provider's list
    final safeCurrentIndex = currentIndex.clamp(0, max(0, images.length - 1)).toInt();

    // Handle empty state based on provider's list
    if (images.isEmpty) {
      widget.logger.w('GalleryDetailView build: images list from provider is empty.');
      // Check if we are in the middle of a deletion process initiated from this screen
      if (_isDeleting) {
         // If deleting initiated here led to empty list, allow pop to happen in _handleDelete
         return Scaffold(
             backgroundColor: theme.colorScheme.background,
             body: const Center(child: CircularProgressIndicator()) // Show loading while pop happens
         );
      } else {
         // If list is empty for other reasons (e.g. started empty), show message or pop.
          // Use addPostFrameCallback to avoid calling pop during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.canPop(context)) {
               widget.logger.i('Popping GalleryDetailView because image list is empty and not deleting.');
               Navigator.of(context).pop();
            }
          });
         return Scaffold(
           backgroundColor: theme.colorScheme.background,
           appBar: AppBar(title: const Text('Gallery')), // Simple AppBar
           body: Center(child: Text('No images found.', // TODO: Localize
               style: TextStyle(color: theme.colorScheme.onBackground))),
         );
      }
    }

     // Get the current image info from the PROVIDER's list
    final JourneyImageInfo currentImageInfo = images[safeCurrentIndex];
    final imageId = currentImageInfo.id;

    // --- Define chip based on BOTH provider state AND session tracking --- 
    Widget? statusChip;
    // *** Only consider showing chip if scan was initiated in this session ***
    if (scanInitiatedInSession.contains(imageId)) {
      // Now check the actual status from the provider
      if (currentImageInfo.hasPotentialText != null) {
         if (currentImageInfo.hasPotentialText == true &&
             currentImageInfo.detectedText != null &&
             currentImageInfo.detectedText!.isNotEmpty) {
              statusChip = const Chip(/* Success */
                 label: Text('OCR Okay'), backgroundColor: Colors.green,
                 labelStyle: TextStyle(color: Colors.white),
                 padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
              );
         } else { // hasPotentialText is false OR (true but no text)
            statusChip = const Chip(/* Failure */
               label: Text('OCR Failed'), backgroundColor: Colors.red,
               labelStyle: TextStyle(color: Colors.white),
               padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
            );
         }
      } else {
          // Scan initiated, but hasPotentialText is still null (processing/pending)
          // Optionally show a pending chip?
          /*
          statusChip = const Chip(
             label: Text('Processing...'), 
             backgroundColor: Colors.orange, 
             labelStyle: TextStyle(color: Colors.white),
             padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
          );
          */
          // Or show nothing until success/fail comes back
          statusChip = null;
      }
    }
    // --- End Chip Logic --- 

    // --- Signed URL Loading/Error Check --- 
    // Check based on the length of the provider's list now
    final expectedUrlCount = images.length;
    // Only consider URLs ready if not loading AND list length matches expected
    final urlsReady = !_isLoadingSignedUrls && _signedUrls.length == expectedUrlCount;
    final urlError = _signedUrlError; // Keep local error state for URLs


    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        foregroundColor: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface,
        elevation: 0,
        shape: const Border(),
        title: Text(l10n.galleryDetailTitle(safeCurrentIndex + 1, images.length), // Use images.length
            style: theme.textTheme.titleMedium),
        centerTitle: true,
        iconTheme: theme.appBarTheme.iconTheme ?? theme.iconTheme,
        actions: [
          if (currentImageInfo.url != null)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () async { // Download logic remains the same
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.downloadingImage)));
                 try {
                   await Future.delayed(const Duration(seconds: 1));
                   print('Download requested for: ${currentImageInfo.url}');
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.downloadComplete)));
                 } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.downloadFailed)));
                 }
              },
            ),
        ],
      ),
      // Wrap body content in a Stack
      body: Stack(
        children: [
          // --- Main Content: Loading / Error / Gallery ---
          // Check for URL errors first
          if (urlError != null && _signedUrls.every((url) => url == null))
             Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(urlError, style: const TextStyle(color: Colors.red)),
                ),
              )
          // Then check if URLs are ready
          else if (!urlsReady)
              const Center(child: CircularProgressIndicator())
          // Otherwise, show the gallery
          else
              PhotoViewGallery.builder(
                      scrollPhysics: const BouncingScrollPhysics(),
                      builder: (BuildContext context, int index) {
                        // Index check should use provider list length
                        if (index >= images.length) {
                          widget.logger.w('PhotoViewGallery builder: index $index out of bounds for images list (length ${images.length}).');
                          return PhotoViewGalleryPageOptions(
                            imageProvider: const AssetImage('assets/placeholder.png'),
                            heroAttributes: PhotoViewHeroAttributes(tag: "error_$index"),
                          );
                        }
                        final imageInfo = images[index]; // Get image from provider state
                        final signedUrl = _signedUrls.length > index ? _signedUrls[index] : null;

                        // Determine image provider
                        ImageProvider imageProvider;
                        if (signedUrl != null && signedUrl.isNotEmpty) {
                          imageProvider = CachedNetworkImageProvider(signedUrl);
                        } else if (imageInfo.localPath != null) {
                           // Handle local path if needed (though unlikely if coming from provider)
                           widget.logger.w('Displaying local path image: ${imageInfo.localPath}');
                           imageProvider = FileImage(File(imageInfo.localPath!));
                        }
                         else {
                          // Fallback if URL/signed URL is missing/invalid
                           widget.logger.w('Using placeholder for image ID ${imageInfo.id} - No valid signed URL or local path.');
                           imageProvider = const AssetImage('assets/placeholder.png');
                         }


                        return PhotoViewGalleryPageOptions(
                          imageProvider: imageProvider,
                          initialScale: PhotoViewComputedScale.contained,
                          heroAttributes: PhotoViewHeroAttributes(
                              tag: imageInfo.id ?? 'image_$index'), // Use image ID or index if ID null
                          minScale: PhotoViewComputedScale.contained * 0.8,
                          maxScale: PhotoViewComputedScale.covered * 2,
                        );
                      },
                      itemCount: images.length, // Use provider list length
                      loadingBuilder: (context, event) => Center(
                        child: SizedBox(
                          width: 20.0, height: 20.0,
                          child: CircularProgressIndicator(
                            value: event == null ? 0 : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                          ),
                        ),
                      ),
                      pageController: pageController,
                      onPageChanged: onPageChanged,
                      backgroundDecoration: BoxDecoration(color: theme.canvasColor),
                    ),

            // --- Positioned Status Chip ---
            if (statusChip != null)
              Positioned(
                top: 24.0, left: 24.0,
                child: Material(
                   elevation: 2.0,
                   borderRadius: BorderRadius.circular(16.0),
                   child: statusChip, // Chip defined earlier based on provider state
                )
              ),
        ],
      ),
      // --- Bottom Navigation Bar ---
      bottomNavigationBar: Container(
            color: theme.bottomAppBarTheme.color ?? theme.colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Scan Button
                  _isScanning // Use local _isScanning state for button display
                    ? const SizedBox(width: 48, height: 48, child: Center(child: CircularProgressIndicator(strokeWidth: 2.0)))
                    : IconButton(
                        icon: const Icon(Icons.document_scanner_outlined),
                        tooltip: l10n.scanButtonTooltip,
                        // Disable scan if already processed successfully? Consider adding check on currentImageInfo.hasPotentialText
                        onPressed: currentImageInfo.hasPotentialText == true ? null : _handleScan, // Disable if already successfully scanned
                      ),
                  // Delete Button
                  _isDeleting // Use local _isDeleting state for button display
                    ? const SizedBox(width: 48, height: 48, child: Center(child: CircularProgressIndicator(strokeWidth: 2.0)))
                    : IconButton(
                        icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                        tooltip: l10n.deleteButtonTooltip,
                        onPressed: _handleDelete,
                      ),
                ],
              ),
            ),
          ),
    );
  }
} 