import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:logger/logger.dart';
import 'package:travel/models/journey_image_info.dart';
import 'package:travel/providers/logging_provider.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/repositories/journey_repository.dart';

// 1. Define the State class
class InvoiceCaptureState extends Equatable {
  final List<JourneyImageInfo> images;
  final Map<String, String?> scanError;
  final String? generalError;
  final String? scanningImageId;

  const InvoiceCaptureState({
    this.images = const [],
    this.scanError = const {},
    this.generalError,
    this.scanningImageId,
  });

  InvoiceCaptureState copyWith({
    List<JourneyImageInfo>? images,
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

// 2. Define the StateNotifier
class InvoiceCaptureNotifier extends StateNotifier<InvoiceCaptureState> {
  final Logger _logger;
  final String _journeyId;
  final Ref _ref;
  StreamSubscription<List<JourneyImageInfo>>? _imageStreamSubscription;

  InvoiceCaptureNotifier(this._journeyId, this._logger, this._ref)
      : super(const InvoiceCaptureState()) {
    _logger.i('InvoiceCaptureNotifier initialized for journeyId: $_journeyId');
    _loadInitialImages();
  }

  Future<void> _loadInitialImages() async {
    try {
      _logger.d('Loading initial images for journey $_journeyId');
      final repository = _ref.read(journeyRepositoryProvider);

      _imageStreamSubscription =
          repository.getJourneyImagesStream(_journeyId).listen(
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
    } catch (e, stackTrace) {
      _logger.e('[INVOICE_CAPTURE] Error loading initial images:', error: e);
      state = state.copyWith(
        generalError: 'Failed to load images: ${e.toString()}',
      );
    }
  }

  void initiateScan(String imageId) {
    _logger.d('Initiating scan for image ID: $imageId');
    state = state.copyWith(
      scanningImageId: imageId,
      scanError: {},
    );
  }

  void setScanError(String imageId, String error) {
    _logger.w('Setting scan error for image ID $imageId: $error');
    state = state.copyWith(
      scanError: {...state.scanError, imageId: error},
      scanningImageId: null,
    );
  }

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

// 3. Define the Provider
final invoiceCaptureProvider = StateNotifierProvider.autoDispose
    .family<InvoiceCaptureNotifier, InvoiceCaptureState, String>(
  (ref, journeyId) {
    final logger = ref.watch(loggerProvider);
    return InvoiceCaptureNotifier(journeyId, logger, ref);
  },
);
