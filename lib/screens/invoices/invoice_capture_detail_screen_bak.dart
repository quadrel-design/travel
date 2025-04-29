import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel/providers/repository_providers.dart';
import '../models/invoice_capture_process.dart';
import '../models/invoice_capture_status.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:travel/widgets/image_status_chip.dart';
import 'package:travel/widgets/invoice/invoice_capture_detail_view.dart';
import 'package:travel/providers/logging_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:travel/utils/invoice_scan_util.dart';
import 'package:travel/providers/firebase_functions_provider.dart';

/// Utility function to determine the display status from the image model.
/// TODO: Consider moving this into the model or a dedicated status utility file.
InvoiceCaptureStatus determineImageStatus(InvoiceCaptureProcess imageInfo) {
  if (imageInfo.status != null) {
    return InvoiceCaptureStatus.fromFirebaseStatus(imageInfo.status);
  }
  return InvoiceCaptureStatus.ready;
}

/// (Legacy name: InvoiceCaptureScreen)
/// Displays a grid overview of captured invoice images for a given journey.
///
/// This screen fetches and displays invoice images associated with the [journeyId].
/// It provides functionality to upload new images, tap on thumbnails to navigate
/// to the detail view, trigger OCR scans, and delete images directly from the grid.
///
/// TODO: Rename class to match filename (`InvoiceCaptureDetailScreen`) if appropriate,
/// or rename file back if this is actually the intended overview screen.
class InvoiceCaptureScreen extends ConsumerWidget {
  /// The ID of the journey whose invoice images are to be displayed.
  final String journeyId;

  /// Creates an [InvoiceCaptureScreen] (likely intended as an overview screen).
  const InvoiceCaptureScreen({super.key, required this.journeyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the stream of invoice images for the journey.
    final journeyImagesAsyncValue =
        ref.watch(invoiceImagesStreamProvider(journeyId));

    // Watch the journey details (likely for the title).
    final journeyAsyncValue = ref.watch(journeyStreamProvider(journeyId));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3), // Set background color
      appBar: AppBar(
        // Display journey title or loading/error state.
        title: journeyAsyncValue.when(
          data: (journey) =>
              Text('Invoices: ${journey?.title ?? "Loading..."}'),
          loading: () => const Text('Invoices: Loading...'),
          error: (_, __) => const Text('Invoices'),
        ),
      ),
      // Build the main body using the image stream data.
      body: _buildBody(context, ref, journeyImagesAsyncValue),
      // FAB for picking and uploading new images.
      floatingActionButton: FloatingActionButton(
        onPressed: () => _pickAndUploadImage(context, ref),
        heroTag: 'upload',
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }

  /// Builds the thumbnail image widget for a single grid tile.
  ///
  /// Uses [CachedNetworkImage] to display the image from its URL.
  /// Shows loading and error states.
  Widget _buildImageTile(
      BuildContext context, WidgetRef ref, InvoiceCaptureProcess imageInfo) {
    if (imageInfo.url.isEmpty) {
      return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
    }

    return CachedNetworkImage(
      imageUrl: imageInfo.url,
      fit: BoxFit.cover,
      httpHeaders: const {
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
        ref
            .read(loggerProvider)
            .e('[INVOICE_CAPTURE] Error loading image:', error: error);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent),
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(invoiceImagesStreamProvider(journeyId)),
                child: const Text('Retry', style: TextStyle(fontSize: 10)),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds the main content area of the screen.
  ///
  /// Displays a [GridView] of invoice images, or relevant loading/error/empty states.
  Widget _buildBody(BuildContext context, WidgetRef ref,
      AsyncValue<List<InvoiceCaptureProcess>> journeyImagesAsyncValue) {
    return journeyImagesAsyncValue.when(
      // Display the grid when image data is available.
      data: (images) {
        ref.read(loggerProvider).d(
            '[INVOICE_CAPTURE] Received ${images.length} images from stream');

        if (images.isEmpty) {
          // Show empty state message.
          return const Center(child: Text("No invoices captured yet."));
        }

        // Build the grid view.
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
            // Build each grid item.
            return GridTile(
              // Footer bar showing status and actions.
              footer: GridTileBar(
                backgroundColor: Colors.black45,
                title: ImageStatusChip(
                    imageInfo: imageInfo), // Display status chip.
                // Trailing icons for actions based on status.
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Show scan button if image is ready.
                    if (imageInfo.status == 'ready' ||
                        imageInfo.status == 'uploading')
                      IconButton(
                        icon: const Icon(Icons.document_scanner,
                            color: Colors.white),
                        onPressed: () => _scanImage(context, ref, imageInfo),
                        tooltip: 'Scan Invoice',
                        iconSize: 20,
                      ),
                    // Always show delete button.
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white),
                      onPressed: () => _deleteImage(context, ref, imageInfo),
                      tooltip: 'Delete Invoice',
                      iconSize: 20,
                    ),
                    // DEPRECATED: Analyze button (functionality likely moved to detail view).
                    IconButton(
                      icon: const Icon(Icons.bar_chart, color: Colors.white),
                      onPressed: () async {
                        print(
                            '[GridTile - DEPRECATED?] Analyze button pressed for image: \\${imageInfo.id}');
                        if (imageInfo.extractedText == null ||
                            imageInfo.extractedText!.isEmpty) {
                          print(
                              '[GridTile - DEPRECATED?] No OCR text to analyze.');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('No OCR text to analyze.')),
                          );
                          return;
                        }
                        try {
                          final functionsService =
                              ref.read(firebaseFunctionsProvider);
                          print(
                              '[GridTile - DEPRECATED?] Calling analyzeImage Cloud Function...');
                          final result = await functionsService.analyzeImage(
                            imageInfo.extractedText!,
                            journeyId,
                            imageInfo.id,
                          );
                          print(
                              '[GridTile - DEPRECATED?] analyzeImage result: \\${result.toString()}');
                          ref.invalidate(
                              invoiceImagesStreamProvider(journeyId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Analysis complete: \\${result['status'] ?? 'unknown'}')),
                          );
                        } catch (e, s) {
                          print('[GridTile - DEPRECATED?] Analysis failed: $e');
                          print('[GridTile - DEPRECATED?] Stack trace: $s');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Analysis failed: Check logs for details.')),
                          );
                        }
                      },
                      tooltip: 'Analyze Text',
                      iconSize: 20,
                    ),
                  ],
                ),
              ),
              // Main content of the tile (the image).
              child: GestureDetector(
                // Navigate to detail view on tap.
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InvoiceCaptureDetailView(
                        journeyId: journeyId,
                        initialIndex: index,
                        images: images,
                      ),
                    ),
                  );
                },
                // Build the image thumbnail.
                child: _buildImageTile(context, ref, imageInfo),
              ),
            );
          },
        );
      },
      // Show loading indicator.
      loading: () {
        ref.read(loggerProvider).d('[INVOICE_CAPTURE] Loading images...');
        return const Center(child: CircularProgressIndicator());
      },
      // Show error message.
      error: (error, stack) {
        ref.read(loggerProvider).e('[INVOICE_CAPTURE] Error loading images',
            error: error, stackTrace: stack);
        return Center(
          child: Text('Error: $error'),
        );
      },
    );
  }

  /// Shows a confirmation dialog and handles the deletion of an invoice image.
  Future<void> _deleteImage(BuildContext context, WidgetRef ref,
      InvoiceCaptureProcess imageInfo) async {
    final repo = ref.read(journeyRepositoryProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text("Delete Invoice?"),
          content: const Text("Are you sure you want to delete this invoice?"),
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
      ref.read(loggerProvider).d("🗑️ Starting invoice deletion...");
      await repo.deleteInvoiceImage(
        journeyId,
        imageInfo.id,
      );
      ref.read(loggerProvider).i("🗑️ Invoice deleted successfully");

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice deleted successfully.')),
        );
      }
    } catch (e) {
      ref.read(loggerProvider).e("🗑️ Error deleting invoice", error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting invoice: $e')),
        );
      }
    }
  }

  /// Handles picking an image from the gallery and uploading it via the repository.
  Future<void> _pickAndUploadImage(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(journeyRepositoryProvider);
    final picker = ImagePicker();

    try {
      ref.read(loggerProvider).d("📸 Starting image picker...");
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) {
        ref.read(loggerProvider).d("📸 User canceled picking image");
        return;
      }

      ref.read(loggerProvider).d("📸 Reading file bytes");
      final fileBytes = await pickedFile.readAsBytes();
      final fileName = p.basename(pickedFile.path);
      ref
          .read(loggerProvider)
          .d("📸 File: $fileName, size: ${fileBytes.length} bytes");

      ref.read(loggerProvider).d("📸 Starting repository upload...");
      final uploadResult =
          await repo.uploadInvoiceImage(journeyId, fileBytes, fileName);

      ref.read(loggerProvider).i("📸 Repository upload completed successfully");
      ref
          .read(loggerProvider)
          .d("📸 Upload result: ${uploadResult.id} - ${uploadResult.url}");

      if (context.mounted) {
        ref.read(loggerProvider).d("📸 Showing success message");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Invoice uploaded! Click Scan to process.')),
        );
      }
    } catch (e) {
      ref.read(loggerProvider).e("📸 ERROR DURING UPLOAD: $e", error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading invoice: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Initiates the OCR scan process for a specific image using [InvoiceScanUtil].
  Future<void> _scanImage(BuildContext context, WidgetRef ref,
      InvoiceCaptureProcess imageInfo) async {
    await InvoiceScanUtil.scanImage(context, ref, journeyId, imageInfo);
  }
}
