import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/providers/service_providers.dart' as service_providers;
import 'package:travel/models/project.dart';
import '../../models/invoice_image_process.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:travel/widgets/invoice_capture_detail_view.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:travel/repositories/repository_exceptions.dart';

class InvoiceCaptureOverviewScreen extends ConsumerStatefulWidget {
  final Project project;
  const InvoiceCaptureOverviewScreen({super.key, required this.project});

  @override
  ConsumerState<InvoiceCaptureOverviewScreen> createState() =>
      _InvoiceCaptureOverviewScreenState();
}

class _InvoiceCaptureOverviewScreenState
    extends ConsumerState<InvoiceCaptureOverviewScreen> {
  final Logger _logger = Logger();
  int _reloadKey = 0;
  XFile? _imageFile; // Store the picked image file
  bool _isUploading = false;
  final bool _isProcessing = false; // For OCR/Analysis
  String? _uploadError;
  InvoiceImageProcess? _uploadedImageInfo; // Store info of last uploaded image

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _logger.d('🔥 InvoiceCaptureOverviewScreen build called');

    final projectImagesAsyncValue = ref
        .watch(projectImagesStreamProvider('${widget.project.id}|$_reloadKey'));

    return Scaffold(
      appBar: AppBar(
        title: Text('Invoices: ${widget.project.title}'),
      ),
      body: _buildBody(context, projectImagesAsyncValue),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _pickAndUploadImage(ImageSource.gallery),
        heroTag: 'upload',
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }

  Widget _buildImageTile(BuildContext context, InvoiceImageProcess imageInfo) {
    _logger.d(
        "🖼️ [_buildImageTile] CALLED for image ID: ${imageInfo.id}, path: '${imageInfo.imagePath}'");

    if (imageInfo.imagePath.isEmpty) {
      _logger.w(
          "🖼️ [_buildImageTile] imagePath is EMPTY for image ID: ${imageInfo.id}");
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, color: Colors.grey),
            SizedBox(height: 4),
            Text(
              'No image',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Watch the new signedUrlProvider
    final asyncSignedUrl =
        ref.watch(service_providers.signedUrlProvider(imageInfo.imagePath));

    return asyncSignedUrl.when(
      data: (signedUrl) {
        _logger.d(
            "🖼️ [_buildImageTile] Successfully got signed URL for '${imageInfo.imagePath}': '$signedUrl'");
        if (signedUrl.isEmpty) {
          _logger.w(
              '[INVOICE_CAPTURE] Received empty URL for image: ${imageInfo.id}, path: ${imageInfo.imagePath}');
          // Error widget for empty URL
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.image_not_supported, color: Colors.orange),
                const SizedBox(height: 4),
                Text(
                  'Image URL invalid',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                ElevatedButton(
                  onPressed: () => _deleteImage(context, imageInfo),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(10, 24),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Remove', style: TextStyle(fontSize: 9)),
                ),
              ],
            ),
          );
        }

        _logger.d(
            "🖼️ [_buildImageTile] Attempting to load CachedNetworkImage with URL: '$signedUrl'");
        return CachedNetworkImage(
          imageUrl: signedUrl,
          fit: BoxFit.cover,
          // Consider adding memCacheHeight/memCacheWidth for thumbnails
          // memCacheHeight: 150, // Example: Adjust based on your tile size
          // memCacheWidth: 150,  // Example: Adjust based on your tile size
          httpHeaders: const {
            'Accept': 'image/*',
            // 'Cache-Control': 'no-cache', // You might not need this if GCS URLs are unique enough or short-lived
          },
          errorWidget: (context, url, error) {
            _logger.e(
                "🖼️ [_buildImageTile] CachedNetworkImage FAILED for URL '$url':",
                error: error);
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent),
                  const SizedBox(height: 4),
                  ElevatedButton(
                    onPressed: () {
                      // Invalidate the provider for this specific path to force a retry
                      ref.invalidate(service_providers
                          .signedUrlProvider(imageInfo.imagePath));
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(10, 24),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Retry', style: TextStyle(fontSize: 9)),
                  ),
                ],
              ),
            );
          },
          progressIndicatorBuilder: (context, url, progress) {
            return Center(
              child: CircularProgressIndicator(
                value: progress.progress,
              ),
            );
          },
        );
      },
      loading: () {
        _logger.d(
            "🖼️ [_buildImageTile] Loading signed URL for '${imageInfo.imagePath}'...");
        return const Center(child: CircularProgressIndicator());
      },
      error: (err, stack) {
        _logger.e(
            "🖼️ [_buildImageTile] Error getting signed URL for '${imageInfo.imagePath}':",
            error: err,
            stackTrace: stack);
        // Error widget for FutureProvider error
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image_outlined, color: Colors.red),
              const SizedBox(height: 4),
              Text(
                'URL Error',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context,
      AsyncValue<List<InvoiceImageProcess>> projectImagesAsyncValue) {
    return projectImagesAsyncValue.when(
      data: (images) {
        _logger.d(
            '[INVOICE_CAPTURE] Received \\${images.length} images from stream');
        _logger.d('[UI] Images received: \\${images.length}');

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
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () => _deleteImage(context, imageInfo),
                  tooltip: 'Delete Invoice',
                  iconSize: 20,
                ),
              ),
              child: GestureDetector(
                onTap: () {
                  _logger.d(
                      'Navigating to InvoiceCaptureDetailView for project: \\${widget.project.id}');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InvoiceCaptureDetailView(
                        projectId: widget.project.id,
                        invoiceId: imageInfo.invoiceId,
                        initialIndex: index,
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
        _logger.d('[INVOICE_CAPTURE] Loading images...');
        return const Center(child: CircularProgressIndicator());
      },
      error: (error, stack) {
        _logger.e('[INVOICE_CAPTURE] Error loading images',
            error: error, stackTrace: stack);
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Error:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(error.toString(), style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              const Text('Stack trace:'),
              SizedBox(
                height: 100,
                child: SingleChildScrollView(
                  child: Text(stack.toString()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteImage(
      BuildContext context, InvoiceImageProcess imageInfo) async {
    final repo = ref.read(invoiceRepositoryProvider);

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
      _logger.d("🗑️ Starting invoice deletion...");
      await repo.deleteInvoiceImage(
        widget.project.id,
        imageInfo.id,
      );
      _logger.i("🗑️ Invoice deleted successfully");

      if (context.mounted) {
        ref.invalidate(
            projectImagesStreamProvider('${widget.project.id}|$_reloadKey'));
        setState(() {
          _reloadKey++;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice deleted successfully.')),
        );
      }
    } catch (e) {
      _logger.e("🗑️ Error deleting invoice", error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting invoice: $e')),
        );
      }
    }
  }

  String _getCurrentUserId() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw NotAuthenticatedException('User not authenticated');
    }
    return currentUser.uid;
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
      _uploadError = null;
      _uploadedImageInfo = null;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: source);

      if (pickedFile == null) {
        _logger.i("📸 No image selected.");
        setState(() => _isUploading = false);
        return;
      }

      _imageFile = pickedFile;
      final fileBytes = await pickedFile.readAsBytes();
      final fileName = p.basename(pickedFile.path);

      _logger.d("📸 Image selected: $fileName (${fileBytes.length} bytes)");

      final repo = ref.read(invoiceRepositoryProvider);

      _logger
          .d("📸 Starting repository upload to project: ${widget.project.id}");

      // Call uploadInvoiceImage with projectId, fileBytes, and fileName only
      final uploadResult =
          await repo.uploadInvoiceImage(widget.project.id, fileBytes, fileName);

      _logger.i(
          "📸 Upload successful! Image ID: ${uploadResult.id}, Path: ${uploadResult.imagePath}");
      setState(() {
        _uploadedImageInfo = uploadResult;
        _imageFile = null; // Clear the picked file after successful upload
      });
    } on RepositoryException catch (e, stackTrace) {
      _logger.e("📸 Repository error during upload",
          error: e, stackTrace: stackTrace);
      setState(() {
        _uploadError = e.message;
      });
    } catch (e, stackTrace) {
      _logger.e("📸 General error during upload",
          error: e, stackTrace: stackTrace);
      setState(() {
        _uploadError = "An unexpected error occurred: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<Map<String, String>> getAuthHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _logger.e("User not authenticated to get headers.");
      throw Exception("User not authenticated");
    }
    final idToken = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    };
  }
}
