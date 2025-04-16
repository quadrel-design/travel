import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel/models/journey_image_info.dart';
import 'package:travel/providers/logging_provider.dart'; // Import the logger provider

// 1. Define the State class
class GalleryDetailState extends Equatable {
  final List<JourneyImageInfo> images;
  final Map<String, String?> scanError; // Map image ID to error message
  // Add signed URL state
  final List<String?> signedUrls;
  final bool isLoadingSignedUrls;
  final String? signedUrlError;

  const GalleryDetailState({
    required this.images,
    this.scanError = const {},
    // Initialize signed URL state
    this.signedUrls = const [],
    this.isLoadingSignedUrls = true,
    this.signedUrlError,
  });

  GalleryDetailState copyWith({
    List<JourneyImageInfo>? images,
    Map<String, String?>? scanError,
    List<String?>? signedUrls,
    bool? isLoadingSignedUrls,
    String? signedUrlError,
    bool clearSignedUrlError = false, // Helper flag to clear error
  }) {
    return GalleryDetailState(
      images: images ?? this.images,
      scanError: scanError ?? this.scanError,
      signedUrls: signedUrls ?? this.signedUrls,
      isLoadingSignedUrls: isLoadingSignedUrls ?? this.isLoadingSignedUrls,
      signedUrlError: clearSignedUrlError ? null : signedUrlError ?? this.signedUrlError,
    );
  }

  @override
  List<Object?> get props => [
        images,
        scanError,
        signedUrls,
        isLoadingSignedUrls,
        signedUrlError,
      ];
}

// 2. Define the StateNotifier
class GalleryDetailNotifier extends StateNotifier<GalleryDetailState> {
  final Logger _logger;
  final List<String> _imageIds;
  String? _channelName;
  final SupabaseClient _supabaseClient;
  final Ref _ref;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  GalleryDetailNotifier(List<JourneyImageInfo> initialImages, this._logger, this._supabaseClient, this._ref)
      : _imageIds = initialImages.map((img) => img.id).where((id) => id.isNotEmpty).toList(),
        // Initialize state with empty signed URLs initially
        super(GalleryDetailState(images: List.from(initialImages), signedUrls: List.filled(initialImages.length, null))) {
    _logger.i('GalleryDetailNotifier initialized for ${_imageIds.length} images.');
    // Fetch signed URLs immediately
    _fetchSignedUrls();
    // Setup Realtime only if there are IDs
    if (_imageIds.isNotEmpty) {
      _setupRealtimeListener();
    }
  }

  // --- Signed URL Logic (Moved from Widget) ---
  String? _extractPath(String url) {
    try {
      final uri = Uri.parse(url);
      final bucketName = 'journey_images';
      final pathStartIndex = uri.path.indexOf(bucketName) + bucketName.length + 1;
      if (pathStartIndex <= bucketName.length) return null;
      return uri.path.substring(pathStartIndex);
    } catch (e) {
      _logger.e('Failed to parse path from URL: $url', error: e);
      return null;
    }
  }
  Future<String> _generateSignedUrl(String imagePath) async {
    try {
      final result = await _supabaseClient.storage
          .from('journey_images')
          .createSignedUrl(imagePath, 3600); // 1 hour expiry
      return result;
    } catch (e) {
      _logger.e('Error generating signed URL for $imagePath', error: e);
      rethrow;
    }
  }

  Future<void> _fetchSignedUrls() async {
     // Use state's image list
     final imageList = state.images;
     final imageCount = imageList.length;

     _logger.d('Fetching signed URLs for $imageCount images within provider.');
     // Update state to indicate loading
     state = state.copyWith(isLoadingSignedUrls: true, signedUrlError: null, clearSignedUrlError: true);

     List<String?> results = List.filled(imageCount, null);
     bool hadError = false;

     for (int i = 0; i < imageCount; i++) {
        final imageInfo = imageList[i];
        final path = _extractPath(imageInfo.url);
        if (path == null) {
          _logger.w('Could not extract path for ${imageInfo.url}');
          hadError = true;
          continue;
        }
        try {
          final signedUrl = await _generateSignedUrl(path);
          results[i] = signedUrl;
        } catch (e) {
          hadError = true;
        }
      }

     // Update state with results
     state = state.copyWith(
       signedUrls: results,
       isLoadingSignedUrls: false,
       signedUrlError: hadError ? 'Some images could not be loaded.' : null, // TODO: Localize
       clearSignedUrlError: !hadError, // Clear error only if successful
     );
     _logger.d('Finished fetching signed URLs within provider.');
   }
  // --- End Signed URL Logic ---

  void _setupRealtimeListener() {
    if (_imageIds.isEmpty) {
      _logger.w('Skipping Realtime setup: No image IDs provided.');
      return;
    }
    _channelName = 'public:journey_images:detail_view_${DateTime.now().millisecondsSinceEpoch}_${hashCode}';
    _logger.d('Setting up Realtime listener for journey_images table using IN filter for ${_imageIds.length} IDs...');
    _logger.d('Subscribing to channel: $_channelName');

    _subscription = _supabaseClient
        .from('journey_images')
        .stream(primaryKey: ['id'])
        .inFilter('id', _imageIds)
        .listen(
          (List<Map<String, dynamic>> data) {
             _logger.d('Realtime update received on channel $_channelName: ${data.length} item(s)');
             // Use PostgresChangePayload for better structure if needed/possible
             // For simplicity, just process the raw list for now
             for (var change in data) {
               _handleRealtimeUpdate(change);
             }
          },
          onError: (error) {
            _logger.e('Realtime listener error on channel $_channelName', error: error);
             state = state.copyWith(scanError: {...state.scanError, 'realtime_error': error.toString()});
          },
          onDone: () {
            _logger.w('Realtime listener on channel $_channelName closed.');
          },
        );

     // Subscribe callback (Optional but useful for knowing when ready)
     _supabaseClient.channel(_channelName!).subscribe((status, [error]) {
        _logger.i('GalleryDetailNotifier Realtime subscription status for $_channelName: $status');
        if (status == RealtimeSubscribeStatus.subscribed) {
            _logger.i('GalleryDetailNotifier successfully subscribed to $_channelName.');
        } else if (status == RealtimeSubscribeStatus.closed || status == RealtimeSubscribeStatus.channelError) {
             _logger.e('Realtime subscription failed/closed for $_channelName', error: error);
             // Consider setting an error state
             state = state.copyWith(scanError: {...state.scanError, 'realtime_error': 'Subscription closed/failed: ${error?.toString()}'});
        } else if (status == RealtimeSubscribeStatus.timedOut) {
             _logger.w('Realtime subscription timed out for $_channelName');
             state = state.copyWith(scanError: {...state.scanError, 'realtime_error': 'Subscription timed out'});
        }
     });
  }

  void _handleRealtimeUpdate(Map<String, dynamic> newRowData) {
      final updatedImageInfo = JourneyImageInfo.fromMap(newRowData);
      _logger.d('Processing update for image ID: ${updatedImageInfo.id}, hasPotentialText: ${updatedImageInfo.hasPotentialText}, Amount: ${updatedImageInfo.detectedTotalAmount}, Currency: ${updatedImageInfo.detectedCurrency}');

      final index = state.images.indexWhere((img) => img.id == updatedImageInfo.id);
      if (index != -1) {
        _logger.d('Updating state for image index: $index with new data.');
        final updatedImages = List<JourneyImageInfo>.from(state.images);
        updatedImages[index] = updatedImageInfo; // Replace with the new data

        // Create a new map for scanError, removing the error for the updated image if it exists
        final newScanError = Map<String, String?>.from(state.scanError);
        newScanError.remove(updatedImageInfo.id);

        state = state.copyWith(
          images: updatedImages,
          scanError: newScanError,
          // Keep signed URL state as is, only data changed
        );
      } else {
         _logger.w('Received realtime update for unknown image ID: ${updatedImageInfo.id}');
      }
  }

  // Method to reset scan status and mark as initiated
  void resetScanStatus(String imageId) {
    _logger.d('Resetting scan status AND marking as initiated for image ID: $imageId');
    final index = state.images.indexWhere((img) => img.id == imageId);
    if (index != -1) {
      final updatedImages = List<JourneyImageInfo>.from(state.images);
      // Mark as initiated, clear previous results
      updatedImages[index] = updatedImages[index].copyWith(
        scanInitiated: true,
        hasPotentialText: null,
        detectedText: null,
        detectedTotalAmount: null,
        detectedCurrency: null,
        isInvoiceGuess: false,
        lastProcessedAt: null,
      );

      // Clear any specific error for this image
      final newScanError = Map<String, String?>.from(state.scanError);
      newScanError.remove(imageId);

      state = state.copyWith(images: updatedImages, scanError: newScanError);
    } else {
      _logger.w('Attempted to reset scan status for unknown image ID: $imageId');
    }
  }

  // Method to explicitly set an error state for a scan
  void setScanError(String imageId, String error) {
    _logger.e('Setting scan error for image ID $imageId: $error');
     final index = state.images.indexWhere((img) => img.id == imageId);
     if (index != -1) {
      final updatedImages = List<JourneyImageInfo>.from(state.images);
      // Reset scan initiated flag on error using the updated copyWith
      updatedImages[index] = updatedImages[index].copyWith(scanInitiated: false);

      state = state.copyWith(
         images: updatedImages, // Include the updated image list
         scanError: { ...state.scanError, imageId: error }
       );
     } else {
       _logger.w('Attempted to set scan error for unknown image ID: $imageId');
     }
  }

  // Method to handle deletion update
  void handleDeletion(String deletedImageId) {
    _logger.i('Handling deletion in provider for image ID: $deletedImageId');
    final currentImages = List<JourneyImageInfo>.from(state.images);
    final initialLength = currentImages.length;
    currentImages.removeWhere((img) => img.id == deletedImageId);

    if (currentImages.length < initialLength) {
        _logger.d('Image $deletedImageId removed from provider state.');
        // Also remove from scanError map
        final newScanError = Map<String, String?>.from(state.scanError);
        newScanError.remove(deletedImageId);
        // Refetch signed URLs for the smaller list
        state = state.copyWith(images: currentImages, scanError: newScanError);
        _fetchSignedUrls(); // Refetch URLs for the remaining images
    } else {
        _logger.w('Attempted to handle deletion for ID $deletedImageId, but it was not found in state.');
    }
}

  @override
  void dispose() {
    _logger.d('Disposing GalleryDetailNotifier. Unsubscribing from channel: $_channelName');
    _subscription?.cancel();
    if (_channelName != null) {
      _supabaseClient.removeChannel(_supabaseClient.channel(_channelName!));
    }
    super.dispose();
  }
}


// 3. Define the StateNotifierProvider.family
final galleryDetailProvider = StateNotifierProvider.autoDispose
    .family<GalleryDetailNotifier, GalleryDetailState, List<JourneyImageInfo>>((ref, initialImages) {
  final logger = ref.watch(loggerProvider);
  final supabaseClient = Supabase.instance.client;
  return GalleryDetailNotifier(initialImages, logger, supabaseClient, ref);
});