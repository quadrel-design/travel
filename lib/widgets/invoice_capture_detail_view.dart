import 'dart:async';
import 'dart:convert';
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
import '../providers/service_providers.dart' as service;
import 'package:path/path.dart' as p;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/location_service_provider.dart';
import './invoice_analysis_panel.dart';
import 'package:travel/widgets/invoice_detail_bottom_bar.dart';
import 'package:travel/widgets/invoice_image_gallery.dart';
import 'package:travel/widgets/invoice_capture_feedback_widgets.dart';
import 'package:travel/widgets/invoice_capture_controller.dart';
import '../services/gcs_file_service.dart';

class InvoiceCaptureDetailView extends ConsumerStatefulWidget {
  const InvoiceCaptureDetailView({
    super.key,
    this.initialIndex = 0,
    required this.projectId,
    required this.invoiceId,
  });

  final int initialIndex;
  final String projectId;
  final String invoiceId;

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
  final bool _isAnalyzing = false;
  late Logger _logger;
  late String invoiceId;
  late InvoiceCaptureController _controller;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    pageController = PageController(initialPage: widget.initialIndex);
    _logger = ref.read(loggerProvider);
    invoiceId = widget.invoiceId;
    _controller = InvoiceCaptureController(
        ref: ref,
        logger: _logger,
        context: context,
        projectId: widget.projectId,
        invoiceId: invoiceId,
        setState: setState,
        getCurrentIndex: () => currentIndex,
        getImages: () => ref
            .read(invoiceCaptureProvider(
                (projectId: widget.projectId, invoiceId: invoiceId)))
            .images);
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  /// Build the image view component
  Widget _buildImageView(InvoiceImageProcess imageInfo) {
    if (imageInfo.url.isEmpty) {
      _logger
          .w('[INVOICE_CAPTURE] ImageInfo ID \\${imageInfo.id} has empty URL.');
      return const ImageErrorWidget(message: 'Image URL is missing');
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
          return const LoadingIndicatorWidget();
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

      // If existing URL is invalid, try to get a fresh one from GCS
      try {
        final gcsFileService = ref.read(service.gcsFileServiceProvider);
        final fileBytes =
            await gcsFileService.downloadFile(fileName: imageInfo.imagePath);
        // Convert bytes to base64 for display
        final base64Image = base64Encode(fileBytes);
        final mimeType = 'image/jpeg'; // or determine from file extension
        return 'data:$mimeType;base64,$base64Image';
      } catch (storageError) {
        _logger.w(
            '[INVOICE_CAPTURE] Failed to get fresh URL from GCS, falling back to original URL',
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
          'Bearer \\${FirebaseAuth.instance.currentUser?.getIdToken() ?? ''}';
    }

    return PhotoView(
      imageProvider: CachedNetworkImageProvider(
        imageUrl,
        headers: headers,
      ),
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      loadingBuilder: (context, event) => const LoadingIndicatorWidget(),
      errorBuilder: (context, error, stackTrace) {
        _logger.e('[INVOICE_CAPTURE] Error loading image:',
            error: error, stackTrace: stackTrace);
        return ImageErrorWidget(
          message: isWeb
              ? 'Error loading image: \\${error.toString()}'
              : 'Error loading image',
          onRetry: () => setState(() {}),
        );
      },
    );
  }

  Widget _buildAnalysisPanel(InvoiceImageProcess imageInfo) {
    if (!_showAnalysis) return const SizedBox.shrink();

    // Check if there's any data to show
    final bool hasData = imageInfo.ocrText != null;

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
        (projectId: widget.projectId, invoiceId: widget.invoiceId));
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
      body: images.isEmpty
          ? const Center(child: Text('No images available'))
          : Stack(
              children: [
                InvoiceImageGallery(
                  images: images,
                  currentIndex: currentIndex,
                  pageController: pageController,
                  onPageChanged: (index) {
                    setState(() {
                      currentIndex = index;
                    });
                  },
                ),
                if (_showAnalysis && images.isNotEmpty)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.7),
                      child: InvoiceAnalysisPanel(
                        imageInfo: images[currentIndex],
                        onClose: () => setState(() => _showAnalysis = false),
                        logger: _logger,
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: InvoiceDetailBottomBar(
        onUpload: null,
        onScan: images.isNotEmpty ? () => _controller.handleScan() : null,
        onInfo: null,
        onFavorite: null,
        onSettings: null,
        onDelete: images.isNotEmpty ? () => _controller.handleDelete() : null,
      ),
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
            onPressed: () => _controller.handleScan(),
            tooltip: 'Scan Invoice',
          ),
        if (!_isDeleting)
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () async {
              print('Analyze button pressed!');
              setState(() => _showAnalysis = false);
              await _controller.handleAnalyze();
              setState(() => _showAnalysis = true);
            },
            tooltip: 'Analyze Invoice',
          ),
        if (!_isDeleting)
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _controller.handleDelete(),
            tooltip: 'Delete Image',
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
                _controller.handleScan();
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
}
