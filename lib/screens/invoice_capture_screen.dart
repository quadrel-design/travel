import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel/providers/repository_providers.dart';
import '../models/invoice_capture_process.dart';
import '../models/invoice_capture_status.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:travel/widgets/image_status_chip.dart';
import 'package:travel/widgets/invoice_capture_detail_view.dart';
import 'package:travel/providers/logging_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

InvoiceCaptureStatus determineImageStatus(InvoiceCaptureProcess imageInfo) {
  if (imageInfo.status != null) {
    return InvoiceCaptureStatus.fromFirebaseStatus(imageInfo.status);
  }
  return InvoiceCaptureStatus.ready;
}

class InvoiceCaptureScreen extends ConsumerWidget {
  final String journeyId;

  const InvoiceCaptureScreen({super.key, required this.journeyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journeyImagesAsyncValue =
        ref.watch(invoiceImagesStreamProvider(journeyId));

    final journeyAsyncValue = ref.watch(journeyStreamProvider(journeyId));

    return Scaffold(
      appBar: AppBar(
        title: journeyAsyncValue.when(
          data: (journey) =>
              Text('Invoices: ${journey?.title ?? "Loading..."}'),
          loading: () => const Text('Invoices: Loading...'),
          error: (_, __) => const Text('Invoices'),
        ),
      ),
      body: _buildBody(context, ref, journeyImagesAsyncValue),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _pickAndUploadImage(context, ref),
        heroTag: 'upload',
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }

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

  Widget _buildBody(BuildContext context, WidgetRef ref,
      AsyncValue<List<InvoiceCaptureProcess>> journeyImagesAsyncValue) {
    return journeyImagesAsyncValue.when(
      data: (images) {
        ref.read(loggerProvider).d(
            '[INVOICE_CAPTURE] Received ${images.length} images from stream');

        if (images.isEmpty) {
          return const Center(child: Text("No invoices captured yet."));
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
                  onPressed: () => _deleteImage(context, ref, imageInfo),
                  tooltip: 'Delete Invoice',
                ),
              ),
              child: GestureDetector(
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
                child: _buildImageTile(context, ref, imageInfo),
              ),
            );
          },
        );
      },
      loading: () {
        ref.read(loggerProvider).d('[INVOICE_CAPTURE] Loading images...');
        return const Center(child: CircularProgressIndicator());
      },
      error: (error, stack) {
        ref.read(loggerProvider).e('[INVOICE_CAPTURE] Error loading images',
            error: error, stackTrace: stack);
        return Center(
          child: Text('Error: $error'),
        );
      },
    );
  }

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
          const SnackBar(content: Text('Invoice uploaded successfully!')),
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
}
