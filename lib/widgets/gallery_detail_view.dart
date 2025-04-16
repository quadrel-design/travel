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
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    pageController = PageController(initialPage: widget.initialIndex);
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

  Future<void> _handleScan(String imageId, String? imageUrl) async {
    if (!mounted) return;

    // Check if another scan is already in progress globally for this view
    if (ref.read(galleryDetailProvider(widget.images)).scanningImageId != null) {
      widget.logger.w('Another scan is already in progress, ignoring request for $imageId');
      // Optionally show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Another scan is already running.')) // TODO: Localize
      );
      return;
    }

    widget.logger.i('Initiating scan for image ID: $imageId');

    // Call the updated notifier method to set scanning state and clear old results
    ref.read(galleryDetailProvider(widget.images).notifier).initiateScan(imageId);

    try {
      // Get the signed URL from the provider state
      final state = ref.read(galleryDetailProvider(widget.images)); // Read state *after* initiating
      final signedUrls = state.signedUrls;
      final images = state.images; // Needed for current index check
      // Find the current index *again* in case the list changed (unlikely here, but safer)
      final currentIdx = images.indexWhere((img) => img.id == imageId);
      if (currentIdx == -1) {
           throw Exception('Current image not found in state after initiating scan.');
      }

      String? urlToDownload = imageUrl; // Fallback to public URL passed initially

      if (currentIdx < signedUrls.length && signedUrls[currentIdx] != null) {
        urlToDownload = signedUrls[currentIdx]!;
        widget.logger.d("Using signed URL for download: $urlToDownload");
      } else if (imageUrl != null) {
        widget.logger.w("Signed URL not available or index mismatch for index $currentIdx. Falling back to initial public URL: $imageUrl");
      } else {
        throw Exception('Image URL is null, cannot download.');
      }

      if (urlToDownload == null) {
        throw Exception('URL to download is null after checks.');
      }

      widget.logger.d("Attempting to download from: $urlToDownload");
      final httpResponse = await http.get(Uri.parse(urlToDownload));
      widget.logger.d("Image download status: ${httpResponse.statusCode}");

      if (httpResponse.statusCode != 200) {
        throw Exception("Failed to download image: ${httpResponse.statusCode}");
      }

      final imageBytes = httpResponse.bodyBytes;
      final imageBase64 = base64Encode(imageBytes);
      widget.logger.d("Image downloaded and encoded for scan (ID: $imageId)");

      widget.logger.d("Invoking Edge Function 'detect-invoice-text'...");
      final response = await Supabase.instance.client.functions.invoke(
        'detect-invoice-text',
        body: {
          'image_base64': imageBase64,
          'journey_image_id': imageId,
        },
      );
      widget.logger.d("Edge Function response status: ${response.status}");

      if (response.status != 200) {
        final errorMsg = response.data?['error'] ?? 'Unknown error';
        widget.logger.e('Edge function invocation failed with status ${response.status}', error: response.data);
        throw Exception('Failed to process image: $errorMsg');
      }

      widget.logger.i('Edge function call successful for scan (ID $imageId). DB update pending via Realtime.');
      // No need to set state here, Realtime listener or error handler clears scanningImageId

    } catch (e, stackTrace) {
      widget.logger.e('Error during scan process for image ID $imageId', error: e, stackTrace: stackTrace);
      // Set error state in provider (this will also clear scanningImageId)
      ref.read(galleryDetailProvider(widget.images).notifier).setScanError(imageId, e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning image: ${e.toString()}')) // Consider localizing
        );
      }
    }
    // No finally block needed to manage scanning state, handled by provider
  }

  Future<void> _handleDelete() async {
    // Get images from provider
    final images = ref.read(galleryDetailProvider(widget.images)).images;
    if (!mounted) return;
    if (_isDeleting || images.isEmpty || currentIndex >= images.length) return;

    final imageToDelete = images[currentIndex];
    final imageUrlToDelete = imageToDelete.url;
    final imageIdToDelete = imageToDelete.id;

    // --- Add Confirmation Dialog --- 
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        // final l10n = AppLocalizations.of(context)!; // Use placeholders for now
        return AlertDialog(
          // title: Text(l10n.deleteImageConfirmationTitle),
          title: const Text('Delete Image?'), // Placeholder
          // content: Text(l10n.deleteImageConfirmationContent),
          content: const Text('Are you sure you want to permanently delete this image?'), // Placeholder
          actions: <Widget>[
            TextButton(
              // child: Text(l10n.cancelButton),
              child: const Text('Cancel'), // Placeholder
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              // child: Text(l10n.deleteButton),
              child: const Text('Delete'), // Placeholder
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    // If the user didn't confirm, stop here
    if (confirmed != true) {
      widget.logger.d('Deletion cancelled by user.');
      return;
    }
    // --- End Confirmation Dialog ---

    setState(() { _isDeleting = true; });
    widget.logger.i('Attempting delete via callback for: $imageUrlToDelete (ID: $imageIdToDelete)');

    try {
      await widget.onDeleteImage(imageUrlToDelete); // Call the passed callback
      widget.logger.i('Parent delete callback successful for: $imageUrlToDelete');

      // The parent (Overview Screen) is responsible for its own success message/handling
      // widget.onImageDeletedSuccessfully(imageUrlToDelete); // Maybe not needed here?

      // Provider state update is crucial for removing the image from *this* view
      if (mounted) {
          ref.read(galleryDetailProvider(widget.images).notifier).handleDeletion(imageIdToDelete);
          widget.logger.i('Called handleDeletion on notifier for ID: $imageIdToDelete');
          // Check if the list became empty after deletion
          final remainingImages = ref.read(galleryDetailProvider(widget.images)).images;
          if (remainingImages.isEmpty && mounted) {
             widget.logger.i('Image list empty after deletion, popping detail view.');
             Navigator.of(context).pop(); // Go back if no images left
          }
      }

    } catch (e) {
        widget.logger.e('Error during parent delete callback for $imageUrlToDelete', error: e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            // SnackBar(content: Text(l10n.deleteImageErrorSnackbar(e.toString()))),
            SnackBar(content: Text('Error deleting image: ${e.toString()}')) // Placeholder
          );
        }
    } finally {
        if (mounted) setState(() { _isDeleting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(galleryDetailProvider(widget.images));
    final images = state.images;
    final signedUrls = state.signedUrls;
    final isLoadingSignedUrls = state.isLoadingSignedUrls;
    final generalError = state.generalError; // Watch general error
    final notifier = ref.read(galleryDetailProvider(widget.images).notifier); // Read notifier for actions

    final NumberFormat currencyFormatter = NumberFormat.currency(
      locale: 'de_DE', // Example locale, adjust as needed
      symbol: '', // Use currency code from data if available
      decimalDigits: 2,
    );

    if (images.isEmpty && generalError == null) {
      return const Center(child: Text('No images yet.'));
    }

    // Ensure currentIndex is valid after potential deletions
    currentIndex = min(currentIndex, images.length - 1);
    if (currentIndex < 0) currentIndex = 0; // Handle case where list becomes empty

    // Access current image data safely AFTER adjusting currentIndex
    final currentImageInfo = images.isNotEmpty ? images[currentIndex] : null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(context, state, currentImageInfo, notifier),
      body: Column(
        children: [
          if (generalError != null)
            MaterialBanner(
              padding: const EdgeInsets.all(10),
              content: Text(generalError, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              leading: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
              actions: [
                TextButton(
                  child: const Text('DISMISS'), // Placeholder
                  onPressed: () {
                    notifier.clearGeneralError();
                  },
                ),
              ],
            ),
          
          Expanded(
            child: _buildGalleryBody(context, state, currencyFormatter),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, GalleryDetailState state, JourneyImageInfo? currentImageInfo, GalleryDetailNotifier notifier) {
    final images = state.images;
    final scanningImageId = state.scanningImageId; // Get scanning state

    // Determine if the *current* image is being scanned
    final bool isCurrentItemScanning = currentImageInfo != null && scanningImageId == currentImageInfo.id;
    // Determine if *any* image is being scanned (to disable button)
    final bool isAnyItemScanning = scanningImageId != null;

    return AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text('${currentIndex + 1} / ${images.length}'), // Placeholder
      centerTitle: true,
      actions: [
        IconButton(
          // Show spinner only if the *current* image is scanning
          icon: isCurrentItemScanning
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.document_scanner_outlined),
          // Disable button if *any* item is scanning or current info is null
          onPressed: currentImageInfo == null || isAnyItemScanning
                ? null
                : () => _handleScan(currentImageInfo.id, currentImageInfo.url),
          tooltip: 'Scan Image', // Placeholder
        ),
        IconButton(
          icon: _isDeleting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.delete_outline),
          // Disable delete if an item is scanning (to avoid conflicts? Optional)
          onPressed: _isDeleting || currentImageInfo == null || isAnyItemScanning ? null : _handleDelete,
          tooltip: 'Delete Image', // Placeholder
        ),
      ],
    );
  }

  Widget _buildGalleryBody(BuildContext context, GalleryDetailState state, NumberFormat currencyFormatter) {
    final images = state.images;
    final signedUrls = state.signedUrls;
    final isLoadingSignedUrls = state.isLoadingSignedUrls;
    final scanningImageId = state.scanningImageId; // Get scanning ID from state

    // Determine image provider based on signed URL availability and loading state
    ImageProvider imageProvider;
    bool showLoadingIndicator = isLoadingSignedUrls || (currentIndex >= signedUrls.length || signedUrls[currentIndex] == null);

    if (!showLoadingIndicator) {
      imageProvider = CachedNetworkImageProvider(signedUrls[currentIndex]!); 
    } else if (images.isNotEmpty && currentIndex < images.length) {
      // Fallback to public URL if signed URL is loading/failed but we have the public one
      imageProvider = CachedNetworkImageProvider(images[currentIndex].url);
    } else {
      // Should ideally not happen if images list is not empty, but provide a placeholder
      imageProvider = const AssetImage('assets/placeholder.png'); // Ensure you have a placeholder asset
    }

    return Column(
      children: [
        Expanded(
          child: PhotoViewGallery.builder(
            pageController: pageController,
            itemCount: images.length,
            builder: (context, index) {
              // Recalculate provider for each item using provider state
              ImageProvider itemImageProvider;
              bool itemShowLoadingIndicator = isLoadingSignedUrls || (index >= signedUrls.length || signedUrls[index] == null);

              if (!itemShowLoadingIndicator) {
                 itemImageProvider = CachedNetworkImageProvider(signedUrls[index]!); 
              } else {
                 itemImageProvider = CachedNetworkImageProvider(images[index].url); // Fallback
              }

              return PhotoViewGalleryPageOptions(
                imageProvider: itemImageProvider,
                minScale: PhotoViewComputedScale.contained * 0.8,
                maxScale: PhotoViewComputedScale.covered * 2,
                initialScale: PhotoViewComputedScale.contained,
                heroAttributes: PhotoViewHeroAttributes(tag: images[index].id),
              );
            },
            onPageChanged: (index) {
              setState(() {
                currentIndex = index;
              });
            },
            loadingBuilder: (context, event) => const Center(
              child: SizedBox(
                width: 20.0,
                height: 20.0,
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
        ),
        if (state.images.isNotEmpty && currentIndex < state.images.length)
          _buildInfoPanel(context, state.images[currentIndex], currencyFormatter, state.scanError[state.images[currentIndex].id], scanningImageId),
      ],
    );
  }

  Widget _buildInfoPanel(BuildContext context, JourneyImageInfo imageInfo, NumberFormat currencyFormatter, String? scanError, String? scanningImageId) {
    // Determine if this specific image is being scanned
    bool isScanning = scanningImageId == imageInfo.id;

    Widget statusWidget;
    if (scanError != null) {
        statusWidget = const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, color: Colors.red, size: 16),
          SizedBox(width: 4),
          Text('Scan Error', style: TextStyle(color: Colors.red)), // Placeholder
        ]);
    } else if (isScanning) {
        statusWidget = const Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
          SizedBox(width: 4),
          Text('Processing...', style: TextStyle(color: Colors.orange)), // Placeholder
        ]);
    } else if (imageInfo.lastProcessedAt != null && imageInfo.hasPotentialText == true) {
        statusWidget = const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
          SizedBox(width: 4),
          Text('Scan Complete', style: TextStyle(color: Colors.green)), // Placeholder
        ]);
    } else if (imageInfo.lastProcessedAt != null && imageInfo.hasPotentialText == false) {
        statusWidget = const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cancel_outlined, color: Colors.grey, size: 16),
          SizedBox(width: 4),
          Text('No Text Found', style: TextStyle(color: Colors.grey)), // Placeholder
        ]);
    } else {
        statusWidget = const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.help_outline, color: Colors.grey, size: 16),
          SizedBox(width: 4),
          Text('Ready to Scan', style: TextStyle(color: Colors.grey)), // Placeholder
        ]);
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.black.withOpacity(0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               const Text('Scan Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
               statusWidget,
             ],
          ),
          if (scanError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(scanError, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          const SizedBox(height: 8),
          if (imageInfo.lastProcessedAt != null && imageInfo.hasPotentialText == true)
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                  const Text('Detected Amount', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(
                    imageInfo.detectedTotalAmount != null
                        ? '${currencyFormatter.format(imageInfo.detectedTotalAmount)} ${imageInfo.detectedCurrency ?? ''}'.trim()
                        : 'N/A', // Placeholder
                    style: const TextStyle(color: Colors.white),
                  ),
               ],
             ),
           if (imageInfo.lastProcessedAt != null)
             Padding(
               padding: const EdgeInsets.only(top: 4.0),
               child: Text(
                 'Last Processed: ${DateFormat.yMd().add_jm().format(imageInfo.lastProcessedAt!.toLocal())}', // Placeholder
                 style: const TextStyle(color: Colors.grey, fontSize: 10),
               ),
             ),
        ],
      ),
    );
  }
} 