/*
 * Invoice Capture Provider
 * 
 * This file defines state management for the invoice capture feature.
 * It handles loading project images, tracking scan status, managing errors,
 * and coordinating the OCR and analysis process.
 * 
 * The providers in this file are essential for the invoice capture workflow,
 * allowing components to reactively update based on the state of image processing
 * and analysis.
 */

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:logger/logger.dart';
import 'package:travel/models/invoice_image_process.dart';
import 'package:travel/providers/logging_provider.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:flutter/foundation.dart';

/// State class for the invoice capture feature.
///
/// Tracks the current state of invoice scanning and processing, including:
/// - List of project images
/// - Scanning status and errors
/// - General errors that might occur during the process
class InvoiceCaptureState extends Equatable {
  /// List of images associated with the project
  final List<InvoiceImageProcess> images;

  /// Map of image IDs to error messages for scan operations
  final Map<String, String?> scanError;

  /// General error message not specific to a particular image
  final String? generalError;

  const InvoiceCaptureState({
    this.images = const [],
    this.scanError = const {},
    this.generalError,
  });

  /// Creates a copy of this state with the specified fields replaced with new values.
  ///
  /// The [clearGeneralError] flag can be used to reset the generalError field to null.
  InvoiceCaptureState copyWith({
    List<InvoiceImageProcess>? images,
    Map<String, String?>? scanError,
    String? generalError,
    bool clearGeneralError = false,
  }) {
    return InvoiceCaptureState(
      images: images ?? this.images,
      scanError: scanError ?? this.scanError,
      generalError:
          clearGeneralError ? null : generalError ?? this.generalError,
    );
  }

  @override
  List<Object?> get props => [
        images,
        scanError,
        generalError,
      ];
}

/// StateNotifier that manages invoice capture state and operations.
///
/// Handles:
/// - Loading project images
/// - Tracking scan status
/// - Managing scan errors
/// - Updating scan status for specific images
class InvoiceCaptureNotifier extends StateNotifier<InvoiceCaptureState> {
  final Logger _logger;
  final String _projectId;
  final String _invoiceId;
  final Ref _ref;
  StreamSubscription<List<InvoiceImageProcess>>? _imageStreamSubscription;

  /// Creates a new InvoiceCaptureNotifier for the specified project and invoice.
  ///
  /// Parameters:
  ///   - _projectId: The ID of the project to load images from
  ///   - _invoiceId: The ID of the invoice to load images from
  ///   - _logger: Logger instance for tracking operations
  ///   - _ref: Riverpod Ref for reading other providers
  InvoiceCaptureNotifier(
      this._projectId, this._invoiceId, this._logger, this._ref)
      : super(const InvoiceCaptureState()) {
    _logger.i(
        'InvoiceCaptureNotifier initialized for projectId: $_projectId, invoiceId: $_invoiceId');
    _loadInitialImages();
  }

  /// Loads the initial set of images for this project and invoice.
  Future<void> _loadInitialImages() async {
    try {
      _logger.d(
          '[INVOICE_CAPTURE] Loading initial images for project $_projectId, invoice $_invoiceId');
      final repository = _ref.read(invoiceRepositoryProvider);
      _imageStreamSubscription =
          repository.getProjectImagesStream(_projectId).listen(
        (newImages) {
          _logger.d(
              '[INVOICE_CAPTURE] Stream received ${newImages.length} images');
          if (!listEquals(state.images, newImages)) {
            _logger.d('[INVOICE_CAPTURE] Image list changed, updating state.');
            state = state.copyWith(images: newImages);
          } else {
            _logger.d(
                '[INVOICE_CAPTURE] Image list is the same, not updating state.');
          }
        },
        onError: (error, stackTrace) {
          _logger.e('[INVOICE_CAPTURE] Error in image stream:',
              error: error, stackTrace: stackTrace);
          state = state.copyWith(
            generalError: 'Failed to load images: ${error.toString()}',
          );
        },
      );
    } catch (e, stackTrace) {
      _logger.e('[INVOICE_CAPTURE] Error loading initial images:',
          error: e, stackTrace: stackTrace);
      state = state.copyWith(
        generalError: 'Failed to load images: \\${e.toString()}',
      );
    }
  }

  /// Sets the state to indicate that scanning has started for the specified image.
  ///
  /// Parameters:
  ///   - imageId: The ID of the image being scanned
  void initiateScan(String imageId) {
    _logger.d('Initiating scan for image ID: $imageId');
    state = state.copyWith(
      scanError: {},
    );
  }

  /// Sets an error message for a specific image scan operation.
  ///
  /// Parameters:
  ///   - imageId: The ID of the image with the error
  ///   - error: The error message
  void setScanError(String imageId, String error) {
    _logger.w('Setting scan error for image ID $imageId: $error');
    state = state.copyWith(
      scanError: {...state.scanError, imageId: error},
    );
  }

  /// Clears the error message for a specific image.
  ///
  /// Parameters:
  ///   - imageId: The ID of the image to clear errors for
  void clearScanError(String imageId) {
    _logger.d('Clearing scan error for image ID: $imageId');
    final newScanError = Map<String, String?>.from(state.scanError);
    newScanError.remove(imageId);
    state = state.copyWith(scanError: newScanError);
  }

  /// Updates the invoiceAnalysis data for a specific image.
  void updateImageAnalysisData(
      String imageId, Map<String, dynamic> newAnalysisData) {
    _logger.d(
        'Updating analysis data for image ID: $imageId with newAnalysisData: $newAnalysisData');
    final imageIndex = state.images.indexWhere((img) => img.id == imageId);
    if (imageIndex != -1) {
      final oldImageInfo = state.images[imageIndex];
      _logger.d(
          '[ANALYSIS_UPDATE] Old imageInfo.invoiceAnalysis: ${oldImageInfo.invoiceAnalysis}');
      _logger.d(
          '[ANALYSIS_UPDATE] Old imageInfo.isInvoiceGuess: ${oldImageInfo.isInvoiceGuess}');
      _logger.d(
          '[ANALYSIS_UPDATE] newAnalysisData received from controller: $newAnalysisData');

      // Extract the 'isInvoice' status from the analysis data to update 'isInvoiceGuess'
      final bool? newIsInvoiceGuess = newAnalysisData['isInvoice'] as bool?;

      // MODIFIED: Convert Map to InvoiceAnalysis object
      final InvoiceAnalysis? newInvoiceAnalysisObject =
          newAnalysisData.isNotEmpty
              ? InvoiceAnalysis.fromJson(newAnalysisData)
              : null;

      final newImageInfo = oldImageInfo.copyWith(
          invoiceAnalysis: newInvoiceAnalysisObject, // Pass the object
          isInvoiceGuess:
              newIsInvoiceGuess, // Update isInvoiceGuess based on analysis
          lastProcessedAt: DateTime.now() // Mark as processed now
          );

      _logger.d(
          '[ANALYSIS_UPDATE] newImageInfo.invoiceAnalysis after copyWith: ${newImageInfo.invoiceAnalysis}');
      _logger.d(
          '[ANALYSIS_UPDATE] newImageInfo.isInvoiceGuess after copyWith: ${newImageInfo.isInvoiceGuess}');

      final updatedImages = List<InvoiceImageProcess>.from(state.images);
      updatedImages[imageIndex] = newImageInfo;

      state = state.copyWith(images: updatedImages);
      _logger.d(
          'Successfully updated analysis data in state for image ID: $imageId');
      _logger.d(
          '[ANALYSIS_UPDATE] State after update - image.invoiceAnalysis: ${state.images[imageIndex].invoiceAnalysis}');
      _logger.d(
          '[ANALYSIS_UPDATE] State after update - image.isInvoiceGuess: ${state.images[imageIndex].isInvoiceGuess}');
    } else {
      _logger
          .w('Could not find image with ID: $imageId to update analysis data.');
    }
  }

  /// Updates the ocrText for a specific image.
  void updateOcrTextForImage(String imageId, String ocrText) {
    _logger.d('Updating ocrText for image ID: $imageId');
    final imageIndex = state.images.indexWhere((img) => img.id == imageId);
    if (imageIndex != -1) {
      final oldImageInfo = state.images[imageIndex];
      final newImageInfo = oldImageInfo.copyWith(
          ocrText: ocrText, lastProcessedAt: DateTime.now());
      final updatedImages = List<InvoiceImageProcess>.from(state.images);
      updatedImages[imageIndex] = newImageInfo;
      state = state.copyWith(images: updatedImages);
      _logger.d('Successfully updated ocrText in state for image ID: $imageId');
    } else {
      _logger.w('Could not find image with ID: $imageId to update ocrText.');
    }
  }

  @override
  void dispose() {
    _logger.d(
        'Disposing InvoiceCaptureNotifier for projectId: $_projectId, invoiceId: $_invoiceId');
    _imageStreamSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for managing invoice capture state for a specific project and invoice.
///
/// This provider creates and maintains a StateNotifier that manages all aspects
/// of the invoice capture process for a given project ID and invoice ID, including:
/// - Image loading and tracking
/// - OCR scanning status
/// - Error handling
/// - State updates
///
/// Parameters:
///   - projectId: The ID of the project to manage invoice capture for
///   - invoiceId: The ID of the invoice to manage invoice capture for
///
/// Usage: `final captureState = ref.watch(invoiceCaptureProvider(projectId, invoiceId));`
final invoiceCaptureProvider = StateNotifierProvider.autoDispose.family<
    InvoiceCaptureNotifier,
    InvoiceCaptureState,
    ({String projectId, String invoiceId})>(
  (ref, ids) {
    final logger = ref.watch(loggerProvider);
    return InvoiceCaptureNotifier(ids.projectId, ids.invoiceId, logger, ref);
  },
);
