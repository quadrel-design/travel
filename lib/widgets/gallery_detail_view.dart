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
import 'package:intl/intl.dart'; // Add intl import

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
  bool _isScanning = false; // Use provider state instead for scan initiated

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    pageController = PageController(initialPage: widget.initialIndex);
    // Fetch initial signed URLs
    // Use the image list directly from the widget as the initial state for the provider
    // is derived from this same list.
    _fetchSignedUrls(widget.images.length, images: widget.images);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

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

  Future<void> _fetchSignedUrls(int imageCount, {required List<JourneyImageInfo> images}) async {
     if (!mounted) return;
      // Prevent refetch if already loading
     if (_isLoadingSignedUrls && _signedUrls.isNotEmpty && _signedUrls.any((url) => url != null)) {
        widget.logger.d('Skipping signed URL fetch, already in progress or completed.');
        return;
     }
     widget.logger.d('Fetching signed URLs for $imageCount images.');
     setState(() {
       _isLoadingSignedUrls = true;
       _signedUrlError = null;
       if (_signedUrls.length != imageCount) {
         _signedUrls = List.filled(imageCount, null);
       }
     });

     List<String?> results = List.filled(imageCount, null);
     bool hadError = false;
     final imageList = images;

     for (int i = 0; i < imageCount; i++) {
        if (i >= imageList.length) {
            widget.logger.w('Index $i out of bounds for imageList (length ${imageList.length}) during signed URL fetch.');
            hadError = true;
            continue;
        }
        final imageInfo = imageList[i];
        final path = _extractPath(imageInfo.url);
        if (path == null) {
          widget.logger.w('Could not extract path for ${imageInfo.url}');
          hadError = true;
          continue;
        }
        try {
          final signedUrl = await _generateSignedUrl(path);
          results[i] = signedUrl;
        } catch (e) {
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
    // Get images from provider
    final images = ref.read(galleryDetailProvider(widget.images)).images;
    if (!mounted) return; 
    if (_isDeleting || images.isEmpty || currentIndex >= images.length) return;

    final imageToDelete = images[currentIndex];
    final imageUrlToDelete = imageToDelete.url;
    final imageIdToDelete = imageToDelete.id;

    setState(() { _isDeleting = true; });
    widget.logger.i('Attempting delete via callback for: $imageUrlToDelete');

    try {
      await widget.onDeleteImage(imageUrlToDelete);
      widget.logger.i('Parent delete callback successful for: $imageUrlToDelete');

      widget.onImageDeletedSuccessfully(imageUrlToDelete);

      if (mounted) {
          ref.read(galleryDetailProvider(widget.images).notifier).handleDeletion(imageIdToDelete);
          widget.logger.i('Called handleDeletion on notifier for ID: $imageIdToDelete');
      }

    } catch (e) {
        widget.logger.e('Error during delete callback for $imageUrlToDelete', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting image: ${e.toString()}')) // TODO: Localize
          );
        }
    } finally {
        if (mounted) setState(() { _isDeleting = false; });
    }
  }

  // --- Scan Logic ---
  Future<void> _handleScan(String imageId, String? imageUrl) async {
    // Use imageUrl from provider to ensure consistency
     if (!mounted) return;

    widget.logger.i('Triggering scan for image ID: $imageId');

    // --- Reset status in provider state --- 
    ref.read(galleryDetailProvider(widget.images).notifier).resetScanStatus(imageId);
    // No need for local _isScanning state, provider state tracks initiation
    // --- End Reset --- 

    try {
       // Prefer signed URL if available and valid for the current image index
       String? urlToDownload = imageUrl; // Fallback to the public URL
       if (currentIndex < _signedUrls.length && _signedUrls[currentIndex] != null) {
           urlToDownload = _signedUrls[currentIndex]!;
           widget.logger.d("Using signed URL for download: $urlToDownload");
       } else if (imageUrl != null) {
            widget.logger.w("Signed URL not available or index mismatch for index $currentIndex. Falling back to public URL: $imageUrl");
       } else {
           // If both imageUrl (passed in) and signedUrl are null, we cannot proceed.
           throw Exception('Image URL is null, cannot download.'); 
       }
       
       // Explicit null check before parsing
       if (urlToDownload == null) {
           throw Exception('URL to download is null after checks.');
       }

      widget.logger.d("Attempting to download from: $urlToDownload");
      final httpResponse = await http.get(Uri.parse(urlToDownload)); // Now safe
      widget.logger.d("Image download status: ${httpResponse.statusCode}");

      if (httpResponse.statusCode != 200) {
        throw Exception("Failed to download image: ${httpResponse.statusCode}");
      }

      final imageBytes = httpResponse.bodyBytes;
      final imageBase64 = base64Encode(imageBytes);
      widget.logger.d("Image downloaded and encoded for scan (ID: $imageId)");

      // Call Supabase Edge Function
      widget.logger.d("Invoking Edge Function 'detect-invoice-text'..."); // Use double quotes
      final response = await Supabase.instance.client.functions.invoke(
        'detect-invoice-text',
        body: {
          'image_base64': imageBase64,
          'journey_image_id': imageId,
        },
      );
      widget.logger.d("Edge Function response status: ${response.status}");

      if (response.status != 200) {
        widget.logger.e('Edge function invocation failed with status ${response.status}', error: response.data);
        throw Exception('Failed to process image: ${response.data?['error'] ?? 'Unknown error'}');
      }

      widget.logger.i('Edge function call successful for scan (ID $imageId). DB update pending.');
      // No need to set state here, Realtime listener in provider handles updates

    } catch (e, stackTrace) {
      widget.logger.e('Error during scan process for image ID $imageId', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning image: ${e.toString()}')) // TODO: Localize
        );
        // Optionally reset the scanInitiatedInSession state here if needed, though it might clear too early
        // ref.read(galleryDetailProvider(widget.images).notifier).clearScanInitiation(imageId); // Example hypothetical method
      }
    } finally {
       // No need to manage local _isScanning state
    }
  }
  // --- End Scan Logic ---

  @override
  Widget build(BuildContext context) {
    // --- Ref.watch for state changes --- 
    final galleryState = ref.watch(galleryDetailProvider(widget.images));
    final images = galleryState.images;

    // --- Ref.listen for side effects (like refetching signed URLs) ---
    ref.listen<GalleryDetailState>(galleryDetailProvider(widget.images), (previous, next) {
       // If image count changes (deletion), refetch signed URLs
       if (previous != null && previous.images.length != next.images.length) {
         widget.logger.d('Image count changed (${previous.images.length} -> ${next.images.length}), refetching signed URLs.');
         _fetchSignedUrls(next.images.length, images: next.images);
       }
       // If an error appears in the state, show a snackbar
       if (previous?.error == null && next.error != null) {
         ScaffoldMessenger.of(context).removeCurrentSnackBar();
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(next.error!))
         );
       }
    });
    // --- End Listeners ---

    // Handle case where images become empty (e.g., last one deleted)
    if (images.isEmpty) {
      // Optionally show a message or navigate back
      return const Scaffold(
        body: Center(child: Text("No images remaining.")), // TODO: Localize
      );
    }

    // Ensure currentIndex is valid after potential deletions
    currentIndex = min(currentIndex, images.length - 1);
    if (currentIndex < 0) currentIndex = 0; // Should not happen if images is not empty

    // Get current image info from provider state
    final JourneyImageInfo currentImageInfo = images[currentIndex];
    final bool scanInitiated = galleryState.scanInitiatedInSession.contains(currentImageInfo.id);

    // --- Add Logging ---
    widget.logger.d(
      'Build Detail View: Index: $currentIndex, ImageID: ${currentImageInfo.id}, ' 
      'scanInitiated: $scanInitiated, hasPotentialText: ${currentImageInfo.hasPotentialText}, ' 
      'Amount: ${currentImageInfo.detectedTotalAmount}, Currency: ${currentImageInfo.detectedCurrency}'
    );
    // --- End Logging ---

    // Prepare NumberFormat for currency
    final currencyFormat = NumberFormat.currency(
      locale: Localizations.localeOf(context).toString(), // Use app's locale
      symbol: currentImageInfo.detectedCurrency ?? '', // Use detected currency or empty string
      decimalDigits: 2
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'), // Use hardcoded default
        elevation: 2,
      ),
      body: _isLoadingSignedUrls
          ? const Center(child: CircularProgressIndicator())
          : PhotoViewGallery.builder(
              itemCount: images.length,
              pageController: pageController,
              builder: (context, index) {
                final imageInfo = images[index];
                final signedUrl = (index < _signedUrls.length) ? _signedUrls[index] : null;

                ImageProvider imageProvider;
                if (signedUrl != null) {
                  imageProvider = CachedNetworkImageProvider(signedUrl);
                } else if (imageInfo.localPath != null && imageInfo.localPath!.isNotEmpty) {
                   // If signed URL failed but we have a local path (e.g., just picked)
                   try {
                     imageProvider = FileImage(File(imageInfo.localPath!));
                   } catch (e) {
                     widget.logger.w('Error creating FileImage from ${imageInfo.localPath}', error: e);
                     imageProvider = const AssetImage('assets/placeholder.png'); // Placeholder
                   }
                } else {
                   widget.logger.w('Missing signed URL and local path for index $index, url: ${imageInfo.url}');
                   // Fallback or error placeholder
                   imageProvider = const AssetImage('assets/placeholder.png'); // Placeholder
                }

                return PhotoViewGalleryPageOptions(
                  imageProvider: imageProvider,
                  minScale: PhotoViewComputedScale.contained * 0.8,
                  maxScale: PhotoViewComputedScale.covered * 2,
                  heroAttributes: PhotoViewHeroAttributes(tag: imageInfo.id),
                );
              },
              onPageChanged: (index) {
                setState(() {
                  currentIndex = index;
                });
              },
              loadingBuilder: (context, event) => const Center(
                child: CircularProgressIndicator(),
              ),
              backgroundDecoration: const BoxDecoration(
                color: Colors.black,
              ),
            ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row( // Row for status indicators
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Chip for Scan Status / Result
                  if (currentImageInfo.hasPotentialText == true || scanInitiated)
                    Chip(
                      avatar: scanInitiated && currentImageInfo.hasPotentialText == null
                          ? const SizedBox( // Show spinner if scan initiated but result not yet back
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(
                              currentImageInfo.isInvoiceGuess ? Icons.receipt_long : Icons.notes,
                              color: Colors.grey.shade600,
                            ),
                      label: Text(
                        scanInitiated && currentImageInfo.hasPotentialText == null
                          ? 'Scanning...' // Use hardcoded default
                          : currentImageInfo.isInvoiceGuess 
                              ? 'Invoice?' // Use hardcoded default 
                              : 'Text?', // Use hardcoded default
                        style: TextStyle(color: Colors.grey.shade700)
                        ),
                      backgroundColor: Colors.grey.shade300,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    ),
                  const SizedBox(width: 8), // Spacing

                  // NEW Chip for Detected Amount
                  if (currentImageInfo.detectedTotalAmount != null)
                    Chip(
                      label: Text(
                        currencyFormat.format(currentImageInfo.detectedTotalAmount),
                        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey.shade400), // Optional border
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    ),
                ],
              ),

              Row( // Row for action buttons
                mainAxisSize: MainAxisSize.min,
                 children: [
                    // Conditionally show Scan Button or Loading Indicator
                    if (!scanInitiated) // New condition: Show if not currently initiated
                       IconButton(
                         icon: const Icon(Icons.document_scanner_outlined),
                         tooltip: 'Scan for text', // Use hardcoded default
                         onPressed: () => _handleScan(currentImageInfo.id, currentImageInfo.url),
                       )
                    // No need for separate loading indicator, chip handles it
                    ,

                    // Delete Button (show loading overlay if _isDeleting)
                    if (_isDeleting)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete', // Use hardcoded default
                        onPressed: _handleDelete,
                      ),
                 ],
              )
            ],
          ),
        ),
      ),
    );
  }
} 