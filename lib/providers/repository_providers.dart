import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel/repositories/auth_repository.dart';
// import 'package:travel/repositories/journey_repository.dart'; // Remove unused import
import 'package:travel/models/journey_image_info.dart'; // ADDED Import for JourneyImageInfo model
// Remove Supabase import
// import 'package:supabase_flutter/supabase_flutter.dart';

// Import Firebase services
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../providers/logging_provider.dart'; // Import logger provider
import 'package:travel/repositories/journey_repository.dart'; // Import base repository class
import 'package:travel/models/journey.dart'; // ADDED Import for Journey model

// import '../providers/logging_provider.dart'; // Remove unused import

// Import the concrete implementation provider
import 'package:travel/repositories/firebase_auth_repository.dart';
import 'package:travel/repositories/firestore_journey_repository.dart'; // ADDED Import
import 'package:logger/logger.dart'; // Import logger

// Provides the Firestore instance
final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

// Provides the FirebaseAuth instance
final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

// Provides the FirebaseStorage instance
final firebaseStorageProvider =
    Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);

// Provider for the AuthRepository (returns the concrete implementation)
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  final logger = ref.watch(loggerProvider);
  return FirebaseAuthRepository(
      firebaseAuth, logger); // Use concrete implementation
});

// Provider for the JourneyRepository (returns the concrete implementation)
final journeyRepositoryProvider = Provider<JourneyRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final storage = ref.watch(firebaseStorageProvider);
  final auth = ref.watch(firebaseAuthProvider);
  final logger = ref.watch(loggerProvider);
  // Pass storage back to the constructor
  return FirestoreJourneyRepository(firestore, storage, auth, logger);
});

// --- Stream Provider for User Journeys ---
final userJourneysStreamProvider =
    StreamProvider.autoDispose<List<Journey>>((ref) {
  // Get the repository
  final repository = ref.watch(journeyRepositoryProvider);
  // Return the stream from the repository method
  // Error handling should be done within the stream or by the UI watching this provider
  return repository.fetchUserJourneys();
});

// UNCOMMENTED block for providers depending on JourneyRepository

// Update detectedSumsProvider to use JourneyRepository stream
final detectedSumsProvider = StreamProvider.autoDispose
    .family<List<JourneyImageInfo>, String>((ref, journeyId) {
  // Get the repository
  final repository = ref.watch(journeyRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  logger
      .d('[PROVIDER] detectedSumsProvider executing for journeyId: $journeyId');

  // Get the stream from the repository
  final imagesStream = repository.getJourneyImagesStream(journeyId);

  // Apply the filter to the stream
  return imagesStream.map((imageList) {
    return imageList
        .where((imageInfo) => imageInfo.detectedTotalAmount != null)
        .toList();
  });
});
// --- End Provider ---

// --- Provider for Journey Images Stream (Already uses repository) ---
final journeyImagesStreamProvider = StreamProvider.autoDispose
    .family<List<JourneyImageInfo>, String>((ref, journeyId) {
  // Get the repository
  final repository = ref.watch(journeyRepositoryProvider);
  // Get logger
  final logger = ref.watch(loggerProvider);
  // *** Log Provider Execution ***
  logger.d(
      '[PROVIDER] journeyImagesStreamProvider executing for journeyId: $journeyId');
  // Return the stream from the repository method
  return repository.getJourneyImagesStream(journeyId);
});
// --- End Provider ---

// End temporary comment block for JourneyRepository dependents

// --- Add Provider for Gallery Upload State ---
final galleryUploadStateProvider = StateProvider<bool>((ref) => false);
// --- End Provider ---
