import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:logger/logger.dart';
import '../models/journey_image_info.dart';
import 'package:http/http.dart' as http;
import '../providers/invoice_capture_provider.dart';
import '../providers/logging_provider.dart';
import '../providers/repository_providers.dart';
import '../repositories/journey_repository.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class InvoiceCaptureDetailView extends ConsumerStatefulWidget {
  const InvoiceCaptureDetailView({
    super.key,
    this.initialIndex = 0,
    required this.journeyId,
    required this.images,
  });

  final int initialIndex;
  final String journeyId;
  final List<JourneyImageInfo> images;

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

  Future<Map<String, String>> _getAuthHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    final token = await user.getIdToken();
    return {
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> _handleScan(String imageId, String? imageUrl) async {
    if (!mounted) return;
    final provider = invoiceCaptureProvider(widget.journeyId);

    if (ref.read(provider).scanningImageId != null) {
      _logger.w(
          'Another scan is already in progress, ignoring request for $imageId');
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan is already in progress.')));
      return;
    }

    _logger.i('Initiating scan for image ID: $imageId');
    ref.read(provider.notifier).initiateScan(imageId);

    try {
      final state = ref.read(provider);
      final images = state.images;
      final currentIdx = images.indexWhere((img) => img.id == imageId);
      if (currentIdx == -1) {
        throw Exception(
            'Current image not found in state after initiating scan.');
      }

      String? urlToDownload = images[currentIdx].url;
      if (urlToDownload.isEmpty) {
        throw Exception('URL to download is null or empty after checks.');
      }

      _logger.d("Attempting to download from: $urlToDownload");
      final httpResponse = await http.get(Uri.parse(urlToDownload));
      _logger.d("Image download status: ${httpResponse.statusCode}");
      if (httpResponse.statusCode != 200) {
        throw Exception("Failed to download image: ${httpResponse.statusCode}");
      }
      _logger.d("Image downloaded (but not used) for scan (ID: $imageId)");

      _logger.i(
          'TODO: Implement Firebase Cloud Function call for scanning image ID: $imageId');
      await Future.delayed(const Duration(seconds: 2));
      _logger.i('Simulated scan success for $imageId');
    } catch (e, stackTrace) {
      _logger.e('[INVOICE_CAPTURE] Error during scan process:',
          error: e, stackTrace: stackTrace);
      ref.read(provider.notifier).setScanError(imageId, e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error scanning image: ${e.toString()}')));
      }
    }
  }

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

  Widget _buildImageView(JourneyImageInfo imageInfo) {
    if (imageInfo.url.isEmpty) {
      _logger
          .w('[INVOICE_CAPTURE] ImageInfo ID ${imageInfo.id} has empty URL.');
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.broken_image, color: Colors.grey, size: 48),
        const SizedBox(height: 16),
        const Text('Image URL is missing',
            style: TextStyle(color: Colors.white)),
      ]));
    }

    if (kIsWeb) {
      return FutureBuilder<String>(
        future: () async {
          try {
            final user = FirebaseAuth.instance.currentUser;
            final token = await user?.getIdToken(true);
            if (token == null) throw Exception('No auth token available');

            final storageRef =
                FirebaseStorage.instance.ref(imageInfo.imagePath);
            final downloadUrl = await storageRef.getDownloadURL();
            _logger.d('[INVOICE_CAPTURE] Generated fresh download URL');
            return downloadUrl;
          } catch (e) {
            _logger.e('[INVOICE_CAPTURE] Error preparing URL:', error: e);
            return imageInfo.url;
          }
        }(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            _logger.e('[INVOICE_CAPTURE] Error getting download URL:',
                error: snapshot.error);
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent),
                  const SizedBox(height: 8),
                  Text('Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white)),
                ],
              ),
            );
          }

          final finalUrl = snapshot.data ?? imageInfo.url;
          return PhotoView(
            imageProvider: CachedNetworkImageProvider(
              finalUrl,
              headers: {
                'Accept': 'image/*',
                'Cache-Control': 'no-cache',
              },
            ),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            loadingBuilder: (context, event) => Center(
              child: CircularProgressIndicator(
                value: event == null
                    ? 0
                    : event.cumulativeBytesLoaded /
                        (event.expectedTotalBytes ?? 1),
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
                    const Text('Error loading image',
                        style: TextStyle(color: Colors.white)),
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
        },
      );
    }

    return PhotoView(
      imageProvider: CachedNetworkImageProvider(
        imageInfo.url,
        headers: {
          'Accept': 'image/*',
          'Cache-Control': 'no-cache',
        },
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
              const Text('Error loading image',
                  style: TextStyle(color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    final images = widget.images;

    if (images.isNotEmpty) {
      if (currentIndex >= images.length) {
        currentIndex = images.length - 1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && pageController.hasClients) {
            pageController.jumpToPage(currentIndex);
          }
        });
      }
    }

    _logger.d('[INVOICE_CAPTURE] Building with ${images.length} images');
    if (images.isNotEmpty) {
      _logger.d('[INVOICE_CAPTURE] First image URL: ${images[0].url}');
    }

    return Scaffold(
      appBar: _showAppBar
          ? AppBar(
              title: Text('Image ${currentIndex + 1} of ${images.length}'),
              actions: [
                if (!_isDeleting)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: _handleDelete,
                    tooltip: 'Delete Image',
                  ),
              ],
            )
          : null,
      body: images.isEmpty
          ? const Center(child: Text('No images available'))
          : PhotoViewGallery.builder(
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
    );
  }

  Future<void> _handleDelete() async {
    final repository = ref.read(journeyRepositoryProvider);
    final images = widget.images;

    if (!mounted) return;
    if (_isDeleting || images.isEmpty || currentIndex >= images.length) return;

    final imageToDelete = images[currentIndex];
    final imageIdToDelete = imageToDelete.id;
    final imagePathToDelete = imageToDelete.imagePath;

    final bool? confirmed = await showDialog<bool>(
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

    if (confirmed != true) {
      _logger.d('Deletion cancelled by user.');
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    if (imagePathToDelete.isEmpty) {
      _logger.e('[INVOICE_CAPTURE] Cannot delete image: imagePath is empty.',
          error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error: Cannot delete image, path is missing.')),
        );
        setState(() {
          _isDeleting = false;
        });
      }
      return;
    }
    final String fileName = p.basename(imagePathToDelete);

    _logger.i(
        'Attempting delete via repository for journey ${widget.journeyId}, image $imageIdToDelete, filename $fileName');

    try {
      await repository.deleteJourneyImage(
          widget.journeyId, imageIdToDelete, fileName);
      _logger.i(
          'Repository delete successful for image ID: $imageIdToDelete, filename: $fileName');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image deleted successfully')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      _logger.e('[INVOICE_CAPTURE] Error deleting image:', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting image: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }
}
