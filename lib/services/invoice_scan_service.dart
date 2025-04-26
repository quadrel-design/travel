import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../models/invoice_capture_process.dart';
import '../services/firebase_functions_service.dart';
import '../services/location_service.dart';
import '../repositories/invoice_repository.dart';

/// Service for handling invoice scanning and processing
class InvoiceScanService {
  final Logger _logger;
  final FirebaseFunctionsService _functionsService;
  final InvoiceRepository _repository;
  final LocationService _locationService;

  InvoiceScanService({
    required Logger logger,
    required FirebaseFunctionsService functionsService,
    required InvoiceRepository repository,
    required LocationService locationService,
  })  : _logger = logger,
        _functionsService = functionsService,
        _repository = repository,
        _locationService = locationService;

  /// Scans an image and updates the repository with the results
  Future<Map<String, dynamic>> scanImage({
    required String imageId,
    required String imageUrl,
    required String journeyId,
    required VoidCallback onScanComplete,
  }) async {
    Map<String, dynamic> result = {'success': false};

    try {
      // Validate URL
      if (imageUrl.isEmpty) {
        throw Exception('Image URL is empty. Cannot proceed with scan.');
      }

      _logger.d("Attempting to download from: $imageUrl");
      final httpResponse = await http.get(Uri.parse(imageUrl));
      _logger.d("Image download status: ${httpResponse.statusCode}");

      if (httpResponse.statusCode != 200) {
        throw Exception("Failed to download image: ${httpResponse.statusCode}");
      }

      _logger.d("Image downloaded successfully for scan (ID: $imageId)");

      // Call Firebase function to perform scan
      _logger
          .i('Calling Firebase Cloud Function for scanning image ID: $imageId');
      result = await _functionsService.scanImage(
        imageUrl,
        journeyId,
        imageId,
      );

      _logger.i('Scan completed for $imageId: ${result['success']}');
      _logger.d('Full result from scan: $result');

      if (result['success'] == true) {
        await _processSuccessfulScan(journeyId, imageId, result);
      } else {
        throw Exception(result['error'] ?? 'Unknown error during scan');
      }

      onScanComplete();
      return result;
    } catch (e, stackTrace) {
      _logger.e('[INVOICE_SCAN] Error during scan process:',
          error: e, stackTrace: stackTrace);

      result = {
        'success': false,
        'error': e.toString(),
        'errorDetails': stackTrace.toString(),
      };

      return result;
    }
  }

  Future<void> _processSuccessfulScan(
      String journeyId, String imageId, Map<String, dynamic> result) async {
    // Extract basic data
    final hasText = result['hasText'] ?? false;
    final detectedText = result['detectedText'] as String?;
    final status = result['status'] as String? ?? 'Text';

    // Extract invoice analysis data if available
    Map<String, dynamic>? invoiceAnalysis;
    if (result.containsKey('invoiceAnalysis') &&
        result['invoiceAnalysis'] != null) {
      invoiceAnalysis = result['invoiceAnalysis'] as Map<String, dynamic>;
      _logger.d('Invoice analysis data: $invoiceAnalysis');
    }

    // Only validate location if we have invoice analysis
    String? validatedLocation;
    if (status == 'Invoice' && invoiceAnalysis?['location'] != null) {
      validatedLocation = await _validateLocation(invoiceAnalysis!['location']);
    }

    // Parse amount and currency
    double? totalAmount;
    String? currency;

    if (status == 'Invoice' && invoiceAnalysis != null) {
      totalAmount = _parseTotalAmount(invoiceAnalysis);
      currency = _getCurrency(invoiceAnalysis);
    }

    // Determine if it's an invoice
    bool isInvoice = status == 'Invoice';
    if (invoiceAnalysis != null && invoiceAnalysis['isInvoice'] is bool) {
      isInvoice = invoiceAnalysis['isInvoice'];
    }

    _logger.i('Updating image with status: $status, isInvoice: $isInvoice');

    // Update the repository
    await _repository.updateImageWithOcrResults(
      journeyId,
      imageId,
      hasText: true,
      detectedText: detectedText,
      totalAmount: totalAmount,
      currency: currency,
      isInvoice: isInvoice,
      status: status,
    );

    // Log the validated location that couldn't be saved due to repository limitations
    if (validatedLocation != null) {
      _logger.i('Validated location found but not stored: $validatedLocation');
    }

    _logger.i('OCR results stored for image $imageId with status: $status');
  }

  double? _parseTotalAmount(Map<String, dynamic> invoiceAnalysis) {
    if (invoiceAnalysis['totalAmount'] != null) {
      var amountValue = invoiceAnalysis['totalAmount'];
      if (amountValue is num) {
        final amount = amountValue.toDouble();
        _logger.d('Total amount is already a number: $amount');
        return amount;
      } else {
        final amountStr = amountValue.toString();
        final amount = double.tryParse(amountStr);
        _logger.d('Parsed total amount from string: $amountStr -> $amount');

        if (amount == null) {
          _logger.w('Could not parse totalAmount: $amountStr');
        }

        return amount;
      }
    } else {
      _logger.w('totalAmount is missing from invoice analysis');
      return null;
    }
  }

  String? _getCurrency(Map<String, dynamic> invoiceAnalysis) {
    if (invoiceAnalysis['currency'] != null) {
      final currency = invoiceAnalysis['currency'].toString();
      _logger.d('Currency: $currency');
      return currency;
    } else {
      _logger.w('currency is missing from invoice analysis');
      return null;
    }
  }

  Future<String?> _validateLocation(String location) async {
    try {
      final placeId = await _locationService.findPlaceId(location);
      if (placeId != null) {
        final placeDetails = await _locationService.getPlaceDetails(placeId);
        if (placeDetails != null) {
          final formattedAddress = placeDetails['formatted_address'] as String;
          _logger.i('Location validated: $formattedAddress');
          return formattedAddress;
        }
      }
      return location; // Return original if validation fails
    } catch (e) {
      _logger.w('Error validating location: $e');
      return location; // Return original location on error
    }
  }
}
