import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel/models/invoice_image_process.dart';
import 'package:travel/providers/logging_provider.dart';
import 'package:travel/providers/service_providers.dart' as service_providers;
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';

/// Utility class for invoice OCR scanning that can be shared across screens
class InvoiceScanUtil {
  static Future<void> scanImage(BuildContext context, WidgetRef ref,
      String projectId, String invoiceId, InvoiceImageProcess imageInfo) async {
    final logger = ref.read(loggerProvider);
    try {
      logger.d("🔍 Starting OCR scan for image ${imageInfo.id}...");
      logger.d("🔍 Image URL: ${imageInfo.url}");
      logger.d("🔍 Project ID: $projectId");
      logger.d("🔍 Invoice ID: $invoiceId");
      logger.d("🔍 Image ID: ${imageInfo.id}");

      // Immediately show feedback to user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OCR processing started...')),
        );
      }

      // Get the current user ID
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (userId.isEmpty) {
        logger.e("🔍 No userId found. Aborting OCR scan.");
        throw Exception("User not authenticated.");
      }

      // Call the OCR service
      logger.d("🔍 Calling Cloud Run OCR endpoint");
      final ocrService = ref.read(service_providers.cloudRunOcrServiceProvider);
      final result = await ocrService.scanImage(
        imageInfo.imagePath,
        projectId,
        invoiceId,
        imageInfo.id,
      );

      logger.i("🔍 OCR processing completed successfully");

      // More detailed logging of the response structure
      logger.d("🔍 OCR result data raw: ${result.toString()}");
      logger.d("🔍 OCR result data type: ${result.runtimeType}");

      logger.d("🔍 Result is a Map with keys: ${result.keys.join(', ')}");

      // Log each field to understand what the OCR service returned
      result.forEach((key, value) {
        if (value is String) {
          logger.d(
              "🔍 Field '$key': ${value.length > 50 ? '${value.substring(0, 50)}...' : value}");
        } else {
          logger.d("🔍 Field '$key': $value");
        }
      });

      // Check for text content under different possible field names
      if (result.containsKey('ocrText')) {
        final text = result['ocrText']?.toString() ?? '';
        logger.d(
            "🔍 Contains 'ocrText' field: ${text.isNotEmpty ? '${text.substring(0, math.min(50, text.length))}...' : 'empty'}");
      } else if (result.containsKey('detectedText')) {
        final text = result['detectedText']?.toString() ?? '';
        logger.d(
            "🔍 Contains 'detectedText' field: ${text.isNotEmpty ? '${text.substring(0, math.min(50, text.length))}...' : 'empty'}");
      }
      if (result.containsKey('text')) {
        final text = result['text']?.toString() ?? '';
        logger.d(
            "🔍 Contains 'text' field: ${text.isNotEmpty ? '${text.substring(0, math.min(50, text.length))}...' : 'empty'}");
      }
      if (result.containsKey('fullText')) {
        final text = result['fullText']?.toString() ?? '';
        logger.d(
            "🔍 Contains 'fullText' field: ${text.isNotEmpty ? '${text.substring(0, math.min(50, text.length))}...' : 'empty'}");
      }

      // Check for confidence field
      if (result.containsKey('confidence')) {
        logger.d("🔍 Confidence: ${result['confidence']}");
      }

      // Log any error information
      if (result.containsKey('error')) {
        logger.e("🔍 Error from OCR service: ${result['error']}");
      }

      // Show appropriate message based on result
      if (context.mounted) {
        String message;

        final status = result['status'] as String? ?? 'uploaded';

        if (status == 'invoice') {
          message = 'OCR completed: Text detected!';
        } else if (status == 'no invoice') {
          message = 'OCR completed: No text detected';
        } else if (status == 'Error') {
          message =
              'OCR completed with error: ${result['error'] ?? 'Unknown error'}';
        } else {
          message = 'OCR completed with status: $status';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      logger.e("🔍 Error during OCR scan: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning image: $e')),
        );
      }
    }
  }
}
