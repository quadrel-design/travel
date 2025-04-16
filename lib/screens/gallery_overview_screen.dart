import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/models/journey.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:travel/providers/logging_provider.dart';
import '../models/journey_image_info.dart';
// Keep for GalleryDetailView dependency if needed elsewhere
import '../widgets/gallery_detail_view.dart';
import '../widgets/image_status_chip.dart';
// Import AppLocalizations
import '../models/image_status.dart'; // Make sure this is imported
import 'package:travel/constants/layout_constants.dart'; // Import layout constants

// Function to determine status (can be moved to a helper file)
ImageStatus determineImageStatus(JourneyImageInfo imageInfo) {
  if (imageInfo.lastProcessedAt != null) {
    if (imageInfo.hasPotentialText == true) {
      return ImageStatus.scanComplete;
    } else {
      return ImageStatus.noTextFound;
    }
  } else {
    // If not processed, assume ready or pending (could add more states)
    // We don't have 'scanInitiated' anymore, so maybe rely on upload time?
    // For now, default to ready.
    return ImageStatus.ready;
  }
}

class GalleryOverviewScreen extends ConsumerWidget {
  final Journey journey;
  const GalleryOverviewScreen({super.key, required this.journey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journeyImagesAsyncValue = ref.watch(journeyImagesStreamProvider(journey.id));
    final uploadState = ref.watch(galleryUploadStateProvider);
    // final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        // title: Text(l10n.galleryOverviewTitle),
        title: const Text('Gallery'), // Placeholder
      ),
      // Pass context instead of l10n for now
      body: _buildBody(context, ref, /*l10n,*/ journeyImagesAsyncValue),
      // Pass context instead of l10n for now
      floatingActionButton: _buildFloatingActionButton(context, ref, /*l10n,*/ uploadState),
    );
  }

  // Remove l10n parameter for now
  Widget _buildBody(BuildContext context, WidgetRef ref, /*AppLocalizations l10n,*/ AsyncValue<List<JourneyImageInfo>> journeyImagesAsyncValue) {
    final logger = ref.watch(loggerProvider);
    final repo = ref.watch(journeyRepositoryProvider);

    // Remove l10n usage inside helper
    Future<bool> _showDeleteConfirmationDialog(BuildContext context) async {
      return await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                // title: Text(l10n.deleteImageConfirmationTitle),
                title: const Text('Delete Image?'), // Placeholder
                // content: Text(l10n.deleteImageConfirmationContent),
                content: const Text('Are you sure?'), // Placeholder
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
          ) ?? false;
    }

    Future<void> _deleteImage(String imageUrl, String imageId) async {
      logger.d('Attempting to delete image: $imageUrl (ID: $imageId)');
      final confirmed = await _showDeleteConfirmationDialog(context);
      if (!confirmed) {
        logger.d('Deletion cancelled by user.');
        return;
      }

      try {
        // Pass both imageUrl and imageId to the repository method
        await repo.deleteJourneyImage(imageUrl, imageId);
        logger.i('Successfully deleted image: $imageUrl (ID: $imageId)');
        // Note: Realtime update should remove the image from the list via the stream provider
      } catch (e, stackTrace) {
        logger.e('Failed to delete image: $imageUrl', error: e, stackTrace: stackTrace);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            // SnackBar(content: Text(l10n.deleteImageErrorSnackbar(e.toString()))),
             SnackBar(content: Text('Error deleting image: ${e.toString()}')), // Placeholder
          );
        }
      }
    }

    return journeyImagesAsyncValue.when(
      data: (images) {
        if (images.isEmpty) {
          return const Center(child: Text('No images yet. Tap + to add.'));
        }
        return GridView.builder(
          // Use layout constants
          padding: kGridPadding,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: kGridCrossAxisCount,
            crossAxisSpacing: kGridCrossAxisSpacing,
            mainAxisSpacing: kGridMainAxisSpacing,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            final imageInfo = images[index];
            final status = determineImageStatus(imageInfo);

            return GestureDetector(
              onTap: () {
                logger.d('Tapped on image index $index, navigating to detail.');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GalleryDetailView(
                      images: images, // Pass the full list
                      initialIndex: index,
                      logger: logger,
                      // Update onDeleteImage callback to accept and pass imageId
                      // We get the imageId from imageInfo corresponding to the url/index
                      onDeleteImage: (url, id) => repo.deleteJourneyImage(url, id),
                      onImageDeletedSuccessfully: (deletedUrl) {
                         logger.i('Detail view reported successful deletion for $deletedUrl, list should update via stream.');
                         // No manual list update needed here due to stream
                      },
                    ),
                  ),
                );
              },
              child: GridTile(
                footer: Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: ImageStatusChip(imageInfo: imageInfo),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageInfo.url,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
         logger.e('Error loading journey images', error: error, stackTrace: stack);
         return Center(child: Text('Error loading images: $error'));
      },
    );
  }

  // Remove l10n parameter for now
  Widget _buildFloatingActionButton(BuildContext context, WidgetRef ref, /*AppLocalizations l10n,*/ bool isUploading) {
      final logger = ref.watch(loggerProvider);
      final repo = ref.watch(journeyRepositoryProvider);

      Future<void> addImage() async {
        if (ref.read(galleryUploadStateProvider)) {
          logger.w('Upload already in progress, ignoring FAB tap.');
          return;
        }

        logger.d('Add image FAB tapped');
        final picker = ImagePicker();
        final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

        if (pickedFile != null) {
          logger.i('Image picked: ${pickedFile.path}');
          ref.read(galleryUploadStateProvider.notifier).state = true;
          try {
            final fileBytes = await pickedFile.readAsBytes();
            final fileName = pickedFile.name;
            logger.d('Uploading image: $fileName');
            await repo.uploadJourneyImage(fileBytes, fileName, journey.id);
            logger.i('Successfully uploaded image: $fileName for Journey ${journey.id}');
          } catch (e, stackTrace) {
            logger.e('Failed to upload image', error: e, stackTrace: stackTrace);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                 // SnackBar(content: Text(l10n.imageUploadErrorSnackbar(e.toString()))),
                 SnackBar(content: Text('Error uploading image: ${e.toString()}')), // Placeholder
              );
            }
          } finally {
             if (context.mounted) { // Check mounted again just in case
               ref.read(galleryUploadStateProvider.notifier).state = false;
             }
          }
        } else {
          logger.d('Image picking cancelled by user.');
        }
      }

      return FloatingActionButton(
        // tooltip: isUploading ? l10n.uploadingStatus : l10n.addPhotoTooltip,
        tooltip: isUploading ? 'Uploading...' : 'Add Photo', // Placeholder
        onPressed: isUploading ? null : addImage,
        child: isUploading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.add_a_photo),
      );
  }

}