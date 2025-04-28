import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel/models/invoice_capture_process.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:travel/providers/logging_provider.dart';
import 'dart:math' as math;

/// Utility class for invoice OCR scanning that can be shared across screens
class InvoiceScanUtil {
  /// Updates the OCR results directly in Firestore as a fallback
  static Future<void> manuallyUpdateOcrResults(
      BuildContext context,
      WidgetRef ref,
      String journeyId,
      String imageId,
      Map<String, dynamic> resultData) async {
    final logger = ref.read(loggerProvider);
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      logger.d("📝 Manually updating OCR results for image $imageId");
      logger.d("📝 Raw result data: $resultData");

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('invoices')
          .doc(journeyId)
          .collection('images')
          .doc(imageId);

      // Extract key data from the result - check various possible field names
      // The Cloud Function might use different field names than our database expects
      final status = resultData['status'] as String? ?? 'unknown';

      // Check field names in priority order based on Cloud Function response structure:
      // 1. extractedText - This is now what the Cloud Function uses
      // 2. detectedText - This might be used in older versions
      // 3. text - Alternative name that might be used
      // 4. fullText - Alternative name that might be used
      String? extractedText = resultData['extractedText'] as String?;

      // If primary field is empty, check alternatives
      if (extractedText == null || extractedText.isEmpty) {
        extractedText = resultData['detectedText'] as String?;
      }
      if (extractedText == null || extractedText.isEmpty) {
        extractedText = resultData['text'] as String?;
      }
      if (extractedText == null || extractedText.isEmpty) {
        extractedText = resultData['fullText'] as String?;
      }

      // Log all fields to help diagnose what's in the response
      logger.d("📝 All result data keys: ${resultData.keys.join(', ')}");
      logger
          .d("📝 extractedText found: ${extractedText != null ? 'YES' : 'NO'}");

      // Handle confidence field which might be in different formats
      final double confidence;
      if (resultData['confidence'] is double) {
        confidence = resultData['confidence'] as double;
      } else if (resultData['confidence'] is int) {
        confidence = (resultData['confidence'] as int).toDouble();
      } else if (resultData['confidence'] is String) {
        confidence = double.tryParse(resultData['confidence'] as String) ?? 0.0;
      } else {
        confidence = 0.0;
      }

      // Create update data
      final updateData = {
        'status': status,
        'extractedText': extractedText ?? '',
        'confidence': confidence,
        'lastProcessedAt': FieldValue.serverTimestamp(),
        'manuallyUpdated': true // Flag to indicate this was updated by client
      };

      logger.d(
          "📝 Update data: Status=$status, textLength=${extractedText?.length ?? 0}, confidence=$confidence");

      await docRef.update(updateData);
      logger.i("📝 Manual OCR results update successful");
    } catch (e) {
      logger.e("📝 Manual OCR update failed", error: e);
    }
  }

  static Future<void> scanImage(BuildContext context, WidgetRef ref,
      String journeyId, InvoiceCaptureProcess imageInfo) async {
    final logger = ref.read(loggerProvider);
    try {
      logger.d("🔍 Starting OCR scan for image ${imageInfo.id}...");
      logger.d("🔍 Image URL: ${imageInfo.url}");
      logger.d("🔍 Journey ID: $journeyId");
      logger.d("🔍 Image ID: ${imageInfo.id}");

      // Immediately show feedback to user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OCR processing started...')),
        );
      }

      // First update status to ocr_running
      try {
        final userId = FirebaseAuth.instance.currentUser!.uid;
        logger.d("🔍 User ID: $userId");

        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('invoices')
            .doc(journeyId)
            .collection('images')
            .doc(imageInfo.id);

        logger.d(
            "🔍 Updating document at path: /users/$userId/invoices/$journeyId/images/${imageInfo.id}");

        await docRef.update({
          'status': 'ocr_running',
          'updated_at': FieldValue.serverTimestamp(),
        });

        logger.d("🔍 Status updated to ocr_running");

        // Verify the update worked
        final updatedDoc = await docRef.get();
        logger.d("🔍 Verified document exists: ${updatedDoc.exists}");
        if (updatedDoc.exists) {
          logger.d("🔍 Current status: ${updatedDoc.data()?['status']}");
        }
      } catch (updateError) {
        logger.e("🔍 Error updating status to ocr_running", error: updateError);
        // Continue even if this fails
      }

      // Call the OCR function
      logger.d("🔍 Calling Firebase Cloud Function 'detectImage'");
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('detectImage');

      final params = {
        'imageUrl': imageInfo.url,
        'invoiceId': journeyId,
        'imageId': imageInfo.id,
      };
      print(
          'Calling detectImage with invoiceId: $journeyId, imageId: ${imageInfo.id}, imageUrl: ${imageInfo.url}');
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

        // Check for status field
        if (resultMap.containsKey('status')) {
          logger.d("🔍 Status field: ${resultMap['status']}");
        } else {
          logger.w("🔍 Result does not contain 'status' field");
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

      // Check if the database was updated
      try {
        final userId = FirebaseAuth.instance.currentUser!.uid;
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('invoices')
            .doc(journeyId)
            .collection('images')
            .doc(imageInfo.id);

        final updatedDoc = await docRef.get();
        final currentStatus = updatedDoc.data()?['status'];
        final hasExtractedText =
            updatedDoc.data()?.containsKey('extractedText') ?? false;
        final extractedTextValue = updatedDoc.data()?['extractedText'];

        logger.d("🔍 After OCR - Document status: $currentStatus");
        logger.d("🔍 After OCR - Has extractedText field: $hasExtractedText");
        if (hasExtractedText) {
          logger.d(
              "🔍 extractedText is ${extractedTextValue == null ? 'null' : 'not null'} with type: ${extractedTextValue?.runtimeType}");
          if (extractedTextValue != null &&
              extractedTextValue is String &&
              extractedTextValue.isNotEmpty) {
            final text = extractedTextValue;
            logger.d(
                "🔍 extractedText sample: ${text.substring(0, math.min(50, text.length))}...");
          } else {
            logger.w("🔍 extractedText exists but is empty or null");
          }
        }

        if (currentStatus == 'ocr_running' ||
            !hasExtractedText ||
            extractedTextValue == null) {
          logger.w(
              "🔍 WARNING: Cloud Function did not update the document properly");

          // Manually update the document with OCR results
          if (result.data is Map) {
            await InvoiceScanUtil.manuallyUpdateOcrResults(context, ref,
                journeyId, imageInfo.id, result.data as Map<String, dynamic>);
          } else {
            // Try to convert non-map data to a map
            final fallbackMap = <String, dynamic>{
              'status': 'unknown',
              'extractedText': result.data?.toString() ?? '',
              'confidence': 0.0
            };
            await InvoiceScanUtil.manuallyUpdateOcrResults(
                context, ref, journeyId, imageInfo.id, fallbackMap);
          }
        } else {
          logger
              .i("🔍 Document was successfully updated by the Cloud Function");
        }
      } catch (verifyError) {
        logger.e("🔍 Error verifying document update after OCR",
            error: verifyError);

        // Still try to manually update if verification failed
        if (result.data is Map) {
          await InvoiceScanUtil.manuallyUpdateOcrResults(context, ref,
              journeyId, imageInfo.id, result.data as Map<String, dynamic>);
        } else {
          await InvoiceScanUtil.manuallyUpdateOcrResults(
              context, ref, journeyId, imageInfo.id, {'status': 'unknown'});
        }
      }

      // Show appropriate message based on result
      if (context.mounted) {
        String message;

        if (result.data is Map<String, dynamic>) {
          final resultMap = result.data as Map<String, dynamic>;
          final status = resultMap['status'] as String? ?? 'unknown';

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

      // Try to reset status on error
      try {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('invoices')
            .doc(journeyId)
            .collection('images')
            .doc(imageInfo.id);

        await docRef.update({
          'status': 'ready',
          'updated_at': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Ignore errors when resetting status
      }
    }
  }
}
