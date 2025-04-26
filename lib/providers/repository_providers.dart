/*
 * Repository Providers
 * 
 * This file defines providers for accessing repositories and data services.
 * These providers serve as the central access point for data operations throughout
 * the application, ensuring consistent access to Firebase services and repositories.
 * 
 * The file includes providers for:
 * - Firebase service instances (Firestore, Auth, Storage)
 * - Repository instances for different data domains
 * - Stream providers for reactive data access
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel/repositories/auth_repository.dart';
import 'package:travel/models/invoice_capture_process.dart';

// Import Firebase services
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../providers/logging_provider.dart';
import 'package:travel/repositories/invoice_repository.dart';
import 'package:travel/models/journey.dart';
import 'package:travel/repositories/firestore_invoice_repository.dart';
import 'package:travel/repositories/firebase_auth_repository.dart';

/// Provider for accessing the Firestore database instance.
///
/// This provider delivers a singleton instance of FirebaseFirestore throughout the app.
/// It serves as the foundation for all Firestore database operations.
final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Provider for accessing the Firebase Authentication instance.
///
/// This provider delivers a singleton instance of FirebaseAuth throughout the app.
/// It serves as the foundation for all authentication operations.
final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

/// Provider for accessing the Firebase Storage instance.
///
/// This provider delivers a singleton instance of FirebaseStorage throughout the app.
/// It serves as the foundation for all storage operations, including image uploads.
final firebaseStorageProvider =
    Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);

/// Provider for the authentication repository.
///
/// This provider creates and delivers an implementation of the AuthRepository interface.
/// It handles user authentication, registration, and session management.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  final logger = ref.watch(loggerProvider);
  return FirebaseAuthRepository(
      firebaseAuth, logger); // Use concrete implementation
});

/// Provider for the journey repository.
///
/// This provider creates and delivers an implementation of the JourneyRepository interface.
/// It handles operations related to journeys, including journey CRUD operations and image management.
final journeyRepositoryProvider = Provider<JourneyRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final storage = ref.watch(firebaseStorageProvider);
  final auth = ref.watch(firebaseAuthProvider);
  final logger = ref.watch(loggerProvider);

  return FirestoreInvoiceRepository(firestore, storage, auth, logger);
});

/// Stream provider for accessing the current user's journeys.
///
/// This provider delivers a real-time stream of the authenticated user's journeys.
/// The stream automatically updates when journeys are added, modified, or removed.
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
    .family<List<InvoiceCaptureProcess>, String>((ref, journeyId) {
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

/// Stream provider for all images associated with a journey.
///
/// This provider delivers a real-time stream of all images for a specific journey.
/// The stream automatically updates when images are added, modified, or removed.
///
/// Parameters:
///   - journeyId: The ID of the journey to fetch images for
final journeyImagesStreamProvider = StreamProvider.autoDispose
    .family<List<InvoiceCaptureProcess>, String>((ref, journeyId) {
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

/// Provider for tracking the gallery upload state.
///
/// This provider maintains a boolean state indicating whether a gallery upload
/// operation is currently in progress. UI components can observe this state
/// to show appropriate loading indicators.
final galleryUploadStateProvider = StateProvider<bool>((ref) => false);

/// Stream provider for a single journey by ID.
///
/// This provider delivers a real-time stream of a specific journey's data.
/// The stream automatically updates when the journey is modified.
///
/// Parameters:
///   - journeyId: The ID of the journey to stream
final journeyStreamProvider =
    StreamProvider.family<Journey?, String>((ref, journeyId) {
  final repository = ref.watch(journeyRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  logger.d(
      '[PROVIDER] journeyStreamProvider executing for journeyId: $journeyId');
  return repository.getJourneyStream(journeyId);
});
