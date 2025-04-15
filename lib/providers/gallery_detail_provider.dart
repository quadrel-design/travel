import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel/models/journey_image_info.dart';
import 'package:travel/providers/logging_provider.dart'; // Import the logger provider

// 1. Define the State class
class GalleryDetailState {
  final List<JourneyImageInfo> images;
  final Set<String> scanInitiatedInSession; // Track scans started in this session
  final bool isLoading;
  final String? error;

  GalleryDetailState({
    required this.images,
    this.scanInitiatedInSession = const {},
    this.isLoading = false,
    this.error,
  });

  GalleryDetailState copyWith({
    List<JourneyImageInfo>? images,
    Set<String>? scanInitiatedInSession,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return GalleryDetailState(
      images: images ?? this.images,
      scanInitiatedInSession: scanInitiatedInSession ?? this.scanInitiatedInSession,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// 2. Define the StateNotifier
class GalleryDetailNotifier extends StateNotifier<GalleryDetailState> {
  final Logger _logger;
  RealtimeChannel? _imagesChannel;
  final List<String> _imageIds;
  String? _channelName;

  GalleryDetailNotifier(List<JourneyImageInfo> initialImages, this._logger)
      : _imageIds = initialImages.map((img) => img.id).where((id) => id.isNotEmpty).toList(),
        super(GalleryDetailState(images: List.from(initialImages))) {
    _logger.i('GalleryDetailNotifier initialized for ${_imageIds.length} images.');
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    if (_imageIds.isEmpty) {
      _logger.w('No valid image IDs provided to GalleryDetailNotifier, skipping Realtime listener setup.');
      return;
    }

    final client = Supabase.instance.client;
    // Use an 'in' filter for all relevant IDs
    final idFilter = PostgresChangeFilter(
          type: PostgresChangeFilterType.inFilter,
          column: 'id',
          value: _imageIds,
        );

    _logger.d('Setting up Realtime listener for journey_images table using IN filter for ${_imageIds.length} IDs...');

    // Store the channel name
    _channelName = 'public:journey_images:detail_view_${DateTime.now().millisecondsSinceEpoch}_${_imageIds.hashCode}';
    _logger.d('Subscribing to channel: $_channelName');

    _imagesChannel = client
        .channel(_channelName!) // Use the stored name
        .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'journey_images',
            filter: idFilter, // Apply initial filter
            callback: (payload) {
              _logger.d('Realtime update received on channel $_channelName: ${payload.toString()}');
              final updatedRecord = payload.newRecord;
              // Ensure the received ID is one we are tracking
              if (updatedRecord != null && _imageIds.contains(updatedRecord['id'])) {
                 _handleRealtimeUpdate(updatedRecord);
              } else {
                 _logger.d('Realtime update ignored (ID not in list or no new record). Record ID: ${updatedRecord?['id']}');
              }
            })
        .subscribe((status, [dynamic error]) async { // Accept optional error argument
      _logger.i('GalleryDetailNotifier Realtime subscription status for $_channelName: $status');
      if (status == RealtimeSubscribeStatus.subscribed) {
        _logger.i('GalleryDetailNotifier successfully subscribed to $_channelName.');
      } else if (status == RealtimeSubscribeStatus.closed || status == RealtimeSubscribeStatus.timedOut || status == RealtimeSubscribeStatus.channelError) { // Check for various error/closed states
        _logger.e('GalleryDetailNotifier Realtime subscription closed or failed for $_channelName. Status: $status', error: error);
        // Update state only if notifier is still mounted
         if(mounted) {
             state = state.copyWith(error: 'Realtime connection lost ($status)');
         }
      }
    });
  }

   void _handleRealtimeUpdate(Map<String, dynamic> updatedRecord) {
    if (!mounted) return; // Check if notifier is still mounted

    try {
      final updatedImageInfo = JourneyImageInfo.fromMap(updatedRecord);
       _logger.d('Processing update for image ID: ${updatedImageInfo.id}, hasPotentialText: ${updatedImageInfo.hasPotentialText}, Amount: ${updatedImageInfo.detectedTotalAmount}, Currency: ${updatedImageInfo.detectedCurrency}');

      final currentImages = List<JourneyImageInfo>.from(state.images); // Create mutable copy
      final index = currentImages.indexWhere((img) => img.id == updatedImageInfo.id);

      if (index != -1) {
         _logger.i('Updating state for image index: $index with new data.');
         // Preserve localPath if it exists - Important if showing images picked locally but not uploaded yet
         final existingLocalPath = currentImages[index].localPath;
         currentImages[index] = JourneyImageInfo(
             id: updatedImageInfo.id,
             url: updatedImageInfo.url, // Make sure URL is updated if it changes
             hasPotentialText: updatedImageInfo.hasPotentialText,
             detectedText: updatedImageInfo.detectedText,
             isInvoiceGuess: updatedImageInfo.isInvoiceGuess,
             detectedTotalAmount: updatedImageInfo.detectedTotalAmount,
             detectedCurrency: updatedImageInfo.detectedCurrency,
             localPath: existingLocalPath // Keep localPath
         );
         // Update state immutably
         // NOTE: We do NOT modify scanInitiatedInSession here. That's handled by resetScanStatus.
         // We only update the image data itself.
         state = state.copyWith(images: currentImages, clearError: true);
      } else {
         _logger.w('Received update for image ID ${updatedImageInfo.id} not found in current state.');
      }
    } catch (e, stackTrace) {
       _logger.e('Error processing Realtime update', error: e, stackTrace: stackTrace);
       state = state.copyWith(error: 'Failed to process image update');
    }
   }

   // Method to reset status before scan
   void resetScanStatus(String imageId) {
     if (!mounted) return;
     _logger.d('Resetting scan status AND marking as initiated for image ID: $imageId');
     final currentImages = List<JourneyImageInfo>.from(state.images);
     final currentInitiated = Set<String>.from(state.scanInitiatedInSession);
     final index = currentImages.indexWhere((img) => img.id == imageId);
     if (index != -1) {
       final img = currentImages[index];
       currentImages[index] = JourneyImageInfo(
          id: img.id,
          url: img.url,
          hasPotentialText: null, // Reset persistent status
          detectedText: null,
          isInvoiceGuess: img.isInvoiceGuess,
          detectedTotalAmount: null,
          detectedCurrency: null,
          localPath: img.localPath);
       currentInitiated.add(imageId); // Mark as initiated in this session
       state = state.copyWith(images: currentImages, scanInitiatedInSession: currentInitiated, clearError: true);
     } else {
        _logger.w('Attempted to reset status for image ID $imageId not found in state.');
     }
   }

   // Method to handle deletion update from parent widget
   void handleDeletion(String imageId) {
      if (!mounted) return;
      _logger.d('Handling deletion for image ID: $imageId');
      final currentImages = List<JourneyImageInfo>.from(state.images);
      final currentInitiated = Set<String>.from(state.scanInitiatedInSession);
      final originalLength = currentImages.length;

      // Remove image from the state list
      currentImages.removeWhere((img) => img.id == imageId);
      // Remove from session tracking set
      currentInitiated.remove(imageId);

      if (currentImages.length < originalLength) {
          _logger.i('Removed image ID $imageId from notifier state.');
          _imageIds.remove(imageId);
          // Update state with the reduced list and updated set
          state = state.copyWith(images: currentImages, scanInitiatedInSession: currentInitiated, clearError: true);

          if (_imageIds.isEmpty && _imagesChannel != null) {
             _logger.w('Image list is now empty, unsubscribing from Realtime channel.');
             _imagesChannel?.unsubscribe();
             _imagesChannel = null;
          }

      } else {
           _logger.w('Attempted to delete image ID $imageId not found in notifier state.');
      }
   }


  @override
  void dispose() {
    _logger.i('Disposing GalleryDetailNotifier and unsubscribing from channel ${_channelName ?? 'N/A'}...');
    _imagesChannel?.unsubscribe();
    super.dispose();
  }
}


// 3. Define the StateNotifierProvider.family
// Remove .autoDispose for testing
final galleryDetailProvider = StateNotifierProvider
    .family<GalleryDetailNotifier, GalleryDetailState, List<JourneyImageInfo>>(
        (ref, initialImages) {
  final logger = ref.watch(loggerProvider);
  return GalleryDetailNotifier(initialImages, logger);
});