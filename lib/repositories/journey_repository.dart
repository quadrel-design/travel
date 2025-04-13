import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/journey.dart';

class JourneyRepository {
   final SupabaseClient _client = Supabase.instance.client;

  Future<List<Journey>> fetchUserJourneys(String userId) async {
    final response = await _client
        .from('journeys')
        .select()
        .eq('user_id', userId)
        .order('start_date', ascending: false);
    
    // Error handling should ideally be more robust in a real app
    // e.g., checking response.error, throwing custom exceptions
    return response.map((data) => Journey.fromJson(data)).toList();
  }

  Future<void> addJourney(Journey journey) async {
     await _client.from('journeys').insert(journey.toJson());
     // Consider returning the created journey or ID, handle errors
  }

   Future<void> deleteJourney(String journeyId) async {
      await _client
          .from('journeys')
          .delete()
          .eq('id', journeyId); 
      // RLS handles ensuring user owns the journey
   }
   
   // Add methods for fetching journey images (from journey_images table)
   Future<List<String>> fetchJourneyImages(String journeyId) async {
      final response = await _client
          .from('journey_images')
          .select('image_url')
          .eq('journey_id', journeyId)
          .order('created_at', ascending: true);
      
       return List<String>.from(response.map((img) => img['image_url'] as String));
   }
   
   // Add methods for updating journeys etc.
} 