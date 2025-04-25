import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:logger/logger.dart';
import 'package:travel/models/journey_image_info.dart';
import 'package:travel/providers/logging_provider.dart'; // Import the logger provider
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/repositories/journey_repository.dart'; // Import the journey repository
// import '../repositories/auth_repository.dart'; // Remove unused import

// 1. Define the State class
class GalleryDetailState extends Equatable {
  final List<JourneyImageInfo> images;
  final Map<String, String?> scanError;
  final String? generalError;
  final String? scanningImageId;

  const GalleryDetailState({
    this.images = const [],
    this.scanError = const {},
    this.generalError,
    this.scanningImageId,
  });

  GalleryDetailState copyWith({
    List<JourneyImageInfo>? images,
    Map<String, String?>? scanError,
    String? generalError,
    String? scanningImageId,
    bool clearGeneralError = false,
    bool clearScanningImageId = false,
  }) {
    return GalleryDetailState(
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
class GalleryDetailNotifier extends StateNotifier<GalleryDetailState> {
  final Logger _logger;
  final String _journeyId;
  final Ref _ref;
  StreamSubscription<List<JourneyImageInfo>>? _imageStreamSubscription;

  GalleryDetailNotifier(this._journeyId, this._logger, this._ref)
      : super(const GalleryDetailState()) {
    _logger.i('GalleryDetailNotifier initialized for journeyId: $_journeyId');
    _loadInitialImages();
  }

  Future<void> _loadInitialImages() async {
    try {
      _logger.d('Loading initial images for journey $_journeyId');
      // Get the repository from the provider
      final repository = _ref.read(journeyRepositoryProvider);

      // Listen to the image stream
      _imageStreamSubscription =
          repository.getJourneyImagesStream(_journeyId).listen(
        (images) {
          _logger.d('Received ${images.length} images from stream');
          state = state.copyWith(images: images);
        },
        onError: (error, stackTrace) {
          _logger.e('Error in image stream',
              error: error, stackTrace: stackTrace);
          state = state.copyWith(
            generalError: 'Failed to load images: ${error.toString()}',
          );
        },
      );
    } catch (e, stackTrace) {
      _logger.e('Error loading initial images',
          error: e, stackTrace: stackTrace);
      state = state.copyWith(
        generalError: 'Failed to load images: ${e.toString()}',
      );
    }
  }

  void initiateScan(String imageId) {
    _logger.d('Initiating scan for image ID: $imageId');
    final index = state.images.indexWhere((img) => img.id == imageId);
    if (index != -1) {
      final updatedImages = List<JourneyImageInfo>.from(state.images);
      updatedImages[index] = updatedImages[index].copyWith(
        setHasPotentialTextNull: true,
        setDetectedTextNull: true,
        setDetectedTotalAmountNull: true,
        setDetectedCurrencyNull: true,
        setLastProcessedAtNull: true,
        isInvoiceGuess: false,
      );
      final newScanError = Map<String, String?>.from(state.scanError);
      newScanError.remove(imageId);
      state = state.copyWith(
        images: updatedImages,
        scanError: newScanError,
        scanningImageId: imageId,
      );
    } else {
      _logger.w('Attempted to initiate scan for unknown image ID: $imageId');
    }
  }

  void setScanError(String imageId, String error) {
    _logger.e('Setting scan error for image ID $imageId: $error');
    final index = state.images.indexWhere((img) => img.id == imageId);
    if (index != -1) {
      final bool clearScanning = state.scanningImageId == imageId;
      if (clearScanning) {
        _logger.d(
            'Scan error occurred for the image currently being scanned ($imageId), clearing scanning state.');
      }
      state = state.copyWith(
        scanError: {...state.scanError, imageId: error},
        clearScanningImageId: clearScanning,
      );
    } else {
      _logger.w('Attempted to set scan error for unknown image ID: $imageId');
    }
  }

  void handleDeletion(String deletedImageId) {
    _logger.i('Handling deletion in provider for image ID: $deletedImageId');
    // Just clear any local scan error associated with the deleted image
    final newScanError = Map<String, String?>.from(state.scanError);
    if (newScanError.containsKey(deletedImageId)) {
      newScanError.remove(deletedImageId);
      state = state.copyWith(scanError: newScanError);
    }
  }

  void clearGeneralError() {
    _logger.d('Clearing general error state.');
    if (state.generalError != null) {
      state = state.copyWith(clearGeneralError: true);
    }
  }

  @override
  void dispose() {
    _logger.d('Disposing GalleryDetailNotifier for journeyId: $_journeyId');
    _imageStreamSubscription?.cancel();
    super.dispose();
  }
}

// Provider definition (updated)
final galleryDetailProvider = StateNotifierProvider.autoDispose
    .family<GalleryDetailNotifier, GalleryDetailState, String>(
        (ref, journeyId) {
  final logger = ref.watch(loggerProvider);
  return GalleryDetailNotifier(journeyId, logger, ref);
});
