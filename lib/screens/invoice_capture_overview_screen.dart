import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/models/project.dart';
import '../models/invoice_capture_process.dart';
import '../models/invoice_capture_status.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:travel/widgets/invoice_capture_detail_view.dart';
import 'package:logger/logger.dart';
import 'package:travel/providers/logging_provider.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:travel/utils/invoice_scan_util.dart';

InvoiceCaptureStatus determineImageStatus(InvoiceCaptureProcess imageInfo) {
  if (imageInfo.status != null) {
    return InvoiceCaptureStatus.fromFirebaseStatus(imageInfo.status);
  }
  return InvoiceCaptureStatus.ready;
}

class InvoiceCaptureOverviewScreen extends ConsumerStatefulWidget {
  final Project project;
  const InvoiceCaptureOverviewScreen({super.key, required this.project});

  @override
  ConsumerState<InvoiceCaptureOverviewScreen> createState() =>
      _InvoiceCaptureOverviewScreenState();
}

class _InvoiceCaptureOverviewScreenState
    extends ConsumerState<InvoiceCaptureOverviewScreen> {
  late final Logger _logger;
  late final Map<String, String> _invoiceImagesProviderParams;

  @override
  void initState() {
    super.initState();
    _logger = ref.read(loggerProvider);
    _invoiceImagesProviderParams = {
      'projectId': widget.project.id,
      'invoiceId': 'main',
    };
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

    final projectImagesAsyncValue =
        ref.watch(invoiceImagesStreamProvider(_invoiceImagesProviderParams));

    return Scaffold(
      appBar: AppBar(
        title: Text('Invoices: ${widget.project.title}'),
      ),
      body: _buildBody(context, projectImagesAsyncValue),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _pickAndUploadImage(context),
        heroTag: 'upload',
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }

  Widget _buildImageTile(
      BuildContext context, InvoiceCaptureProcess imageInfo) {
    if (imageInfo.url.isEmpty) {
      return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
    }

    return FutureBuilder<Uint8List?>(
      future: FirebaseStorage.instance.refFromURL(imageInfo.url).getData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          _logger.e('[INVOICE_CAPTURE] Error loading image via getData:',
              error: snapshot.error);
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.redAccent),
                SizedBox(height: 4),
                Text('Error', style: TextStyle(fontSize: 10)),
              ],
            ),
          );
        }

        return Image.memory(
          snapshot.data!,
          fit: BoxFit.cover,
        );
      },
    );
  }

  Widget _buildBody(BuildContext context,
      AsyncValue<List<InvoiceCaptureProcess>> projectImagesAsyncValue) {
    return projectImagesAsyncValue.when(
      data: (images) {
        _logger.d(
            '[INVOICE_CAPTURE] Received \\${images.length} images from stream');
        print('[UI] Images received: \\${images.length}');
        for (final img in images) {
          print(
              '[UI] Image: id=\\${img.id}, url=\\${img.url}, status=\\${img.status}');
        }

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

            Widget trailingWidget;
            switch (imageInfo.status) {
              case 'invoice':
              case 'no invoice':
              case 'analysis_complete':
              case 'analysis_failed':
                trailingWidget = IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () => _deleteImage(context, imageInfo),
                  tooltip: 'Delete Invoice',
                  iconSize: 20,
                );
                break;
              case 'ocr_running':
              case 'analysis_running':
                trailingWidget = const Padding(
                  padding: EdgeInsets.all(10.0),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.0, color: Colors.white),
                  ),
                );
                break;
              case 'ready':
              case 'uploading':
                trailingWidget = IconButton(
                  icon: const Icon(Icons.document_scanner, color: Colors.white),
                  onPressed: () => _scanImage(context, ref, imageInfo),
                  tooltip: 'Scan Invoice',
                  iconSize: 20,
                );
                break;
              default:
                trailingWidget = IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () => _deleteImage(context, imageInfo),
                  tooltip: 'Delete Invoice',
                  iconSize: 20,
                );
                break;
            }

            return GridTile(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InvoiceCaptureDetailView(
                        projectId: widget.project.id,
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
                  child: Text(stack.toString() ?? 'No stack trace'),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Check Firestore rules and data for this project.'),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteImage(
      BuildContext context, InvoiceCaptureProcess imageInfo) async {
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
      _logger.d("🗑️ Starting invoice deletion...");
      await repo.deleteInvoiceImage(
        widget.project.id,
        imageInfo.id,
      );
      _logger.i("🗑️ Invoice deleted successfully");

      if (context.mounted) {
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

  Future<void> _pickAndUploadImage(BuildContext context) async {
    final repo = ref.read(projectRepositoryProvider);
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
          await repo.uploadInvoiceImage(widget.project.id, fileBytes, fileName);

      _logger.i("📸 Repository upload completed successfully");
      _logger.d("📸 Upload result: ${uploadResult.id} - ${uploadResult.url}");

      // No longer automatically starting OCR
      if (context.mounted) {
        _logger.d("📸 Showing success message");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Invoice uploaded! Click Scan to process.')),
        );
      }
    } catch (e, stack) {
      _logger.e("📸 ERROR DURING UPLOAD: $e", error: e, stackTrace: stack);
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

  // Helper function to call the OCR scan function in invoice_capture_screen.dart
  Future<void> _scanImage(BuildContext context, WidgetRef ref,
      InvoiceCaptureProcess imageInfo) async {
    // Use the utility class to scan the image
    await InvoiceScanUtil.scanImage(context, ref, widget.project.id, imageInfo);
  }
}
