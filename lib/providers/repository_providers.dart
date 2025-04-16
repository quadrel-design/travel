import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel/repositories/auth_repository.dart';
import 'package:travel/repositories/journey_repository.dart';
import 'package:travel/models/journey_image_info.dart';

// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// Provider for JourneyRepository
final journeyRepositoryProvider = Provider<JourneyRepository>((ref) {
  return JourneyRepository();
});

// --- Add Provider for Detected Sums --- 
final detectedSumsProvider = FutureProvider.autoDispose
    .family<List<JourneyImageInfo>, String>((ref, journeyId) async {
  // Watch the repository provider
  final repository = ref.watch(journeyRepositoryProvider);
  // Call the fetch method
  return repository.fetchDetectedSums(journeyId);
});
// --- End Provider --- 