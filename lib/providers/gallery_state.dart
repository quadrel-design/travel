import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:travel/repositories/journey_repository.dart';
import 'package:riverpod/riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:travel/providers/repository_providers.dart';

part "gallery_state.freezed.dart"; // Use double quotes for the part file

@freezed
class GalleryState with _$GalleryState {
  const factory GalleryState({
    @Default([]) List<String> imageUrls,
    @Default(true) bool isLoading,
    @Default(false) bool isUploading,
    @Default(false) bool isLoadingMore,
    @Default(true) bool canLoadMore, // Assume we can load more initially
    String? error,
    @Default(0) int currentPage, // Track pagination
  }) = _GalleryState;
}

class GalleryNotifier extends StateNotifier<GalleryState> {
  final JourneyRepository _journeyRepository;
  final String _journeyId;
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  static const int _itemsPerPage = 15;

  GalleryNotifier(this._journeyRepository, this._journeyId)
    : super(const GalleryState()) {
      loadInitialImages();
    }

  Future<void> loadInitialImages() async {
    // Reset state for initial load or refresh
    state = state.copyWith(isLoading: true, currentPage: 0, canLoadMore: true, error: null);
    try {
      // Fetch the first page
      final urls = await _journeyRepository.fetchJourneyImages(
        _journeyId,
        limit: _itemsPerPage,
        offset: 0,
      );
      state = state.copyWith(
        imageUrls: urls,
        isLoading: false,
        currentPage: 1, // We have loaded page 1
        canLoadMore: urls.length == _itemsPerPage, // Can load more if we got a full page
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to load images', isLoading: false);
    }
  }

  Future<void> loadMoreImages() async {
    // Prevent loading more if already loading, or if no more pages
    if (state.isLoadingMore || !state.canLoadMore) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final offset = state.currentPage * _itemsPerPage;
      final newUrls = await _journeyRepository.fetchJourneyImages(
        _journeyId,
        limit: _itemsPerPage,
        offset: offset,
      );
      state = state.copyWith(
        imageUrls: [ ...state.imageUrls, ...newUrls ], // Append new URLs
        isLoadingMore: false,
        currentPage: state.currentPage + 1,
        canLoadMore: newUrls.length == _itemsPerPage, // Check if last page was full
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to load more images', isLoadingMore: false);
      // Optionally show error via SnackBar or keep it in state
    }
  }

  Future<void> addImageReferenceToState(String imageUrl) async {
    state = state.copyWith(imageUrls: [imageUrl, ...state.imageUrls]);
  }

  Future<Map<String, List<String>>> uploadImages() async {
    if (state.isUploading) return {'success': [], 'errors': []};

    state = state.copyWith(isUploading: true);
    List<String> successfulUrls = [];
    List<String> errorMessages = [];

    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isEmpty) {
         state = state.copyWith(isUploading: false);
         return {'success': [], 'errors': []};
      }

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
         throw Exception("User not logged in during image upload.");
      }

      for (final pickedFile in pickedFiles) {
         try {
            final bytes = await pickedFile.readAsBytes();
            final fileExt = p.extension(pickedFile.name);
            final fileName = '${const Uuid().v4()}$fileExt';
            final filePath = '$userId/$_journeyId/$fileName';

            await _supabase.storage
              .from('journey_images')
              .uploadBinary(
                  filePath,
                  bytes,
                  fileOptions: FileOptions(contentType: pickedFile.mimeType)
              );
              
            final imageUrl = _supabase.storage
              .from('journey_images')
              .getPublicUrl(filePath);

            await _journeyRepository.addImageReference(_journeyId, imageUrl);
            successfulUrls.add(imageUrl);
            addImageReferenceToState(imageUrl); 

         } catch (e) {
           errorMessages.add('Failed to upload ${pickedFile.name}: ${e.toString()}'); 
         }
      }

    } catch (e) {
       errorMessages.add('Error processing images: ${e.toString()}');
    } finally {
       state = state.copyWith(isUploading: false);
    }
    return {'success': successfulUrls, 'errors': errorMessages};
  }

  Future<void> deleteImage(String imageUrl) async {
     // 1. Optimistically remove from UI
     final currentUrls = List<String>.from(state.imageUrls);
     final originalIndex = currentUrls.indexOf(imageUrl); // Store index for potential revert
     if (originalIndex == -1) return; // Image not found in current state
     
     currentUrls.removeAt(originalIndex);
     state = state.copyWith(imageUrls: currentUrls);
     
     try {
       // 2. Call repository to delete from DB and storage
       await _journeyRepository.deleteImage(_journeyId, imageUrl);
     } catch (e) {
       // 3. Revert UI change if deletion failed
       // Add back at the original position to maintain order
       currentUrls.insert(originalIndex, imageUrl); 
       state = state.copyWith(imageUrls: currentUrls, error: 'Failed to delete image'); // Add error state
       // TODO: Show error message via SnackBar from UI?
     }
  }
}

// Define the StateNotifierProvider
// It takes the journeyId as an argument using .family
final galleryNotifierProvider = StateNotifierProvider.family<GalleryNotifier, GalleryState, String>((ref, journeyId) {
  final journeyRepository = ref.watch(journeyRepositoryProvider); // Read the repo provider
  return GalleryNotifier(journeyRepository, journeyId); 
}); 