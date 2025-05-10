import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel/providers/repository_providers.dart';
import '../../models/invoice_image_process.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:travel/widgets/invoice_capture_detail_view.dart';
import 'package:travel/providers/logging_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:travel/utils/invoice_scan_util.dart';
import 'package:travel/widgets/invoice_detail_bottom_bar.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:travel/services/gcs_file_service.dart';

class InvoiceCaptureDetailScreen extends ConsumerWidget {
  final String projectId;
  final String invoiceId;

  const InvoiceCaptureDetailScreen({
    super.key,
    required this.projectId,
    required this.invoiceId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectImagesAsyncValue = ref.watch(invoiceImagesStreamProvider({
      'projectId': projectId,
      'invoiceId': invoiceId,
    }));

    final projectAsyncValue = ref.watch(projectStreamProvider(projectId));

    return Scaffold(
      appBar: AppBar(
        title: projectAsyncValue.when(
          data: (project) =>
              Text('Invoices: ${project?.title ?? "Loading..."}'),
          loading: () => const Text('Invoices: Loading...'),
          error: (_, __) => const Text('Invoices'),
        ),
      ),
      body: _buildBody(context, ref, projectImagesAsyncValue),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _pickAndUploadImage(context, ref),
        heroTag: 'upload',
        child: const Icon(Icons.add_a_photo),
      ),
      bottomNavigationBar: InvoiceDetailBottomBar(
        onUpload: () => _pickAndUploadImage(context, ref),
        onScan: null, // TODO: connect scan logic
        onInfo: null, // TODO: connect info logic
        onFavorite: null, // TODO: connect favorite logic
        onSettings: null, // TODO: connect settings logic
        onDelete: null, // TODO: connect delete logic
      ),
    );
  }

  Widget _buildImageTile(
      BuildContext context, WidgetRef ref, InvoiceImageProcess imageInfo) {
    if (imageInfo.imagePath.isEmpty) {
      return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
    }

    return FutureBuilder<String>(
      future: ref
          .read(gcsFileServiceProvider)
          .getSignedDownloadUrl(fileName: imageInfo.imagePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Icon(Icons.error, color: Colors.red));
        }
        final signedUrl = snapshot.data!;
        return CachedNetworkImage(
          imageUrl: signedUrl,
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
                        ref.invalidate(invoiceImagesStreamProvider({
                      'projectId': projectId,
                      'invoiceId': invoiceId,
                    })),
                    child: const Text('Retry', style: TextStyle(fontSize: 10)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref,
      AsyncValue<List<InvoiceImageProcess>> projectImagesAsyncValue) {
    return projectImagesAsyncValue.when(
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
                title: Container(),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white),
                      onPressed: () => _deleteImage(context, ref, imageInfo),
                      tooltip: 'Delete Invoice',
                      iconSize: 20,
                    ),
                  ],
                ),
              ),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InvoiceCaptureDetailView(
                        projectId: projectId,
                        invoiceId: invoiceId,
                        initialIndex: index,
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
      InvoiceImageProcess imageInfo) async {
    final repo = ref.read(projectRepositoryProvider);

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
        projectId,
        invoiceId,
        imageInfo.id,
      );
      ref.read(loggerProvider).i("🗑️ Invoice deleted successfully");
    } catch (e) {
      ref.read(loggerProvider).e("🗑️ Error deleting invoice", error: e);
    }
  }

  Future<void> _pickAndUploadImage(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(projectRepositoryProvider);
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
      final uploadResult = await repo.uploadInvoiceImage(
          projectId, invoiceId, fileBytes, fileName);

      ref.read(loggerProvider).i("📸 Repository upload completed successfully");
      ref
          .read(loggerProvider)
          .d("📸 Upload result: ${uploadResult.id} - ${uploadResult.url}");
    } catch (e) {
      ref.read(loggerProvider).e("📸 ERROR DURING UPLOAD: $e", error: e);
    }
  }

  Future<void> _scanImage(BuildContext context, WidgetRef ref,
      InvoiceImageProcess imageInfo) async {
    await InvoiceScanUtil.scanImage(
        context, ref, projectId, invoiceId, imageInfo);
  }
}
