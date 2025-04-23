import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel/repositories/auth_repository.dart';
import 'package:travel/repositories/journey_repository.dart';
import 'package:travel/models/journey_image_info.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/logging_provider.dart'; // Import logger provider

// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  // Inject SupabaseClient and Logger
  // final supabaseClient = Supabase.instance.client;
  // final logger = ref.watch(loggerProvider);
  // return AuthRepository(supabaseClient, logger); // Constructor takes no args based on error
  return AuthRepository();
});

// Provider for JourneyRepository
final journeyRepositoryProvider = Provider<JourneyRepository>((ref) {
  // Inject SupabaseClient and Logger
  final supabaseClient = Supabase.instance.client;
  final logger = ref.watch(loggerProvider);
  return JourneyRepository(supabaseClient, logger);
});

// --- Change Provider for Detected Sums to StreamProvider --- 
final detectedSumsProvider = StreamProvider.autoDispose
    .family<List<JourneyImageInfo>, String>((ref, journeyId) {
  // Get Supabase client instance
  final supabaseClient = Supabase.instance.client;
  
  // Define the stream - Fetch all images for the journey
  final stream = supabaseClient
      .from('journey_images')
      .stream(primaryKey: ['id']) // Specify primary key
      .eq('journey_id', journeyId) // Filter by journey
      .order('last_processed_at', ascending: false); // Optional ordering

  // Map the stream data and FILTER within the map
  return stream.map((listOfMaps) {
    return listOfMaps
        .map((map) => JourneyImageInfo.fromMap(map))
        // Apply the filter here
        .where((imageInfo) => imageInfo.detectedTotalAmount != null)
        .toList();
  });
});
// --- End Provider --- 

// --- Add Provider for Journey Images Stream --- 
final journeyImagesStreamProvider = StreamProvider.autoDispose
    .family<List<JourneyImageInfo>, String>((ref, journeyId) {
  // Get the repository
  final repository = ref.watch(journeyRepositoryProvider);
  // Get logger
  final logger = ref.watch(loggerProvider); 
  // *** Log Provider Execution ***
  logger.d('[PROVIDER] journeyImagesStreamProvider executing for journeyId: $journeyId');
  // Return the stream from the repository method
  return repository.getJourneyImagesStream(journeyId);
});
// --- End Provider --- 

// --- Add Provider for Gallery Upload State --- 
final galleryUploadStateProvider = StateProvider<bool>((ref) => false);
// --- End Provider --- 