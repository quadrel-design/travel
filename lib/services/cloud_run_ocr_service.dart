import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../repositories/repository_exceptions.dart';
import '../services/gcs_file_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Cloud Run OCR Service
///
/// Provides a service for interacting with the Cloud Run backend for OCR and analysis,
/// handling HTTP requests, parameter passing, timeouts, and error handling.
class CloudRunOcrService {
  final Logger _logger;
  final String _baseUrl;
  static const int _defaultTimeoutSeconds = 60;

  /// Creates an instance of [CloudRunOcrService].
  ///
  /// Requires a [Logger] instance and the base URL of your Cloud Run service.
  CloudRunOcrService({
    required Logger logger,
    required String baseUrl,
  })  : _logger = logger,
        _baseUrl = baseUrl;

  /// Calls the OCR endpoint to process an image.
  ///
  /// Parameters:
  ///  - [imagePath]: The path of the image to scan.
  ///  - [projectId]: The ID of the associated project/invoice.
  ///  - [invoiceId]: The ID of the specific invoice.
  ///  - [imageId]: The ID of the specific image document.
  ///  - [timeoutSeconds]: Optional timeout duration (defaults to 60s).
  ///
  /// Returns: A [Map<String, dynamic>] containing the OCR result data upon success.
  ///
  /// Throws:
  ///  - [FunctionCallException]: If the API call fails, times out,
  ///    or returns an unexpected result.
  Future<Map<String, dynamic>> scanImage(
      String imagePath, String projectId, String invoiceId, String imageId,
      {int timeoutSeconds = _defaultTimeoutSeconds}) async {
    _logger.d(
        '[OCR] Service scanImage called for imageId: $imageId, invoiceId: $invoiceId');
    try {
      // Always fetch a fresh signed URL for OCR
      final gcsFileService = GcsFileService(backendBaseUrl: _baseUrl);
      final imageUrl =
          await gcsFileService.getSignedDownloadUrl(fileName: imagePath);
      _logger.d('[OCR] Preparing to scan image: $imageUrl');
      _logger.d(
          '[OCR] Project ID: $projectId, Invoice ID: $invoiceId, Image ID: $imageId');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _logger.e('[OCR] User not authenticated for OCR request.');
        throw FunctionCallException('User not authenticated for OCR request',
            functionName: 'ocr-invoice');
      }
      final token = await user.getIdToken();
      final authHeaders = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(
        Uri.parse('$_baseUrl/ocr-invoice'),
        headers: authHeaders,
        body: jsonEncode({
          'imageUrl': imageUrl,
          'projectId': projectId,
          'invoiceId': invoiceId,
          'imageId': imageId,
          'userId': user.uid,
        }),
      )
          .timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          throw TimeoutException(
              'OCR request timed out after $timeoutSeconds seconds');
        },
      );

      if (response.statusCode != 200) {
        throw FunctionCallException(
          'OCR request failed with status ${response.statusCode}',
          functionName: 'ocr-invoice',
          originalException: response.body,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _logger.d('[OCR] Raw result data: $data');

      if (!data.containsKey('success') || data['success'] != true) {
        _logger.w(
            '[OCR] Request successful, but response format is unexpected. Data: $data');
        throw FunctionCallException(
          'OCR response format unexpected',
          functionName: 'ocr-invoice',
          originalException: 'Missing success field in response',
        );
      }

      return data;
    } on TimeoutException catch (e, stackTrace) {
      _logger.e('[OCR] Timeout calling OCR endpoint:',
          error: e, stackTrace: stackTrace);
      throw FunctionCallException(
        'OCR request timed out after $timeoutSeconds seconds',
        functionName: 'ocr-invoice',
        code: 'timeout',
        originalException: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      _logger.e('[OCR] Error scanning image:',
          error: e, stackTrace: stackTrace);
      throw FunctionCallException(
        e.toString(),
        functionName: 'ocr-invoice',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Calls the analysis endpoint to process OCR text.
  ///
  /// Parameters:
  ///  - [ocrText]: The text to analyze.
  ///  - [projectId]: The ID of the associated project/invoice.
  ///  - [invoiceId]: The ID of the specific invoice.
  ///  - [imageId]: The ID of the specific image document.
  ///  - [timeoutSeconds]: Optional timeout duration (defaults to 60s).
  ///
  /// Returns: A [Map<String, dynamic>] containing the analysis result data upon success.
  ///
  /// Throws:
  ///  - [FunctionCallException]: If the API call fails, times out,
  ///    or returns an unexpected result.
  Future<Map<String, dynamic>> analyzeImage(
      String ocrText, String projectId, String invoiceId, String imageId,
      {int timeoutSeconds = _defaultTimeoutSeconds}) async {
    try {
      _logger.d(
          '[ANALYSIS] Preparing to analyze text for project: $projectId, invoice: $invoiceId, image: $imageId');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _logger.e('[ANALYSIS] User not authenticated for Analysis request.');
        throw FunctionCallException(
            'User not authenticated for Analysis request',
            functionName: 'analyze-invoice');
      }
      final token = await user.getIdToken();
      final authHeaders = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(
        Uri.parse('$_baseUrl/analyze-invoice'),
        headers: authHeaders,
        body: jsonEncode({
          'ocrText': ocrText,
          'projectId': projectId,
          'invoiceId': invoiceId,
          'imageId': imageId,
          'userId': user.uid,
        }),
      )
          .timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          throw TimeoutException(
              'Analysis request timed out after $timeoutSeconds seconds');
        },
      );

      debugPrint(
          '[CloudRunOcrService] Raw response body from /analyze-invoice: \${response.body}');

      if (response.statusCode != 200) {
        throw FunctionCallException(
          'Analysis request failed with status ${response.statusCode}',
          functionName: 'analyze-invoice',
          originalException: response.body,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _logger.d('[ANALYSIS] Raw result data: $data');

      if (!data.containsKey('success')) {
        _logger.w(
            '[ANALYSIS] Request successful, but response format is unexpected. Data: $data');
        throw FunctionCallException(
          'Analysis response format unexpected',
          functionName: 'analyze-invoice',
          originalException: 'Missing success field in response',
        );
      }

      _logger.i(
          '[ANALYSIS] Analysis completed successfully with status: ${data['status']}');
      return data;
    } on TimeoutException catch (e, stackTrace) {
      _logger.e('[ANALYSIS] Timeout calling analysis endpoint:',
          error: e, stackTrace: stackTrace);
      throw FunctionCallException(
        'Analysis request timed out after $timeoutSeconds seconds',
        functionName: 'analyze-invoice',
        code: 'timeout',
        originalException: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      _logger.e('[ANALYSIS] Error analyzing image:',
          error: e, stackTrace: stackTrace);
      throw FunctionCallException(
        e.toString(),
        functionName: 'analyze-invoice',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }
}
