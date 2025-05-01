import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:logger/logger.dart';
import '../models/invoice_image_process.dart';
import 'package:http/http.dart' as http;
import '../providers/invoice_capture_provider.dart';
import '../providers/logging_provider.dart';
import '../providers/repository_providers.dart';
import '../providers/firebase_functions_provider.dart';
import 'package:path/path.dart' as p;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/location_service_provider.dart';
import './invoice_analysis_panel.dart';

class InvoiceCaptureDetailView extends ConsumerStatefulWidget {
  const InvoiceCaptureDetailView({
    super.key,
    this.initialIndex = 0,
    required this.projectId,
  });

  final int initialIndex;
  final String projectId;

  @override
  ConsumerState<InvoiceCaptureDetailView> createState() {
    return _InvoiceCaptureDetailViewState();
  }
}

class _InvoiceCaptureDetailViewState
    extends ConsumerState<InvoiceCaptureDetailView> {
  late PageController pageController;
  late int currentIndex;
  bool _isDeleting = false;
  bool _showAppBar = true;
  bool _showAnalysis = false;
  bool _isAnalyzing = false;
  late Logger _logger;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    pageController = PageController(initialPage: widget.initialIndex);
    _logger = ref.read(loggerProvider);
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  /// Handle scanning the current image
  Future<void> _handleScan(String imageId, String? imageUrl) async {
    if (!mounted) return;
    final provider = invoiceCaptureProvider(
        (projectId: widget.projectId, invoiceId: 'main'));

    _logger.i('Initiating scan for image ID: $imageId');
    ref.read(provider.notifier).initiateScan(imageId);

    // Timer for OCR timeout
    Timer? timeoutTimer;
    timeoutTimer = Timer(const Duration(seconds: 60), () {
      if (mounted) {
        _logger.e('[INVOICE_CAPTURE] OCR timed out after 60 seconds');
        ref.read(provider.notifier).setScanError(imageId, "OCR timed out");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OCR process timed out')),
        );
      }
      timeoutTimer?.cancel();
    });

    try {
      // Get the current image info from state
      final state = ref.read(provider);
      final images = state.images;
      final currentIdx = images.indexWhere((img) => img.id == imageId);
      if (currentIdx == -1) {
        throw Exception(
            'Current image not found in state after initiating scan.');
      }

      final imageToScan = images[currentIdx];
      final urlToDownload = imageToScan.url;

      // Validate URL
      if (urlToDownload.isEmpty) {
        throw Exception('Image URL is empty. Cannot proceed with scan.');
      }

      // Download the image to verify it exists
      _logger.d("Attempting to download from: $urlToDownload");
      final httpResponse = await http.get(Uri.parse(urlToDownload));
      _logger.d("Image download status: ${httpResponse.statusCode}");
      if (httpResponse.statusCode != 200) {
        throw Exception("Failed to download image: ${httpResponse.statusCode}");
      }
      _logger.d("Image downloaded successfully for scan (ID: $imageId)");

      // Call the Firebase Cloud Function to perform OCR and analysis
      final functionsService = ref.read(firebaseFunctionsProvider);
      _logger
          .i('Calling Firebase Cloud Function for scanning image ID: $imageId');

      final result = await functionsService.scanImage(
        urlToDownload,
        widget.projectId,
        imageId,
      );

      // Cancel timeout timer as operation completed
      timeoutTimer.cancel();

      _logger.i('Scan completed for $imageId: ${result['success']}');
      _logger.d('Full result from scan: $result');

      if (result['success'] == true) {
        if (mounted) {
          _showScanResultMessage(result);
        }

        await _processAndStoreScanResults(result, images[currentIdx].id);
      } else {
        throw Exception(result['error'] ?? 'Unknown error during scan');
      }
    } catch (e, stackTrace) {
      // Cancel timeout timer
      timeoutTimer.cancel();

      _logger.e('[INVOICE_CAPTURE] Error during scan process:',
          error: e, stackTrace: stackTrace);

      ref.read(provider.notifier).setScanError(imageId, e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error scanning image: ${e.toString()}')));
      }
    }
  }

  /// Show appropriate message based on scan result
  void _showScanResultMessage(Map<String, dynamic> result) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scan completed.')),
    );
  }

  /// Process scan results and store in repository
  Future<void> _processAndStoreScanResults(
      Map<String, dynamic> result, String imageId) async {
    // Store the OCR results using the repository
    final repository = ref.read(projectRepositoryProvider);

    // Extract invoice analysis data if available
    Map<String, dynamic>? invoiceAnalysis;
    if (result.containsKey('invoiceAnalysis') &&
        result['invoiceAnalysis'] != null) {
      invoiceAnalysis = result['invoiceAnalysis'] as Map<String, dynamic>;
      _logger.d('Invoice analysis data: $invoiceAnalysis');
    }

    // Only validate location if we have invoice analysis
    String? validatedLocation;
    if (invoiceAnalysis?['location'] != null) {
      final locationService = ref.read(locationServiceProvider);
      final placeId =
          await locationService.findPlaceId(invoiceAnalysis!['location']);
      if (placeId != null) {
        final placeDetails = await locationService.getPlaceDetails(placeId);
        if (placeDetails != null) {
          validatedLocation = placeDetails['formatted_address'] as String;
          _logger.i('Location validated: $validatedLocation');
        }
      }
    }

    // Determine if it's an invoice
    bool isInvoice = false;
    if (invoiceAnalysis != null && invoiceAnalysis['isInvoice'] is bool) {
      isInvoice = invoiceAnalysis['isInvoice'];
    }

    _logger.i('Updating image with status: $isInvoice');

    // Update the repository with all the processed data
    await repository.updateImageWithOcrResults(
      widget.projectId,
      imageId,
      isInvoice: isInvoice,
    );

    // Note: Store validatedLocation in a log for now since the repository doesn't support it
    if (validatedLocation != null) {
      _logger.i('Validated location found but not stored: $validatedLocation');
      // TODO: Add support for storing location in the repository
    }

    _logger.i('OCR results stored for image $imageId with status: $isInvoice');
  }

  /// Validate if an image URL is valid and accessible
  Future<bool> _validateImageUrl(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      _logger.d(
          '[URL_VALIDATION] Status code: ${response.statusCode} for URL: $url');
      _logger.d('[URL_VALIDATION] Headers: ${response.headers}');
      return response.statusCode == 200 &&
          response.headers['content-type']?.startsWith('image/') == true;
    } catch (e) {
      _logger.e('[INVOICE_CAPTURE] Error validating image URL:', error: e);
      return false;
    }
  }

  /// Build the image view component
  Widget _buildImageView(InvoiceImageProcess imageInfo) {
    if (imageInfo.url.isEmpty) {
      _logger
          .w('[INVOICE_CAPTURE] ImageInfo ID ${imageInfo.id} has empty URL.');
      return const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.broken_image, color: Colors.grey, size: 48),
        SizedBox(height: 16),
        Text('Image URL is missing', style: TextStyle(color: Colors.white)),
      ]));
    }

    if (kIsWeb) {
      return _buildWebImageView(imageInfo);
    }

    return _buildMobileImageView(imageInfo);
  }

  Widget _buildWebImageView(InvoiceImageProcess imageInfo) {
    return FutureBuilder<String>(
      future: _getValidImageUrl(imageInfo),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final finalUrl = snapshot.data ?? imageInfo.url;
        return _buildPhotoView(finalUrl, true);
      },
    );
  }

  Widget _buildMobileImageView(InvoiceImageProcess imageInfo) {
    return _buildPhotoView(imageInfo.url, false);
  }

  Future<String> _getValidImageUrl(InvoiceImageProcess imageInfo) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken(true);
      if (token == null) {
        _logger.w(
            '[INVOICE_CAPTURE] No auth token available, falling back to original URL');
        return imageInfo.url;
      }

      // First try to validate the existing URL
      if (await _validateImageUrl(imageInfo.url)) {
        _logger.d('[INVOICE_CAPTURE] Existing URL is valid, using it');
        return imageInfo.url;
      }

      // If existing URL is invalid, try to get a fresh one
      try {
        final storageRef = FirebaseStorage.instance.ref(imageInfo.imagePath);
        final downloadUrl = await storageRef.getDownloadURL();
        _logger.d('[INVOICE_CAPTURE] Generated fresh download URL');
        return downloadUrl;
      } catch (storageError) {
        _logger.w(
            '[INVOICE_CAPTURE] Failed to get fresh URL from storage, falling back to original URL',
            error: storageError);
        return imageInfo.url;
      }
    } catch (e) {
      _logger.e('[INVOICE_CAPTURE] Error preparing URL:', error: e);
      return imageInfo.url; // Fall back to original URL
    }
  }

  Widget _buildPhotoView(String imageUrl, bool isWeb) {
    Map<String, String> headers = {
      'Accept': 'image/*',
      'Cache-Control': 'no-cache',
    };

    if (isWeb) {
      headers['Authorization'] =
          'Bearer ${FirebaseAuth.instance.currentUser?.getIdToken() ?? ''}';
    }

    return PhotoView(
      imageProvider: CachedNetworkImageProvider(
        imageUrl,
        headers: headers,
      ),
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      loadingBuilder: (context, event) => Center(
        child: CircularProgressIndicator(
          value: event == null
              ? 0
              : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
        ),
      ),
      errorBuilder: (context, error, stackTrace) {
        _logger.e('[INVOICE_CAPTURE] Error loading image:',
            error: error, stackTrace: stackTrace);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent),
              const SizedBox(height: 8),
              Text(
                  isWeb
                      ? 'Error loading image: ${error.toString()}'
                      : 'Error loading image',
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => setState(() {}),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalysisPanel(InvoiceImageProcess imageInfo) {
    if (!_showAnalysis) return const SizedBox.shrink();

    // Check if there's any data to show
    final bool hasData = imageInfo.extractedText != null;

    if (!hasData) {
      return const Center(
        child: Text(
          'No analysis data available for this image',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return InvoiceAnalysisPanel(
      imageInfo: imageInfo,
      onClose: () => setState(() => _showAnalysis = false),
      logger: _logger,
    );
  }

  @override
  Widget build(BuildContext context) {
    print('InvoiceCaptureDetailView build called');
    final provider = invoiceCaptureProvider(
        (projectId: widget.projectId, invoiceId: 'main'));
    final state = ref.watch(provider);
    final images = state.images;

    // Debug logging: print all images received
    _logger.d('[INVOICE_CAPTURE] UI received ${images.length} images:');
    for (final img in images) {
      _logger.d(
          '[INVOICE_CAPTURE] Image: id=${img.id}, url=${img.url}, imagePath=${img.imagePath}');
    }

    // Handle case when images are removed
    if (images.isNotEmpty && currentIndex >= images.length) {
      currentIndex = images.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && pageController.hasClients) {
          pageController.jumpToPage(currentIndex);
        }
      });
    }

    _logger.d('[INVOICE_CAPTURE] Building with ${images.length} images');
    if (images.isNotEmpty) {
      _logger.d('[INVOICE_CAPTURE] First image URL: ${images[0].url}');
    }

    return Scaffold(
      appBar: _buildAppBar(images),
      body: _buildBody(images),
    );
  }

  PreferredSizeWidget? _buildAppBar(List<InvoiceImageProcess> images) {
    if (!_showAppBar) return null;

    return AppBar(
      title: Text('Image ${currentIndex + 1} of ${images.length}'),
      actions: [
        if (!_isDeleting)
          IconButton(
            icon: const Icon(Icons.document_scanner),
            onPressed: () =>
                _handleScan(images[currentIndex].id, images[currentIndex].url),
            tooltip: 'Scan Invoice',
          ),
        if (!_isDeleting)
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () async {
              print('Analyze button pressed!');
              setState(() => _showAnalysis = false);
              final imageInfo = images[currentIndex];
              final functionsService = ref.read(firebaseFunctionsProvider);
              // Debug print for function call parameters
              print('Calling analyzeImage with:');
              print('  projectId: \\${widget.projectId}');
              print('  invoiceId: main');
              print('  imageId: \\${imageInfo.id}');
              print('  extractedText: \\${imageInfo.extractedText}');
              await functionsService.analyzeImage(
                imageInfo.extractedText ?? '',
                widget.projectId, // projectId
                imageInfo.id, // imageId
              );
              // Wait a moment for Firestore to update
              await Future.delayed(const Duration(seconds: 1));
              setState(() => _showAnalysis = true);
            },
            tooltip: 'Analyze Invoice',
          ),
        if (!_isDeleting)
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _handleDelete,
            tooltip: 'Delete Image',
          ),
      ],
    );
  }

  Widget _buildBody(List<InvoiceImageProcess> images) {
    if (images.isEmpty) {
      return const Center(child: Text('No images available'));
    }

    return Stack(
      children: [
        PhotoViewGallery.builder(
          scrollPhysics: const BouncingScrollPhysics(),
          builder: (BuildContext context, int index) {
            final imageInfo = images[index];
            _logger.d(
                '[INVOICE_CAPTURE] Loading image ${index + 1}/${images.length}: ${imageInfo.url}');

            return PhotoViewGalleryPageOptions.customChild(
              child: _buildImageView(imageInfo),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
              heroAttributes: PhotoViewHeroAttributes(tag: imageInfo.id),
              onTapUp: (_, __, ___) {
                setState(() {
                  _showAppBar = !_showAppBar;
                });
              },
            );
          },
          itemCount: images.length,
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          pageController: pageController,
          onPageChanged: (index) {
            setState(() {
              currentIndex = index;
            });
          },
        ),
        if (_showAnalysis)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildAnalysisPanel(images[currentIndex]),
          ),
      ],
    );
  }

  Widget _buildStatusChip(InvoiceImageProcess imageInfo) {
    // Remove: final status = InvoiceCaptureStatus.fromFirebaseStatus(imageInfo.status);

    // Remove all code that checks or displays imageInfo.status or InvoiceCaptureStatus.

    // Return empty container if no status to show
    return const SizedBox.shrink();
  }

  // Show error details and retry option
  void _showErrorDetails(InvoiceImageProcess imageInfo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('OCR Processing Error'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The system encountered an error while trying to process this image.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('Possible reasons:'),
              const SizedBox(height: 8),
              _buildErrorItem('The image might not contain readable text'),
              _buildErrorItem('The image format might not be supported'),
              _buildErrorItem('Network connection issues'),
              _buildErrorItem('Server timeout or processing error'),
              const SizedBox(height: 16),
              const Text('Would you like to try again?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleScan(imageInfo.id, imageInfo.url);
              },
              child: const Text('Retry'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Future<void> _handleDelete() async {
    final repository = ref.read(projectRepositoryProvider);
    final provider = invoiceCaptureProvider(
        (projectId: widget.projectId, invoiceId: 'main'));
    final state = ref.read(provider);
    final images = state.images;

    if (!mounted) return;
    if (_isDeleting || images.isEmpty || currentIndex >= images.length) return;

    final imageToDelete = images[currentIndex];
    final imageIdToDelete = imageToDelete.id;
    final imagePathToDelete = imageToDelete.imagePath;

    final bool? confirmed = await _showDeleteConfirmationDialog();
    if (confirmed != true) {
      _logger.d('Deletion cancelled by user.');
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    if (imagePathToDelete.isEmpty) {
      _handleDeleteError('Cannot delete image: imagePath is empty.');
      return;
    }

    final String fileName = p.basename(imagePathToDelete);

    _logger.i(
        'Attempting delete via repository for project ${widget.projectId}, image $imageIdToDelete, filename $fileName');

    try {
      await repository.deleteInvoiceImage(
        widget.projectId,
        images[currentIndex].id,
      );
      _logger.i(
          'Repository delete successful for image ID: $imageIdToDelete, filename: $fileName');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image deleted successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      _handleDeleteError('Error deleting image: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  void _handleDeleteError(String message) {
    _logger.e('[INVOICE_CAPTURE] $message', error: message);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      setState(() {
        _isDeleting = false;
      });
    }
  }

  Future<bool?> _showDeleteConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Image?'),
          content: const Text(
              'Are you sure you want to permanently delete this image?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }
}
