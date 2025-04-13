import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/journey.dart';
import 'package:logger/logger.dart';

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
// --- End Custom Exceptions ---

class JourneyRepository {
   final SupabaseClient _client = Supabase.instance.client;
   final Logger _logger = Logger();

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
   
   Future<List<String>> fetchJourneyImages(String journeyId) async {
      try {
        final response = await _client
            .from('journey_images')
            .select('image_url')
            .eq('journey_id', journeyId)
            .order('created_at', ascending: true);
        
         return List<String>.from(response.map((img) => img['image_url'] as String));
      } catch (e) {
         _logger.e('Failed to fetch images for journey: $journeyId', error: e);
         throw CouldNotFetchJourneyImages(e);
      }
   }
} 