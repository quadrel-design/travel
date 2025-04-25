import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/models/journey.dart';
import '../models/journey_image_info.dart';
import '../models/image_status.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:travel/widgets/image_status_chip.dart';
import 'package:travel/widgets/gallery_detail_view.dart';
import 'package:logger/logger.dart';
import 'package:travel/providers/logging_provider.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Function to determine status (can be moved to a helper file)
ImageStatus determineImageStatus(JourneyImageInfo imageInfo) {
  if (imageInfo.lastProcessedAt != null) {
    if (imageInfo.hasPotentialText == true) {
      return ImageStatus.scanComplete;
    } else {
      return ImageStatus.noTextFound;
    }
  } else {
    // If not processed, assume ready or pending
    return ImageStatus.ready;
  }
}

class GalleryOverviewScreen extends ConsumerStatefulWidget {
  final Journey journey;
  const GalleryOverviewScreen({super.key, required this.journey});

  @override
  ConsumerState<GalleryOverviewScreen> createState() =>
      _GalleryOverviewScreenState();
}

class _GalleryOverviewScreenState extends ConsumerState<GalleryOverviewScreen> {
  late final Logger _logger;

  @override
  void initState() {
    super.initState();
    _logger = ref.read(loggerProvider);
  }

  @override
  void dispose() {
    super.dispose();
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
      _logger.e('[URL_VALIDATION] Error validating URL: $url', error: e);
      return false;
    }
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Watch the stream provider for journey images
    final journeyImagesAsyncValue =
        ref.watch(journeyImagesStreamProvider(widget.journey.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Gallery: ${widget.journey.title}'),
      ),
      body: _buildBody(context, journeyImagesAsyncValue),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _pickAndUploadImage(context),
        heroTag: 'upload',
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }

  Widget _buildImageTile(BuildContext context, JourneyImageInfo imageInfo) {
    if (imageInfo.url.isEmpty) {
      return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
    }

    return CachedNetworkImage(
      imageUrl: imageInfo.url,
      fit: BoxFit.cover,
      httpHeaders: {
        'Accept': 'image/*',
        'Cache-Control': 'no-cache',
      },
      progressIndicatorBuilder: (context, url, progress) {
        return Center(
          child: CircularProgressIndicator(
            value: progress.progress,
          ),
        );
      },
      errorWidget: (context, url, error) {
        _logger.e('[GALLERY_OVERVIEW] Error loading image:', error: error);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent),
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: () => setState(() {}),
                child: const Text('Retry', style: TextStyle(fontSize: 10)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context,
      AsyncValue<List<JourneyImageInfo>> journeyImagesAsyncValue) {
    return journeyImagesAsyncValue.when(
      data: (images) {
        _logger.d(
            '[GALLERY_OVERVIEW] Received ${images.length} images from stream');

        if (images.isEmpty) {
          return const Center(child: Text("No images yet."));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(4.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4.0,
            mainAxisSpacing: 4.0,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            final imageInfo = images[index];
            return GridTile(
              footer: GridTileBar(
                backgroundColor: Colors.black45,
                title: ImageStatusChip(imageInfo: imageInfo),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () => _deleteImage(context, imageInfo),
                  tooltip: 'Delete Image',
                ),
              ),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GalleryDetailView(
                        journeyId: widget.journey.id,
                        initialIndex: index,
                        images: images,
                      ),
                    ),
                  );
                },
                child: _buildImageTile(context, imageInfo),
              ),
            );
          },
        );
      },
      loading: () {
        _logger.d('[GALLERY_OVERVIEW] Loading images...');
        return const Center(child: CircularProgressIndicator());
      },
      error: (error, stack) {
        _logger.e('[GALLERY_OVERVIEW] Error loading images',
            error: error, stackTrace: stack);
        return Center(
          child: Text('Error: $error'),
        );
      },
    );
  }

  Future<void> _deleteImage(
      BuildContext context, JourneyImageInfo imageInfo) async {
    final repo = ref.read(journeyRepositoryProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text("Delete Image?"),
          content: const Text("Are you sure you want to delete this image?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            TextButton(
              child: const Text("Delete"),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      _logger.d("🗑️ Starting image deletion...");
      await repo.deleteJourneyImage(
          widget.journey.id, imageInfo.id, p.basename(imageInfo.imagePath));
      _logger.i("🗑️ Image deleted successfully");

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image deleted successfully.')),
        );
      }
    } catch (e) {
      _logger.e("🗑️ Error deleting image", error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting image: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage(BuildContext context) async {
    final repo = ref.read(journeyRepositoryProvider);
    final picker = ImagePicker();

    try {
      _logger.d("📸 Starting image picker...");
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) {
        _logger.d("📸 User canceled picking image");
        return;
      }

      _logger.d("📸 Reading file bytes");
      final fileBytes = await pickedFile.readAsBytes();
      final fileName = p.basename(pickedFile.path);
      _logger.d("📸 File: $fileName, size: ${fileBytes.length} bytes");

      _logger.d("📸 Starting repository upload...");
      final uploadResult =
          await repo.uploadJourneyImage(widget.journey.id, fileBytes, fileName);

      _logger.i("📸 Repository upload completed successfully");
      _logger.d("📸 Upload result: ${uploadResult.id} - ${uploadResult.url}");

      if (context.mounted) {
        _logger.d("📸 Showing success message");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image uploaded successfully!')),
        );
      }
    } catch (e, stack) {
      _logger.e("📸 ERROR DURING UPLOAD: $e", error: e, stackTrace: stack);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
