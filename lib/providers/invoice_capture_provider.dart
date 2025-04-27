/*
 * Invoice Capture Provider
 * 
 * This file defines state management for the invoice capture feature.
 * It handles loading journey images, tracking scan status, managing errors,
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
import 'package:travel/models/invoice_capture_process.dart';
import 'package:travel/providers/logging_provider.dart';
import 'package:travel/providers/repository_providers.dart';

/// State class for the invoice capture feature.
///
/// Tracks the current state of invoice scanning and processing, including:
/// - List of journey images
/// - Scanning status and errors
/// - General errors that might occur during the process
class InvoiceCaptureState extends Equatable {
  /// List of images associated with the journey
  final List<InvoiceCaptureProcess> images;

  /// Map of image IDs to error messages for scan operations
  final Map<String, String?> scanError;

  /// General error message not specific to a particular image
  final String? generalError;

  /// ID of the image currently being scanned, if any
  final String? scanningImageId;

  const InvoiceCaptureState({
    this.images = const [],
    this.scanError = const {},
    this.generalError,
    this.scanningImageId,
  });

  /// Creates a copy of this state with the specified fields replaced with new values.
  ///
  /// The [clearGeneralError] and [clearScanningImageId] flags can be used to reset
  /// those fields to null.
  InvoiceCaptureState copyWith({
    List<InvoiceCaptureProcess>? images,
    Map<String, String?>? scanError,
    String? generalError,
    String? scanningImageId,
    bool clearGeneralError = false,
    bool clearScanningImageId = false,
  }) {
    return InvoiceCaptureState(
      images: images ?? this.images,
      scanError: scanError ?? this.scanError,
      generalError:
          clearGeneralError ? null : generalError ?? this.generalError,
      scanningImageId:
          clearScanningImageId ? null : scanningImageId ?? this.scanningImageId,
    );
  }

  @override
  List<Object?> get props => [
        images,
        scanError,
        generalError,
        scanningImageId,
      ];
}

/// StateNotifier that manages invoice capture state and operations.
///
/// Handles:
/// - Loading journey images
/// - Tracking scan status
/// - Managing scan errors
/// - Updating scan status for specific images
class InvoiceCaptureNotifier extends StateNotifier<InvoiceCaptureState> {
  final Logger _logger;
  final String _journeyId;
  final Ref _ref;
  StreamSubscription<List<InvoiceCaptureProcess>>? _imageStreamSubscription;

  /// Creates a new InvoiceCaptureNotifier for the specified journey.
  ///
  /// Automatically loads initial images upon creation.
  ///
  /// Parameters:
  ///   - _journeyId: The ID of the journey to load images from
  ///   - _logger: Logger instance for tracking operations
  ///   - _ref: Riverpod Ref for reading other providers
  ///   - _ref: Reference to the Riverpod provider context
  InvoiceCaptureNotifier(this._journeyId, this._logger, this._ref)
      : super(const InvoiceCaptureState()) {
    _logger.i('InvoiceCaptureNotifier initialized for journeyId: $_journeyId');
    _loadInitialImages();
  }

  /// Loads the initial set of images for this journey.
  ///
  /// Sets up a stream subscription that keeps the state updated with the latest images.
  Future<void> _loadInitialImages() async {
    try {
      _logger.d('Loading initial images for journey $_journeyId');
      final repository = _ref.read(invoiceRepositoryProvider);

      _imageStreamSubscription =
          repository.getInvoiceImagesStream(_journeyId).listen(
        (images) {
          _logger.d('Received ${images.length} images from stream');
          state = state.copyWith(images: images);
        },
        onError: (error, stackTrace) {
          _logger.e('[INVOICE_CAPTURE] Error in image stream:', error: error);
          state = state.copyWith(
            generalError: 'Failed to load images: ${error.toString()}',
          );
        },
      );
    } catch (e) {
      _logger.e('[INVOICE_CAPTURE] Error loading initial images:', error: e);
      state = state.copyWith(
        generalError: 'Failed to load images: ${e.toString()}',
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
      scanningImageId: imageId,
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
      scanningImageId: null,
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

  @override
  void dispose() {
    _logger.d('Disposing InvoiceCaptureNotifier for journeyId: $_journeyId');
    _imageStreamSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for managing invoice capture state for a specific journey.
///
/// This provider creates and maintains a StateNotifier that manages all aspects
/// of the invoice capture process for a given journey ID, including:
/// - Image loading and tracking
/// - OCR scanning status
/// - Error handling
/// - State updates
///
/// Parameters:
///   - journeyId: The ID of the journey to manage invoice capture for
///
/// Usage: `final captureState = ref.watch(invoiceCaptureProvider(journeyId));`
final invoiceCaptureProvider = StateNotifierProvider.autoDispose
    .family<InvoiceCaptureNotifier, InvoiceCaptureState, String>(
  (ref, journeyId) {
    final logger = ref.watch(loggerProvider);
    return InvoiceCaptureNotifier(journeyId, logger, ref);
  },
);
