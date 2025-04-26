import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class OcrService {
  final FirebaseFunctions _functions;

  OcrService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  /// Process an image file using OCR to detect text
  /// This is the first step in the two-step process
  Future<Map<String, dynamic>> detectImageText(
    File imageFile,
    String journeyId,
    String imageId,
  ) async {
    try {
      // Read the file as bytes
      final bytes = await imageFile.readAsBytes();

      // Convert bytes to base64
      final base64Image = base64Encode(bytes);

      // Call the first Firebase Function to detect text
      final result = await _functions
          .httpsCallable('detectImage')
          .call<Map<String, dynamic>>({
        'imageData': base64Image,
        'journeyId': journeyId,
        'imageId': imageId,
      });

      return result.data;
    } catch (e) {
      debugPrint('Error detecting text in image: $e');
      rethrow;
    }
  }

  /// Analyze detected text for invoice information
  /// This is the second step in the two-step process
  Future<Map<String, dynamic>> analyzeDetectedText(
    String detectedText,
    String journeyId,
    String imageId,
  ) async {
    try {
      // Call the second Firebase Function to analyze the text
      final result = await _functions
          .httpsCallable('analyzeImage')
          .call<Map<String, dynamic>>({
        'detectedText': detectedText,
        'journeyId': journeyId,
        'imageId': imageId,
      });

      return result.data;
    } catch (e) {
      debugPrint('Error analyzing text: $e');
      rethrow;
    }
  }

  /// Process an image URL using the legacy combined function
  /// This uses the original scanImage function that does both steps at once
  Future<Map<String, dynamic>> processImageLegacy(
    String imageUrl,
    String journeyId,
    String imageId,
  ) async {
    try {
      // Call the Firebase Function with the URL
      final result = await _functions
          .httpsCallable('scanImage')
          .call<Map<String, dynamic>>({
        'imageUrl': imageUrl,
        'journeyId': journeyId,
        'imageId': imageId,
        'skipAnalysis': false,
      });

      return result.data;
    } catch (e) {
      debugPrint('Error processing image with legacy function: $e');
      rethrow;
    }
  }
}
