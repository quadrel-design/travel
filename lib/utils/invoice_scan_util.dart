import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel/models/invoice_image_process.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:travel/providers/logging_provider.dart';
import 'dart:math' as math;
import 'package:travel/models/invoice_image_status.dart';

/// Utility class for invoice OCR scanning that can be shared across screens
class InvoiceScanUtil {
  static Future<void> scanImage(BuildContext context, WidgetRef ref,
      String projectId, InvoiceImageProcess imageInfo) async {
    final logger = ref.read(loggerProvider);
    try {
      logger.d("🔍 Starting OCR scan for image ${imageInfo.id}...");
      logger.d("🔍 Image URL: ${imageInfo.url}");
      logger.d("🔍 Project ID: $projectId");
      logger.d("🔍 Image ID: ${imageInfo.id}");

      // Immediately show feedback to user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OCR processing started...')),
        );
      }

      // Call the OCR function
      logger.d("🔍 Calling Firebase Cloud Function 'detectImage'");
      print('Apply to image-detect...');
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('detectImage');

      final params = {
        'imageUrl': imageInfo.url,
        'projectId': projectId,
        'invoiceId': 'main',
        'imageId': imageInfo.id,
      };
      print(
          'Calling detectImage with invoiceId: $projectId, imageId: ${imageInfo.id}, imageUrl: ${imageInfo.url}');
      logger.d("🔍 Function parameters: $params");

      final result = await callable.call(params);

      logger.i("🔍 OCR processing completed successfully");

      // More detailed logging of the response structure
      logger.d("🔍 OCR result data raw: ${result.data.toString()}");
      logger.d("🔍 OCR result data type: ${result.data.runtimeType}");

      if (result.data is Map<String, dynamic>) {
        final resultMap = result.data as Map<String, dynamic>;
        logger.d("🔍 Result is a Map with keys: ${resultMap.keys.join(', ')}");

        // Log each field to understand what the Cloud Function returned
        resultMap.forEach((key, value) {
          if (value is String) {
            logger.d(
                "🔍 Field '$key': ${value.length > 50 ? '${value.substring(0, 50)}...' : value}");
          } else {
            logger.d("🔍 Field '$key': $value");
          }
        });

        // Check for text content under different possible field names
        if (resultMap.containsKey('extractedText')) {
          final text = resultMap['extractedText']?.toString() ?? '';
          logger.d(
              "🔍 Contains 'extractedText' field: ${text.isNotEmpty ? '${text.substring(0, math.min(50, text.length))}...' : 'empty'}");
        } else if (resultMap.containsKey('detectedText')) {
          final text = resultMap['detectedText']?.toString() ?? '';
          logger.d(
              "🔍 Contains 'detectedText' field: ${text.isNotEmpty ? '${text.substring(0, math.min(50, text.length))}...' : 'empty'}");
        }
        if (resultMap.containsKey('text')) {
          final text = resultMap['text']?.toString() ?? '';
          logger.d(
              "🔍 Contains 'text' field: ${text.isNotEmpty ? '${text.substring(0, math.min(50, text.length))}...' : 'empty'}");
        }
        if (resultMap.containsKey('fullText')) {
          final text = resultMap['fullText']?.toString() ?? '';
          logger.d(
              "🔍 Contains 'fullText' field: ${text.isNotEmpty ? '${text.substring(0, math.min(50, text.length))}...' : 'empty'}");
        }

        // Check for confidence field
        if (resultMap.containsKey('confidence')) {
          logger.d("🔍 Confidence: ${resultMap['confidence']}");
        }

        // Log any error information
        if (resultMap.containsKey('error')) {
          logger.e("🔍 Error from Cloud Function: ${resultMap['error']}");
        }
      } else {
        logger.w(
            "🔍 Result data is not a Map, it's a ${result.data.runtimeType}");
        if (result.data != null) {
          logger.d("🔍 Non-map result value: ${result.data.toString()}");
        }
      }

      // Show appropriate message based on result
      if (context.mounted) {
        String message;

        if (result.data is Map<String, dynamic>) {
          final resultMap = result.data as Map<String, dynamic>;
          final status = resultMap['status'] as String? ?? 'uploaded';

          if (status == 'invoice') {
            message = 'OCR completed: Text detected!';
          } else if (status == 'no invoice') {
            message = 'OCR completed: No text detected';
          } else if (status == 'Error') {
            message =
                'OCR completed with error: ${resultMap['error'] ?? 'Unknown error'}';
          } else {
            message = 'OCR completed with status: $status';
          }
        } else {
          message = 'OCR completed but received unexpected response format';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      logger.e("🔍 Error starting OCR process", error: e);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting OCR: $e')),
        );
      }
    }
  }
}
