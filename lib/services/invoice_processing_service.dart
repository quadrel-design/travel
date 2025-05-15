import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice_image_process.dart';
import '../providers/service_providers.dart' as services;
import '../providers/logging_provider.dart';
import '../providers/repository_providers.dart';
import '../config/service_config.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../services/gcs_file_service.dart';

class InvoiceProcessingService {
  final Ref ref;

  InvoiceProcessingService(this.ref);

  Future<bool> runOCR(
      String projectId, String invoiceId, String imageId) async {
    final logger = ref.read(loggerProvider);
    logger.i('Starting OCR processing for image $imageId');

    try {
      // Get the image repository to fetch the image path
      final invoiceRepository = ref.read(invoiceRepositoryProvider);

      // Get the auth repository to fetch current user
      final authRepository = ref.read(authRepositoryProvider);
      final userId = authRepository.currentUser?.uid ?? "unknown-user";

      // Fetch the invoice image to get its path
      final imagesStream = invoiceRepository.getProjectImagesStream(projectId);
      final images = await imagesStream.first;

      // Find the specific image we're processing
      final matchingImages = images.where((img) => img.id == imageId).toList();
      if (matchingImages.isEmpty) {
        logger.e('Image with ID $imageId not found in repository');
        return false;
      }

      final imageInfo = matchingImages.first;
      final imagePath = imageInfo.imagePath;

      if (imagePath == null || imagePath.isEmpty) {
        logger.e('No image path found for image $imageId');
        return false;
      }

      logger.d('Found image path: $imagePath');

      // Use the correct API URL from config
      final backendUrl = ServiceConfig.gcsApiBaseUrl;
      logger.d('Using backend URL: $backendUrl for OCR processing');

      // Create a GCS file service to get a signed URL
      final gcsFileService = GcsFileService(backendBaseUrl: backendUrl);
      final imageUrl =
          await gcsFileService.getSignedDownloadUrl(fileName: imagePath);
      logger.d(
          'Generated signed URL for image: ${imageUrl.substring(0, math.min(50, imageUrl.length))}...');

      // Make API request to backend service
      final response = await http.post(
        Uri.parse('$backendUrl/ocr-invoice'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'projectId': projectId,
          'invoiceId': invoiceId,
          'imageId': imageId,
          'imageUrl': imageUrl,
          'userId': userId,
        }),
      );

      logger.d('OCR response status: ${response.statusCode}');
      logger.d(
          'OCR response body: ${response.body.substring(0, math.min(100, response.body.length))}...');

      if (response.statusCode == 200 || response.statusCode == 202) {
        logger.i('OCR request sent successfully for image $imageId');
        return true;
      } else {
        logger.e(
            'OCR request failed with status ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      logger.e('Error sending OCR request', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> runAnalysis(
      String projectId, String invoiceId, String imageId) async {
    final logger = ref.read(loggerProvider);
    logger.i('Starting analysis for image $imageId');

    try {
      // Get the image repository to fetch OCR text
      final invoiceRepository = ref.read(invoiceRepositoryProvider);

      // Get the auth repository to fetch current user
      final authRepository = ref.read(authRepositoryProvider);
      final userId = authRepository.currentUser?.uid ?? "unknown-user";

      // Fetch the invoice image data from the repository
      // Since we don't have a direct getInvoiceImage method in the repository,
      // we'll have to listen to the stream briefly to get the image
      logger.d('Fetching image data for imageId: $imageId');
      final imagesStream = invoiceRepository.getProjectImagesStream(projectId);
      final images = await imagesStream.first;

      // Find the specific image we're analyzing
      final matchingImages = images.where((img) => img.id == imageId).toList();
      if (matchingImages.isEmpty) {
        logger.e('Image with ID $imageId not found in repository');
        return false;
      }

      final imageInfo = matchingImages.first;

      // Debug the image data we found
      logger.d('Found image: ${imageInfo.id}');
      logger.d('OCR text length: ${imageInfo.ocrText?.length ?? 0}');
      logger.d(
          'Has OCR text: ${imageInfo.ocrText != null && imageInfo.ocrText!.isNotEmpty}');

      // Check if OCR text exists
      if (imageInfo.ocrText == null || imageInfo.ocrText!.isEmpty) {
        logger.e(
            'OCR text is not available for image $imageId. Please run OCR first.');
        return false;
      }

      // Use the correct API URL from config
      final backendUrl = ServiceConfig.gcsApiBaseUrl;
      logger.d('Using backend URL: $backendUrl for analysis');

      // Make API request with actual OCR text and user ID
      final response = await http.post(
        Uri.parse('$backendUrl/analyze-invoice'),
        headers: {
          'Content-Type': 'application/json',
          // 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'projectId': projectId,
          'invoiceId': invoiceId,
          'imageId': imageId,
          'ocrText': imageInfo.ocrText,
          'userId': userId,
        }),
      );

      logger.d('Analysis response status: ${response.statusCode}');

      // Log the full response for debug purposes
      try {
        final responseMap = json.decode(response.body);
        logger.d('Analysis response data: $responseMap');

        // Even if the analysis determines this is not an invoice, we consider
        // the API call successful as long as we got a response
        if (response.statusCode == 200 || response.statusCode == 202) {
          logger.i('Analysis request sent successfully for image $imageId');

          // If the backend sent an ApiError status but returned a 200 status code,
          // we still consider it a successful request (just not a successful analysis)
          return true;
        }
      } catch (e) {
        logger.e('Error parsing response body: $e');
        logger.d(
            'Raw response body: ${response.body.substring(0, math.min(100, response.body.length))}...');
      }

      logger.e(
          'Analysis request failed with status ${response.statusCode}: ${response.body}');
      return false;
    } catch (e, stackTrace) {
      logger.e('Error sending analysis request',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }
}
