import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import '../providers/invoice_capture_provider.dart';
import '../providers/repository_providers.dart';
import 'package:path/path.dart' as p;
import 'package:travel/utils/invoice_scan_util.dart';
import '../providers/service_providers.dart' as service_providers;

class InvoiceCaptureController {
  final WidgetRef ref;
  final Logger logger;
  final BuildContext context;
  final String projectId;
  final String invoiceId;
  final void Function(VoidCallback fn) setState;
  final int Function() getCurrentIndex;
  final List<dynamic> Function() getImages;

  InvoiceCaptureController({
    required this.ref,
    required this.logger,
    required this.context,
    required this.projectId,
    required this.invoiceId,
    required this.setState,
    required this.getCurrentIndex,
    required this.getImages,
  });

  Future<void> handleScan() async {
    final images = getImages();
    final currentIndex = getCurrentIndex();
    if (images.isEmpty || currentIndex >= images.length) return;
    final imageId = images[currentIndex].id;
    final imagePath = images[currentIndex].imagePath;
    final gcsFileService = ref.read(service_providers.gcsFileServiceProvider);
    final imageUrl =
        await gcsFileService.getSignedDownloadUrl(fileName: imagePath);
    final provider =
        invoiceCaptureProvider((projectId: projectId, invoiceId: invoiceId));
    logger.i('Initiating scan for image ID: $imageId');
    ref.read(provider.notifier).initiateScan(imageId);
    Timer? timeoutTimer;
    timeoutTimer = Timer(const Duration(seconds: 60), () {
      logger.e('[INVOICE_CAPTURE] OCR timed out after 60 seconds');
      ref.read(provider.notifier).setScanError(imageId, "OCR timed out");
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OCR process timed out')),
      );
      timeoutTimer?.cancel();
    });
    try {
      if (imageUrl.isEmpty) {
        throw Exception('Image URL is empty. Cannot proceed with scan.');
      }
      logger.d("Attempting to download from: $imageUrl");
      final httpResponse = await http.get(Uri.parse(imageUrl));
      logger.d("Image download status: ${httpResponse.statusCode}");
      if (httpResponse.statusCode != 200) {
        throw Exception("Failed to download image: ${httpResponse.statusCode}");
      }
      logger.d("Image downloaded successfully for scan (ID: $imageId)");
      logger.i('Calling Cloud Run OCR for scanning image ID: $imageId');

      // Get the current image object before scan
      final currentImageInfo = images[currentIndex];

      final Map<String, dynamic>? ocrResult = await InvoiceScanUtil.scanImage(
        context,
        ref,
        projectId,
        invoiceId,
        currentImageInfo, // Pass the specific image info
      );
      timeoutTimer
          .cancel(); // Cancel timeout if scanImage completes (success or error)

      if (ocrResult != null) {
        String? extractedTextValue;
        // Prioritize 'ocrText', then 'text', then 'fullText' as potential keys
        if (ocrResult['extractedText'] is String &&
            (ocrResult['extractedText'] as String).isNotEmpty) {
          extractedTextValue = ocrResult['extractedText'] as String;
        } else if (ocrResult['ocrText'] is String &&
            (ocrResult['ocrText'] as String).isNotEmpty) {
          extractedTextValue = ocrResult['ocrText'] as String;
        } else if (ocrResult['text'] is String &&
            (ocrResult['text'] as String).isNotEmpty) {
          extractedTextValue = ocrResult['text'] as String;
        } else if (ocrResult['fullText'] is String &&
            (ocrResult['fullText'] as String).isNotEmpty) {
          extractedTextValue = ocrResult['fullText'] as String;
        }
        // Add other potential keys like 'detectedText' if necessary based on actual OCR service response

        if (extractedTextValue != null) {
          logger.i(
              'OCR scan successful for $imageId. Extracted text. Updating state.');
          final notifier = ref.read(invoiceCaptureProvider(
              (projectId: projectId, invoiceId: invoiceId)).notifier);
          notifier.updateOcrTextForImage(imageId, extractedTextValue);
          // InvoiceScanUtil handles success snackbar
        } else {
          // Text is null or empty, or not found under expected keys.
          String errorMessage = "OCR returned no usable text.";
          if (ocrResult.containsKey('error') && ocrResult['error'] != null) {
            errorMessage = "OCR Error: ${ocrResult['error']}";
            logger.e(
                'OCR service returned an error for $imageId: ${ocrResult['error']}');
          } else {
            logger.w(
                'OCR scan for $imageId did not find text under expected keys or text was empty. Result: $ocrResult');
          }
          ref.read(provider.notifier).setScanError(imageId, errorMessage);
          // InvoiceScanUtil might show a snackbar; if not, or if more specific error needed, consider adding one here or relying on state change.
        }
      } else {
        // ocrResult is null.
        // This typically means InvoiceScanUtil.scanImage returned null, likely due to an exception
        // during its HTTP call or within its own try-catch block.
        // The catch block in this handleScan method or in InvoiceScanUtil should have already logged
        // the error and called setScanError.
        logger.w(
            'OCR scan for $imageId returned null result. Error should have been handled by InvoiceScanUtil or the calling catch block.');
      }
    } catch (e, stackTrace) {
      // Catch errors from scanImage or pre-scan steps
      timeoutTimer?.cancel(); // Ensure timer is cancelled on any error too
      logger.e('[INVOICE_CAPTURE] Error during scan process:',
          error: e, stackTrace: stackTrace);
      ref.read(provider.notifier).setScanError(imageId, e.toString());
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning image: ${e.toString()}')),
      );
    }
  }

  Future<void> handleAnalyze() async {
    final images = getImages();
    final currentIndex = getCurrentIndex();
    if (images.isEmpty || currentIndex >= images.length) return;
    final imageInfo = images[currentIndex];

    logger.d(
        "Full ocrText from imageInfo before sending to analyzeImage: START-----\n${imageInfo.ocrText}\n-----END ocrText. Length: ${imageInfo.ocrText?.length}");

    final analysisService =
        ref.read(service_providers.cloudRunOcrServiceProvider);

    final Map<String, dynamic> analysisResponse =
        await analysisService.analyzeImage(
      imageInfo.ocrText ?? '',
      projectId,
      invoiceId,
      imageInfo.id,
    );

    if (analysisResponse['success'] == true &&
        analysisResponse['data'] != null) {
      final Map<String, dynamic> newInvoiceAnalysisData =
          analysisResponse['data'] as Map<String, dynamic>;

      ref
          .read(invoiceCaptureProvider(
              (projectId: projectId, invoiceId: invoiceId)).notifier)
          .updateImageAnalysisData(imageInfo.id, newInvoiceAnalysisData);

      logger.i(
          "Successfully received and updated LOCAL analysis data for image ${imageInfo.id}: $newInvoiceAnalysisData");

      // Now, persist these results to Firestore
      try {
        final projectRepo = ref.read(invoiceRepositoryProvider);
        final bool isConfirmed =
            newInvoiceAnalysisData['isInvoice'] as bool? ?? false;

        await projectRepo.updateImageWithAnalysisDetails(
            projectId, imageInfo.id,
            analysisData: newInvoiceAnalysisData,
            isInvoiceConfirmed: isConfirmed,
            status: 'analysis_complete');
        logger.i(
            "Successfully PERSISTED analysis data to Firestore for image ${imageInfo.id}");
      } catch (e, s) {
        logger.e(
            "Error persisting analysis data to Firestore for image ${imageInfo.id}: $e",
            error: e,
            stackTrace: s);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Error saving analysis details: ${e.toString()}')),
          );
        }
      }
    } else {
      logger.e(
          "Analysis call was not successful or data was null for image ${imageInfo.id}: $analysisResponse");
      // Optionally, show an error to the user via ScaffoldMessenger or another way
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to get analysis details: ${analysisResponse['message'] ?? 'Unknown error'}')),
        );
      }
    }
    // await Future.delayed(const Duration(seconds: 1)); // This might not be needed anymore
  }

  Future<void> handleDelete() async {
    final images = getImages();
    final currentIndex = getCurrentIndex();
    if (images.isEmpty || currentIndex >= images.length) return;
    final imageToDelete = images[currentIndex];
    final imageIdToDelete = imageToDelete.id;
    final imagePathToDelete = imageToDelete.imagePath;
    final repository = ref.read(invoiceRepositoryProvider);
    final bool? confirmed = await _showDeleteConfirmationDialog();
    if (confirmed != true) {
      logger.d('Deletion cancelled by user.');
      return;
    }
    setState(() {
      // Optionally set a deleting state in the parent
    });
    if (imagePathToDelete.isEmpty) {
      _handleDeleteError('Cannot delete image: imagePath is empty.');
      return;
    }
    final String fileName = p.basename(imagePathToDelete);
    logger.i(
        'Attempting delete via repository for project $projectId, image $imageIdToDelete, filename $fileName');
    try {
      await repository.deleteInvoiceImage(
        projectId,
        imageIdToDelete,
      );
      logger.i(
          'Image $imageIdToDelete deleted successfully locally and from backend');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image deleted successfully')),
      );
      if (!context.mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      _handleDeleteError('Error deleting image: ${e.toString()}');
    } finally {
      setState(() {
        // Optionally unset deleting state
      });
    }
  }

  void _handleDeleteError(String message) {
    logger.e('[INVOICE_CAPTURE] $message', error: message);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    setState(() {
      // Optionally unset deleting state
    });
  }

  Future<bool?> _showDeleteConfirmationDialog() {
    return showDialog<bool>(
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
  }
}
