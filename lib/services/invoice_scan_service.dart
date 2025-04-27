/**
 * Invoice Scan Service
 *
 * Provides a service to manage the end-to-end invoice scanning process,
 * including triggering the backend scan function and processing/validating the results.
 */
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../services/firebase_functions_service.dart';
import '../services/location_service.dart';
import '../repositories/invoice_repository.dart';
import '../repositories/repository_exceptions.dart'; // For FunctionCallException

/// Service for handling invoice scanning and processing
class InvoiceScanService {
  final Logger _logger;
  final FirebaseFunctionsService _functionsService;
  final InvoiceRepository _repository;
  final LocationService _locationService;

  /// Creates an instance of [InvoiceScanService].
  ///
  /// Requires instances of [Logger], [FirebaseFunctionsService],
  /// [InvoiceRepository], and [LocationService].
  InvoiceScanService({
    required Logger logger,
    required FirebaseFunctionsService functionsService,
    required InvoiceRepository repository,
    required LocationService locationService,
  })  : _logger = logger,
        _functionsService = functionsService,
        _repository = repository,
        _locationService = locationService;

  /// Scans an image by calling the backend Cloud Function and processes the results.
  ///
  /// Parameters:
  ///  - [imageId]: The unique ID of the image document in Firestore.
  ///  - [imageUrl]: The URL of the image to be scanned.
  ///  - [journeyId]: The ID of the parent invoice/journey document.
  ///  - [onScanComplete]: A callback function executed after processing (success or failure).
  ///
  /// Returns: A [Map<String, dynamic>] containing the result from the Cloud Function
  ///          if successful, or an error map (`{'success': false, 'error': ...}`) if an error occurs.
  Future<Map<String, dynamic>> scanImage({
    required String imageId,
    required String imageUrl,
    required String journeyId,
    required VoidCallback onScanComplete,
  }) async {
    Map<String, dynamic> result = {'success': false};

    try {
      // The function service might handle empty URLs, but basic check here is okay.
      // if (imageUrl.isEmpty) { ... }

      // Call Firebase function to perform scan
      _logger
          .i('Calling Firebase Cloud Function for scanning image ID: $imageId');
      result = await _functionsService.scanImage(
        imageUrl,
        journeyId,
        imageId, // Pass necessary parameters
      );

      _logger.i('Scan completed for $imageId: ${result['success']}');
      // Since the functions service now throws on failure, this point means success.
      await _processSuccessfulScan(journeyId, imageId, result);

      onScanComplete();
      return result;
    } on FunctionCallException catch (e, stackTrace) {
      _logger.e('[INVOICE_SCAN] Error during scan process:',
          error: e, stackTrace: stackTrace);

      result = {
        'success': false,
        'error': e.message, // Use the message from the custom exception
        'code': e.code, // Include the code if available
      };
      onScanComplete(); // Ensure callback is called even on error
      return result;
    } catch (e, stackTrace) {
      // Catch any other unexpected errors
      _logger.e('[INVOICE_SCAN] Unexpected error during scan process:',
          error: e, stackTrace: stackTrace);
      result = {
        'success': false,
        'error': 'An unexpected error occurred during the scan process.',
      };
      onScanComplete(); // Ensure callback is called even on error
      return result;
    }
  }

  /// Processes the results from a successful Cloud Function scan call.
  /// Extracts relevant data, validates location, and updates the repository.
  Future<void> _processSuccessfulScan(
      String journeyId, String imageId, Map<String, dynamic> result) async {
    // Extract basic data
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
      isInvoice: isInvoice,
      status: status,
    );

    // Log the validated location that couldn't be saved due to repository limitations
    if (validatedLocation != null) {
      _logger.i('Validated location found but not stored: $validatedLocation');
    }

    _logger.i('OCR results stored for image $imageId with status: $status');
  }

  /// Validates a location string using the LocationService.
  /// Tries to find a Place ID and get details to return a formatted address.
  /// Returns the original location string if validation fails or an error occurs.
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
