import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:travel/models/journey.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:travel/providers/logging_provider.dart';
import 'package:logger/logger.dart';
import '../widgets/full_screen_confirm_dialog.dart';
import '../models/journey_image_info.dart';
import 'package:http/http.dart' as http; // Keep for GalleryDetailView dependency if needed elsewhere
import 'dart:math';
import '../widgets/gallery_detail_view.dart';
import 'dart:convert';
import '../widgets/image_status_chip.dart';

// Change to ConsumerWidget
class GalleryOverviewScreen extends ConsumerWidget { // Changed from ConsumerStatefulWidget
  final Journey journey;
  const GalleryOverviewScreen({super.key, required this.journey});

  // --- Remove State Logic --- 
  // State variables removed (_isLoadingImages, _imageError, _journeyImages, _isUploading)
  // initState, dispose, didChangeDependencies removed
  // _loadImages method removed
  // --- End Remove State Logic --- 

  // Keep _addImage (will need ref to access logger and potentially providers)
  Future<void> _addImage(BuildContext context, WidgetRef ref) async {
    // Access logger from ref
    final logger = ref.read(loggerProvider);
    // Access repository if needed for deleteImage (passed to GalleryDetailView)
    final journeyRepository = ref.read(journeyRepositoryProvider);

    // Read upload state locally if needed, or manage via a separate provider
    // For simplicity, let's keep _isUploading via StatefulWidget for now
    // TODO: Refactor _isUploading state management if desired

    final picker = ImagePicker();
    // final scaffoldMessenger = ScaffoldMessenger.of(context); // Get ScaffoldMessenger

    try {
      final List<XFile> pickedFiles = await picker.pickMultiImage();
      // No need for mounted check in ConsumerWidget
      if (pickedFiles.isEmpty) return;
      // setState(() { _isUploading = true; }); // Requires State

      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("User not logged in.");

      int successCount = 0;
      List<String> errorMessages = [];
      for (final pickedFile in pickedFiles) {
        try {
          final imageRecordId = const Uuid().v4();
          logger.d('Generated image record ID: $imageRecordId for ${pickedFile.name}');
          final imageBytes = await pickedFile.readAsBytes();
          
          final fileExt = p.extension(pickedFile.name);
          final fileName = '$imageRecordId$fileExt';
          final filePath = '$userId/${journey.id}/$fileName';

          logger.d('Uploading binary for $fileName...');
          await supabase.storage.from('journey_images').uploadBinary(
                filePath, imageBytes, fileOptions: FileOptions(contentType: pickedFile.mimeType));
          final imageUrl = supabase.storage.from('journey_images').getPublicUrl(filePath);
          logger.d('Image uploaded to: $imageUrl');

          logger.d('Adding initial DB reference for ID: $imageRecordId');
          // Use journeyRepository obtained from ref
          await journeyRepository.addImageReference(
            journey.id,
            imageUrl,
            id: imageRecordId,
          );
          logger.d('Initial image reference added to DB with ID: $imageRecordId');

          // --- Scan trigger REMOVED --- 

          successCount++;
        } catch (e) { 
          logger.e('Error processing file ${pickedFile.name}', error: e);
          errorMessages.add('Failed to process ${pickedFile.name}.'); 
        }
      } // End for loop

      // --- Refresh handled by StreamProvider, remove manual _loadImages call ---
      // if (successCount > 0 || errorMessages.isNotEmpty) { 
      //   logger.d('Upload loop finished, calling _loadImages...');
      //   await _loadImages(); 
      // } else {
      //   logger.d('Upload loop finished, nothing processed, skipping _loadImages.');
      // }

      // Show snackbar after loop completes
      // Check context validity before showing snackbar
      if (context.mounted && (successCount > 0 || errorMessages.isNotEmpty)) {
          String message = '$successCount image(s) uploaded.'; // TODO: Localize
          if (errorMessages.isNotEmpty) {
            message += '\nErrors:\n${errorMessages.join("\n")}'; // TODO: Localize
          }
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message), duration: Duration(seconds: errorMessages.isEmpty ? 2 : 5))
          );
      }
    } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error processing images: $e')) // TODO: Localize
          );
        }
    } finally {
       // if (mounted) setState(() { _isUploading = false; }); // Requires State
    }
  }

  // Keep _deleteImage (needs ref for repository and logger)
  Future<void> _deleteImage(BuildContext context, WidgetRef ref, String imageUrl) async {
    final logger = ref.read(loggerProvider);
    final journeyRepository = ref.read(journeyRepositoryProvider);
    // final scaffoldMessenger = ScaffoldMessenger.of(context); // Get ScaffoldMessenger

    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => FullScreenConfirmDialog(
        title: 'Delete Image?', // TODO: Localize
        content: 'Are you sure you want to permanently delete this image?', // TODO: Localize
      ),
    ) ?? false;

    if (!confirm || !context.mounted) return; // Added context mounted check

    try {
      await journeyRepository.deleteImage(journey.id, imageUrl);
      // Check context validity before showing snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image deleted.')) // TODO: Localize
        );
        // Refresh handled by StreamProvider
      }
    } catch (e) {
      // Check context validity before showing snackbar
      if (context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error deleting image: $e')) // TODO: Localize
          );
      }
    }
  }

  @override
  // Add WidgetRef ref
  Widget build(BuildContext context, WidgetRef ref) {
    final logger = ref.read(loggerProvider); // Get logger
    final theme = Theme.of(context);
    // Watch the stream provider
    final asyncJourneyImages = ref.watch(journeyImagesStreamProvider(journey.id));

    // TODO: Still need to handle _isUploading state, maybe via a local StateProvider?
    // final isUploading = ref.watch(uploadingStateProvider); 

    return Scaffold(
      appBar: AppBar(
        title: Text('${journey.title} - Gallery'),
        centerTitle: true,
        actions: [
          // Refresh handled by StreamProvider, button less critical but can force provider refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(journeyImagesStreamProvider(journey.id)),
            tooltip: 'Refresh', // TODO: Localize
          ),
        ],
      ),
      // Use AsyncValue.when to handle stream states
      body: SafeArea(
        child: asyncJourneyImages.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
             logger.e('Error loading journey images stream', error: error, stackTrace: stack);
             return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error loading images: $error', style: TextStyle(color: theme.colorScheme.error)), // TODO: Localize
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.refresh(journeyImagesStreamProvider(journey.id)),
                        child: const Text('Retry'), // TODO: Localize
                      )
                    ]
                  ),
                )
             );
          },
          data: (journeyImages) => _buildGalleryContent(context, ref, theme, journeyImages), // Pass ref down if needed
        )
      ),
      floatingActionButton: FloatingActionButton(
        // Need to handle disabling based on upload state
        onPressed: () => _addImage(context, ref),
        tooltip: 'Add Image', // TODO: Localize
        // Need to handle showing indicator based on upload state
        child: const Icon(Icons.add_photo_alternate_outlined),
      ),
    );
  }

  // Update to accept journeyImages list and ref
  Widget _buildGalleryContent(BuildContext context, WidgetRef ref, ThemeData theme, List<JourneyImageInfo> journeyImages) {
    final logger = ref.read(loggerProvider);

    if (journeyImages.isEmpty) {
      return const Center(child: Text('No images added yet.')); // TODO: Localize
    }

    // Remove RefreshIndicator, handled by provider refresh
    return GridView.builder(
        padding: const EdgeInsets.all(1.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 1.0,
          mainAxisSpacing: 1.0,
        ),
        itemCount: journeyImages.length,
        itemBuilder: (context, index) {
          final imageInfo = journeyImages[index];
          final imageUrl = imageInfo.url;
          String? extractPath(String url) {
            try {
              final uri = Uri.parse(url);
              final bucketName = 'journey_images';
              final pathStartIndex = uri.path.indexOf(bucketName) + bucketName.length + 1;
              if (pathStartIndex <= bucketName.length) return null;
              return uri.path.substring(pathStartIndex);
            } catch (e) {
              logger.e('Failed to parse path from URL: $url', error: e);
              return null;
            }
          }
          final imagePath = extractPath(imageUrl);

          return GestureDetector(
            onTap: () async {
              // Navigate to detail view
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GalleryDetailView(
                    // Pass the LIVE list from the provider state
                    // Need to access it here or pass it down carefully
                    // Simplest might be to pass the full list again
                    images: journeyImages, // Pass current list
                    initialIndex: index,
                    logger: logger,
                    // Pass the modified _deleteImage method
                    onDeleteImage: (imgUrl) => _deleteImage(context, ref, imgUrl),
                    onImageDeletedSuccessfully: (deletedUrl) {
                       logger.d('GalleryDetailView reported successful deletion for: $deletedUrl');
                       // No manual refresh needed here, stream handles it
                    },
                  ),
                ),
              );
            },
            child: Hero(
              tag: imageUrl,
              child: Stack( 
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    child: imagePath == null
                      ? Container( 
                          color: theme.colorScheme.errorContainer,
                          child: Icon(Icons.broken_image, color: theme.colorScheme.onErrorContainer),
                        )
                      : FutureBuilder<String>(
                          // Future should ideally be cached or managed by another provider
                          // to avoid refetching on every build
                          // TODO: Optimize signed URL generation/caching for grid view
                          future: Supabase.instance.client.storage
                              .from('journey_images')
                              .createSignedUrl(imagePath, 600), // Shorter expiry for grid?
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                               logger.e('Error creating signed URL for $imagePath', error: snapshot.error);
                               return Container(
                                  color: theme.colorScheme.errorContainer, 
                                  child: Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer), 
                               );
                            }
                            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                               final signedUrl = snapshot.data!;
                               if (signedUrl.isEmpty) {
                                   logger.w('createSignedUrl returned empty string for $imagePath');
                                    return Container(
                                      color: theme.colorScheme.errorContainer, 
                                      child: Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer), 
                                    );
                               }
                               return CachedNetworkImage(
                                 imageUrl: signedUrl,
                                 fit: BoxFit.cover,
                                 placeholder: (context, url) => Container(
                                     color: theme.colorScheme.surfaceContainerHighest,
                                 ),
                                 errorWidget: (context, url, error) {
                                    logger.w('Failed to load image via signed URL for path: $imagePath', error: error);
                                    return Container(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      child: Icon(Icons.error_outline, color: theme.colorScheme.onSurfaceVariant),
                                    );
                                 },
                               );
                            }
                            return Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                            );
                          },
                        ),
                  ),
                  Positioned(
                    top: 16.0,
                    left: 16.0,
                    child: ImageStatusChip(imageInfo: imageInfo),
                  ),
                ],
              ),
            ),
          );
        },
      );
  }
} 