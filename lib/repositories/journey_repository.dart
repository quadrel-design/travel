import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/journey.dart';
import 'dart:typed_data'; // For Uint8List
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart'; // Import Logger
import 'repository_exceptions.dart'; // Import custom exceptions
import '../models/journey_image_info.dart';

class JourneyRepository {
  // --- Dependency Injection ---
  final SupabaseClient _supabaseClient;
  final Logger _logger;

  JourneyRepository(this._supabaseClient, this._logger);
  // --- End Dependency Injection ---

  // Helper to get current user ID, throws NotAuthenticatedException if null
  String _getCurrentUserId() {
    final userId = _supabaseClient.auth.currentUser?.id;
    if (userId == null) {
      _logger.e('User ID is null, operation requires authentication.');
      throw NotAuthenticatedException('User must be logged in to perform this operation.');
    }
    return userId;
  }

  // Helper to extract storage path from URL
  String? _extractStoragePath(String url) {
    try {
      final uri = Uri.parse(url);
      final bucketName = 'journey_images'; // Assuming this is your bucket name
      final pathSegments = uri.pathSegments;
      // Find the segment after 'object/public' and the bucket name
      final bucketIndex = pathSegments.indexOf(bucketName);
      if (bucketIndex == -1 || bucketIndex + 1 >= pathSegments.length) {
        _logger.w('Could not find bucket "$bucketName" or path segments after it in URL: $url');
        return null;
      }
      // Join the segments after the bucket name
      return pathSegments.sublist(bucketIndex + 1).join('/');
    } catch (e) {
      _logger.e('Failed to parse path from URL: $url', error: e);
      return null;
    }
  }

  Future<List<Journey>> getJourneys() async {
    try {
      final userId = _getCurrentUserId();
      _logger.d('Fetching journeys for user: $userId');
      final data = await _supabaseClient
          .from('journeys')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      _logger.d('Fetched ${data.length} journeys from DB.');
      final journeys = data.map((item) => Journey.fromJson(item)).toList();
      return journeys;
    } on PostgrestException catch (e, stackTrace) {
      _logger.e('PostgrestException fetching journeys', error: e, stackTrace: stackTrace);
      throw DatabaseFetchException('Failed to fetch journeys: ${e.message}', e, stackTrace);
    } on NotAuthenticatedException { // Re-throw specific exception
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error fetching journeys', error: e, stackTrace: stackTrace);
      throw DatabaseFetchException('An unexpected error occurred while fetching journeys.', e, stackTrace);
    }
  }

  Future<void> createJourney(String title) async {
    try {
      final userId = _getCurrentUserId();
      _logger.d('Creating journey "$title" for user: $userId');
      await _supabaseClient.from('journeys').insert({
        'user_id': userId,
        'title': title,
      });
      _logger.i('Successfully created journey "$title".');
    } on PostgrestException catch (e, stackTrace) {
      _logger.e('PostgrestException creating journey "$title"', error: e, stackTrace: stackTrace);
      throw DatabaseOperationException('Failed to create journey: ${e.message}', e, stackTrace);
    } on NotAuthenticatedException { // Re-throw specific exception
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error creating journey "$title"', error: e, stackTrace: stackTrace);
      throw DatabaseOperationException('An unexpected error occurred while creating the journey.', e, stackTrace);
    }
  }

  Future<void> updateJourney(Journey journey) async {
    try {
      final userId = _getCurrentUserId(); // Ensure user is logged in
      _logger.d('Updating journey ID: ${journey.id}');
      await _supabaseClient
          .from('journeys')
          .update(journey.toJson()) // Use the model's toJson
          .eq('id', journey.id)
          .eq('user_id', userId); // Ensure user owns the journey
      _logger.i('Successfully updated journey ID: ${journey.id}');
    } on PostgrestException catch (e, stackTrace) {
      _logger.e('PostgrestException updating journey ${journey.id}', error: e, stackTrace: stackTrace);
      throw DatabaseOperationException('Failed to update journey: ${e.message}', e, stackTrace);
    } on NotAuthenticatedException { // Re-throw specific exception
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error updating journey ${journey.id}', error: e, stackTrace: stackTrace);
      throw DatabaseOperationException('An unexpected error occurred while updating the journey.', e, stackTrace);
    }
  }

   Future<void> deleteJourney(String journeyId) async {
    try {
      final userId = _getCurrentUserId();
      _logger.d('Attempting to delete journey ID: $journeyId for user: $userId');

      // 1. Delete associated images from storage (optional, based on RLS policies)
      //    If RLS handles cascade deletes in storage, this might not be strictly needed here,
      //    but explicit deletion can be safer.
      final storagePath = '$userId/$journeyId';
      _logger.d('Listing files in storage path: $storagePath for deletion.');
      final fileList = await _supabaseClient.storage.from('journey_images').list(path: storagePath);
      final filePathsToDelete = fileList.map((file) => '$storagePath/${file.name}').toList();

      if (filePathsToDelete.isNotEmpty) {
         _logger.d('Deleting ${filePathsToDelete.length} files from storage...');
         await _supabaseClient.storage.from('journey_images').remove(filePathsToDelete);
         _logger.d('Storage files deleted.');
      } else {
         _logger.d('No files found in storage path $storagePath to delete.');
      }

      // 2. Delete the journey record from the database
      _logger.d('Deleting journey record ID: $journeyId from database.');
      await _supabaseClient.from('journeys').delete().eq('id', journeyId).eq('user_id', userId);

      _logger.i('Successfully deleted journey ID: $journeyId and associated data.');
    } on StorageException catch (e, stackTrace) { // Catch storage specific errors
      _logger.e('StorageException deleting journey content $journeyId', error: e, stackTrace: stackTrace);
      // Decide if this is critical - maybe only log and continue to delete DB record?
      // For now, we'll throw a specific exception.
      throw ImageDeleteException('Failed to delete journey images from storage: ${e.message}', e, stackTrace);
    } on PostgrestException catch (e, stackTrace) {
      _logger.e('PostgrestException deleting journey record $journeyId', error: e, stackTrace: stackTrace);
      throw DatabaseOperationException('Failed to delete journey record: ${e.message}', e, stackTrace);
    } on NotAuthenticatedException { // Re-throw specific exception
       rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error deleting journey $journeyId', error: e, stackTrace: stackTrace);
      throw DatabaseOperationException('An unexpected error occurred while deleting the journey.', e, stackTrace);
    }
  }

  Future<String> uploadJourneyImage(Uint8List imageBytes, String fileName) async {
    final imageRecordId = const Uuid().v4();
    final userId = _getCurrentUserId();
    final fileExt = p.extension(fileName);
    // Store images under journey ID later when context is available
    // For now, maybe store directly under user? Or a temporary location?
    // Let's assume a structure like: userId/imageRecordId.ext for now
    final filePath = '$userId/$imageRecordId$fileExt';
    _logger.d('Attempting to upload image to path: $filePath (Record ID: $imageRecordId)');

    try {
      await _supabaseClient.storage.from('journey_images').uploadBinary(
            filePath,
            imageBytes,
            // Consider adding file options like contentType if available/needed
            // fileOptions: FileOptions(contentType: pickedFile.mimeType)
          );
      final imageUrl = _supabaseClient.storage.from('journey_images').getPublicUrl(filePath);
      _logger.i('Image uploaded successfully to: $imageUrl');

      // Add initial reference to the database
      await addImageReference(imageUrl, id: imageRecordId);

      return imageUrl; // Return the public URL
    } on StorageException catch (e, stackTrace) {
      _logger.e('StorageException during image upload for $filePath', error: e, stackTrace: stackTrace);
      throw ImageUploadException('Storage failed: ${e.message}', e, stackTrace);
    } on AddImageReferenceException { // Let specific exception bubble up
      // Could potentially try to delete the uploaded storage file here if DB insert fails
      _logger.w('Image uploaded to storage ($filePath), but failed to add DB reference. Manual cleanup might be needed.');
      rethrow;
    } on NotAuthenticatedException { // Re-throw specific exception
       rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during image upload for $filePath', error: e, stackTrace: stackTrace);
      throw ImageUploadException('An unexpected error occurred during upload.', e, stackTrace);
    }
  }

  // Method to add just the image reference
  Future<void> addImageReference(String imageUrl, {String? id}) async {
    final imageRecordId = id ?? const Uuid().v4();
    final userId = _getCurrentUserId(); // Ensure user is logged in
    _logger.d('Adding image reference to DB. ID: $imageRecordId, URL: $imageUrl');

    try {
      await _supabaseClient.from('journey_images').insert({
        'id': imageRecordId,
        'user_id': userId,
        'url': imageUrl,
        // Add journey_id later if needed
      });
      _logger.i('Successfully added image reference to DB. ID: $imageRecordId');
    } on PostgrestException catch (e, stackTrace) {
      _logger.e('PostgrestException adding image reference $imageRecordId', error: e, stackTrace: stackTrace);
      throw AddImageReferenceException('Database insert failed: ${e.message}', e, stackTrace);
    } on NotAuthenticatedException { // Re-throw specific exception
       rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error adding image reference $imageRecordId', error: e, stackTrace: stackTrace);
      throw AddImageReferenceException('An unexpected error occurred adding the DB reference.', e, stackTrace);
    }
  }

  // Stream for journey images (Now uses journeyId)
  Stream<List<JourneyImageInfo>> getJourneyImagesStream(String journeyId) {
     _logger.d('Creating stream for journey images for journey ID: $journeyId');
     try {
       final userId = _getCurrentUserId();
       return _supabaseClient
         .from('journey_images')
         .stream(primaryKey: ['id'])
         // .eq('user_id', userId) // Filter by user ID
         .eq('journey_id', journeyId) // Filter by journey ID
         .order('created_at') // Order by creation time
         .map((list) => list.map((map) => JourneyImageInfo.fromMap(map)).toList());
     } on NotAuthenticatedException { // Handle auth error during stream setup
       // Return an empty stream or stream with error?
       _logger.e('Cannot get journey images stream: User not authenticated.');
       // Returning an error stream might be better for the UI to handle
       return Stream.error(NotAuthenticatedException('User must be logged in to view images.'));
     } catch (e, stackTrace) {
        _logger.e('Error setting up journey images stream for journey $journeyId', error: e, stackTrace: stackTrace);
        return Stream.error(DatabaseFetchException('Failed to setup image stream', e, stackTrace));
     }
  }

  Future<void> deleteJourneyImage(String imageUrl) async {
    final imagePath = _extractStoragePath(imageUrl);
    if (imagePath == null) {
       _logger.e('Could not extract storage path from URL, cannot delete: $imageUrl');
       throw ImageDeleteException('Invalid image URL format.');
    }
    _logger.d('Attempting to delete image from storage: $imagePath');

    try {
      // Delete from storage
      await _supabaseClient.storage.from('journey_images').remove([imagePath]);
      _logger.i('Successfully deleted image from storage: $imagePath');

      // Delete from database (using URL as the key here - might be better to use ID if available)
      // This assumes RLS prevents deleting others' images if only URL is known.
      // If an ID is available, using .eq('id', imageId) is generally safer.
      _logger.d('Attempting to delete image reference from DB for URL: $imageUrl');
      await _supabaseClient.from('journey_images').delete().eq('image_url', imageUrl);
      _logger.i('Successfully deleted image reference from DB for URL: $imageUrl');

    } on StorageException catch (e, stackTrace) {
      _logger.e('StorageException deleting image $imagePath', error: e, stackTrace: stackTrace);
      throw ImageDeleteException('Storage delete failed: ${e.message}', e, stackTrace);
    } on PostgrestException catch (e, stackTrace) {
       _logger.e('PostgrestException deleting image reference for $imageUrl', error: e, stackTrace: stackTrace);
       // If storage delete succeeded but DB failed, log warning
       _logger.w('Storage file $imagePath deleted, but failed to delete DB reference for $imageUrl. Manual cleanup might be needed.');
       throw DatabaseOperationException('DB delete failed: ${e.message}', e, stackTrace);
    } catch (e, stackTrace) {
       _logger.e('Unexpected error deleting image $imagePath', error: e, stackTrace: stackTrace);
       throw ImageDeleteException('An unexpected error occurred during deletion.', e, stackTrace);
    }
  }

} 