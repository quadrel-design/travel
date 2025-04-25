// Removed unused import: import 'package:flutter_riverpod/flutter_riverpod.dart';
// Removed unused import: import 'package:riverpod_annotation/riverpod_annotation.dart';
// Removed unused import: import 'package:travel/models/journey.dart';
// Removed unused import: import 'package:travel/providers/repository_providers.dart';

// Removed unused part directive: part 'journey_provider.g.dart';

/* // Comment out provider using unavailable repo
// Example provider - adjust as needed
// This provider might fetch all journeys for the current user
final allJourneysProvider = FutureProvider<List<Journey>>((ref) async {
  final journeyRepository = ref.watch(journeyRepositoryProvider);
  // Get AuthRepository to access current user
  final authRepository = ref.watch(authRepositoryProvider);
  // Get current user ID from AuthRepository
  final userId = authRepository.currentUser?.uid;

  if (userId == null) {
    // Handle case where user is not logged in (return empty list or throw error)
    return [];
  }
  // Pass userId to the fetch method
  return journeyRepository.fetchUserJourneys(userId);
});
*/

// Add other journey-related providers here if necessary

/* // Temporarily comment out this provider
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/journey.dart'; // Import Journey model
// Adjust path as needed
import '../repositories/journey_repository.dart'; 
// Adjust path as needed
import 'repository_providers.dart';

// Provider for fetching a single journey by ID
final journeyProvider = StreamProvider.autoDispose.family<Journey?, String>((ref, journeyId) {
  final repository = ref.watch(journeyRepositoryProvider);
  // Return the stream from the repository
  return repository.getJourneyStream(journeyId);
});
*/
