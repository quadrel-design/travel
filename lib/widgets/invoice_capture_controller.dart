import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import '../providers/invoice_capture_provider.dart';
import '../providers/repository_providers.dart';
import '../providers/firebase_functions_provider.dart';
import '../providers/location_service_provider.dart';
import 'package:path/path.dart' as p;

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
    final imageUrl = images[currentIndex].url;
    final provider =
        invoiceCaptureProvider((projectId: projectId, invoiceId: invoiceId));
    logger.i('Initiating scan for image ID: $imageId');
    ref.read(provider.notifier).initiateScan(imageId);
    Timer? timeoutTimer;
    timeoutTimer = Timer(const Duration(seconds: 60), () {
      logger.e('[INVOICE_CAPTURE] OCR timed out after 60 seconds');
      ref.read(provider.notifier).setScanError(imageId, "OCR timed out");
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
      final functionsService = ref.read(firebaseFunctionsProvider);
      logger
          .i('Calling Firebase Cloud Function for scanning image ID: $imageId');
      final result = await functionsService.scanImage(
        imageUrl,
        projectId,
        invoiceId,
        imageId,
      );
      timeoutTimer.cancel();
      logger.i('Scan completed for $imageId: ${result['success']}');
      logger.d('Full result from scan: $result');
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan completed.')),
        );
        await _processAndStoreScanResults(result, imageId);
      } else {
        throw Exception(result['error'] ?? 'Unknown error during scan');
      }
    } catch (e, stackTrace) {
      timeoutTimer.cancel();
      logger.e('[INVOICE_CAPTURE] Error during scan process:',
          error: e, stackTrace: stackTrace);
      ref.read(provider.notifier).setScanError(imageId, e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning image: ${e.toString()}')),
      );
    }
  }

  Future<void> _processAndStoreScanResults(
      Map<String, dynamic> result, String imageId) async {
    final repository = ref.read(projectRepositoryProvider);
    Map<String, dynamic>? invoiceAnalysis;
    if (result.containsKey('invoiceAnalysis') &&
        result['invoiceAnalysis'] != null) {
      invoiceAnalysis = result['invoiceAnalysis'] as Map<String, dynamic>;
      logger.d('Invoice analysis data: $invoiceAnalysis');
    }
    String? validatedLocation;
    if (invoiceAnalysis?['location'] != null) {
      final locationService = ref.read(locationServiceProvider);
      final placeId =
          await locationService.findPlaceId(invoiceAnalysis!['location']);
      if (placeId != null) {
        final placeDetails = await locationService.getPlaceDetails(placeId);
        if (placeDetails != null) {
          validatedLocation = placeDetails['formatted_address'] as String;
          logger.i('Location validated: $validatedLocation');
        }
      }
    }
    bool isInvoice = false;
    if (invoiceAnalysis != null && invoiceAnalysis['isInvoice'] is bool) {
      isInvoice = invoiceAnalysis['isInvoice'];
    }
    logger.i('Updating image with status: $isInvoice');
    await repository.updateImageWithOcrResults(
      projectId,
      invoiceId,
      imageId,
      isInvoice: isInvoice,
    );
    if (validatedLocation != null) {
      logger.i('Validated location found but not stored: $validatedLocation');
    }
    logger.i('OCR results stored for image $imageId with status: $isInvoice');
  }

  Future<void> handleAnalyze() async {
    final images = getImages();
    final currentIndex = getCurrentIndex();
    if (images.isEmpty || currentIndex >= images.length) return;
    final imageInfo = images[currentIndex];
    final functionsService = ref.read(firebaseFunctionsProvider);
    await functionsService.analyzeImage(
      imageInfo.ocrText ?? '',
      projectId,
      invoiceId,
      imageInfo.id,
    );
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> handleDelete() async {
    final images = getImages();
    final currentIndex = getCurrentIndex();
    if (images.isEmpty || currentIndex >= images.length) return;
    final imageToDelete = images[currentIndex];
    final imageIdToDelete = imageToDelete.id;
    final imagePathToDelete = imageToDelete.imagePath;
    final repository = ref.read(projectRepositoryProvider);
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
        invoiceId,
        imageIdToDelete,
      );
      logger.i(
          'Repository delete successful for image ID: $imageIdToDelete, filename: $fileName');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image deleted successfully')),
      );
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
