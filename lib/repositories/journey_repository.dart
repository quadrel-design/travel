import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/journey.dart';
import 'package:logger/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/logging_provider.dart';

// --- Custom Exceptions ---
class JourneyRepositoryException implements Exception {
  final String message;
  final dynamic error;
  JourneyRepositoryException(this.message, [this.error]);
  @override
  String toString() => 'JourneyRepositoryException: $message ${error != null ? "($error)" : ""}';
}
class CouldNotFetchJourneys extends JourneyRepositoryException {
  CouldNotFetchJourneys([dynamic error]) : super('Could not fetch journeys', error);
}
class CouldNotAddJourney extends JourneyRepositoryException {
   CouldNotAddJourney([dynamic error]) : super('Could not add journey', error);
}
class CouldNotDeleteJourney extends JourneyRepositoryException {
   CouldNotDeleteJourney([dynamic error]) : super('Could not delete journey', error);
}
class CouldNotFetchJourneyImages extends JourneyRepositoryException {
   CouldNotFetchJourneyImages([dynamic error]) : super('Could not fetch journey images', error);
}
class CouldNotAddImageReference extends JourneyRepositoryException {
   CouldNotAddImageReference([dynamic error]) : super('Could not add image reference to DB', error);
}
// Add Exception for Image Deletion
class CouldNotDeleteImage extends JourneyRepositoryException {
   CouldNotDeleteImage([dynamic error]) : super('Could not delete image', error);
}
// --- End Custom Exceptions ---

class JourneyRepository {
   final SupabaseClient _client = Supabase.instance.client;
   final Logger _logger = ProviderContainer().read(loggerProvider);

  Future<List<Journey>> fetchUserJourneys(String userId) async {
    try {
      final response = await _client
          .from('journeys')
          .select()
          .eq('user_id', userId)
          .order('start_date', ascending: false);
      
      // TODO: Add proper error checking based on Supabase response structure if needed
      return response.map((data) => Journey.fromJson(data)).toList();
    } catch (e) {
      _logger.e('Failed to fetch journeys for user $userId', error: e);
      throw CouldNotFetchJourneys(e);
    }
  }

  Future<void> addJourney(Journey journey) async {
     try {
       await _client.from('journeys').insert(journey.toJson());
     } catch (e) {
        _logger.e('Failed to add journey: ${journey.title}', error: e);
        throw CouldNotAddJourney(e);
     }
  }

   Future<void> deleteJourney(String journeyId) async {
      try {
        await _client
            .from('journeys')
            .delete()
            .eq('id', journeyId);
      } catch (e) {
         _logger.e('Failed to delete journey: $journeyId', error: e);
         throw CouldNotDeleteJourney(e);
      }
   }
   
   Future<List<String>> fetchJourneyImages(
     String journeyId, {
     int? limit, 
     int? offset,
   }) async {
      try {
        var query = _client
            .from('journey_images')
            .select('image_url')
            .eq('journey_id', journeyId)
            .order('created_at', ascending: true);

        if (limit != null && offset != null) {
          query = query.range(offset, offset + limit - 1);
        }

        final response = await query;
        
         return List<String>.from(response.map((img) => img['image_url'] as String));
      } catch (e) {
         _logger.e('Failed to fetch images for journey: $journeyId', error: e);
         throw CouldNotFetchJourneyImages(e);
      }
   }

  // Method to add image reference to the DB table
  Future<void> addImageReference(String journeyId, String imageUrl) async {
    try {
      await _client.from('journey_images').insert({
        'journey_id': journeyId,
        'image_url': imageUrl,
      });
      _logger.i('Added image reference to DB for journey $journeyId');
    } catch (e) {
       _logger.e('Failed to add image reference for journey $journeyId', error: e);
       throw CouldNotAddImageReference(e);
    }
  }

  // Method to delete an image from DB and Storage
  Future<void> deleteImage(String journeyId, String imageUrl) async {
    _logger.d('deleteImage START - Journey: $journeyId, URL: $imageUrl'); // Use debug level
    // 1. Extract storage path from URL
    // Assumes URL structure: https://<project_ref>.supabase.co/storage/v1/object/public/journey_images/<user_id>/<journey_id>/<filename>
    final uri = Uri.parse(imageUrl);
    // Find the start of the path after bucket name
    final bucketName = 'journey_images'; // Make sure this matches your bucket
    final pathStartIndex = uri.path.indexOf(bucketName) + bucketName.length + 1; // +1 for the slash
    if (pathStartIndex <= bucketName.length) {
        _logger.e('Could not parse storage path from URL: $imageUrl');
        throw CouldNotDeleteImage('Invalid image URL format');
    }
    final storagePath = uri.path.substring(pathStartIndex);
    _logger.i('Attempting to delete image. Journey: $journeyId, URL: $imageUrl, Path: $storagePath');

    try {
      // 2. Delete DB reference (use imageUrl to find the row)
      _logger.d('Deleting DB reference for $imageUrl');
      await _client
          .from('journey_images')
          .delete()
          .eq('image_url', imageUrl);
      _logger.d('DB reference deleted (or did not exist).');

      // 3. Delete from Storage
      _logger.d('Deleting from Storage: $storagePath');
      await _client.storage
          .from(bucketName)
          .remove([storagePath]);
      _logger.d('Storage deletion success.');

      _logger.i('Successfully deleted image: $storagePath');

    } catch (e) {
      _logger.e('deleteImage FAILED for $imageUrl', error: e);
      _logger.e('Failed to delete image for journey $journeyId (URL: $imageUrl)', error: e);
      // Consider if partial deletion needs handling (e.g., DB deleted but storage failed)
      throw CouldNotDeleteImage(e);
    }
  }
} 