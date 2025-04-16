import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/journey.dart';
import '../models/journey_image_info.dart';
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
   
   Future<List<JourneyImageInfo>> fetchJourneyImages(
     String journeyId, {
     int? limit, 
     int? offset,
   }) async {
      try {
        var query = _client
            .from('journey_images')
            .select('id, image_url, is_invoice_guess, has_potential_text, detected_text, detected_total_amount, detected_currency')
            .eq('journey_id', journeyId)
            .order('created_at', ascending: true);

        if (limit != null && offset != null) {
          query = query.range(offset, offset + limit - 1);
        }

        final response = await query;
        
         return response.map((data) => JourneyImageInfo.fromMap(data)).toList();
      } catch (e) {
         _logger.e('Failed to fetch images for journey: $journeyId', error: e);
         throw CouldNotFetchJourneyImages(e);
      }
   }

  // Method to add image reference to the DB table
  Future<void> addImageReference(
    String journeyId,
    String imageUrl,
    {required String id}
  ) async {
    try {
      // Insert only basic info
      await _client.from('journey_images').insert({
        'id': id,
        'journey_id': journeyId,
        'image_url': imageUrl,
        // Removed analysis flags
      });
      _logger.i('Added image reference to DB with ID: $id for journey $journeyId');
    } catch (e) {
       _logger.e('Failed to add image reference for journey $journeyId (ID: $id)', error: e);
       throw CouldNotAddImageReference(e);
    }
  }

  // Method to delete an image from DB and Storage
  Future<void> deleteImage(String journeyId, String imageUrl) async {
    _logger.d('deleteImage START - Journey: $journeyId, URL: $imageUrl');
    final uri = Uri.parse(imageUrl);
    final bucketName = 'journey_images';
    final pathStartIndex = uri.path.indexOf(bucketName) + bucketName.length + 1;
    if (pathStartIndex <= bucketName.length) {
        _logger.e('Could not parse storage path from URL: $imageUrl');
        throw CouldNotDeleteImage('Invalid image URL format');
    }
    final storagePath = uri.path.substring(pathStartIndex);
    _logger.i('Attempting to delete image. Journey: $journeyId, URL: $imageUrl, Path: $storagePath');

    try {
      _logger.d('Deleting DB reference for $imageUrl');
      await _client
          .from('journey_images')
          .delete()
          .eq('image_url', imageUrl);
      _logger.d('DB reference deleted (or did not exist).');

      _logger.d('Deleting from Storage: $storagePath');
      await _client.storage
          .from(bucketName)
          .remove([storagePath]);
      _logger.d('Storage deletion success.');

      _logger.i('Successfully deleted image: $storagePath');

    } catch (e) {
      _logger.e('deleteImage FAILED for $imageUrl', error: e);
      _logger.e('Failed to delete image for journey $journeyId (URL: $imageUrl)', error: e);
      throw CouldNotDeleteImage(e);
    }
  }

  // --- Add method to fetch detected sums --- 
  Future<List<JourneyImageInfo>> fetchDetectedSums(String journeyId) async {
    try {
      final response = await _client
          .from('journey_images')
          .select('id, image_url, detected_total_amount, detected_currency, last_processed_at') // Select relevant fields
          .eq('journey_id', journeyId)
          .not('detected_total_amount', 'is', null) // Filter for non-null amounts
          .order('last_processed_at', ascending: false); // Order by processing time

      return response.map((data) => JourneyImageInfo.fromMap(data)).toList();
    } catch (e) {
      _logger.e('Failed to fetch detected sums for journey: $journeyId', error: e);
      // Consider adding a specific exception type if needed
      throw JourneyRepositoryException('Could not fetch detected sums', e);
    }
  }
  // --- End method --- 
} 