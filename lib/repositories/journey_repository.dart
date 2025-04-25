import 'dart:typed_data'; // For Uint8List

// Firebase Imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Remove Supabase import
// import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:logger/logger.dart'; // Import Logger
import '../models/journey.dart';
import '../models/journey_image_info.dart';
import 'repository_exceptions.dart'; // Import custom exceptions

// Abstract class defining the contract for Journey data operations
abstract class JourneyRepository {
  // --- Journey Methods ---

  /// Fetches all journeys for the currently logged-in user as a stream.
  Stream<List<Journey>> fetchUserJourneys();

  /// Fetches a single journey by its ID as a stream.
  Stream<Journey?> getJourneyStream(String journeyId);

  /// Adds a new journey to the data store.
  /// Returns the newly created Journey object with its generated ID.
  Future<Journey> addJourney(Journey journey);

  /// Updates an existing journey.
  Future<void> updateJourney(Journey journey);

  /// Deletes a journey and its associated data (like images).
  Future<void> deleteJourney(String journeyId);

  // --- Journey Image Methods ---

  /// Fetches all image metadata for a specific journey as a stream.
  Stream<List<JourneyImageInfo>> getJourneyImagesStream(String journeyId);

  /// Uploads an image file for a specific journey.
  /// Returns the JourneyImageInfo object containing metadata and the download URL.
  Future<JourneyImageInfo> uploadJourneyImage(
      String journeyId, List<int> imageBytes, String fileName);

  /// Deletes a specific image associated with a journey, including its storage file.
  Future<void> deleteJourneyImage(
      String journeyId, String imageId, String fileName);

  // --- Potentially needed methods (Add if required by other parts of the app) ---

  // Future<void> updateJourneyImageMetadata(String journeyId, JourneyImageInfo imageInfo);

  // Note: Removed getJourneys (use fetchUserJourneys stream), createJourney (use addJourney),
  // deleteSingleJourneyImage (use deleteJourneyImage), addImageReference (Firestore handles this)
  // compared to the original interface deduced from the error messages.
}

class JourneyRepositoryImpl implements JourneyRepository {
  // --- Dependency Injection ---
  // Replace SupabaseClient with Firestore and Storage
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final Logger _logger;

  // Update constructor
  JourneyRepositoryImpl(
      this._firestore, this._storage, this._auth, this._logger);
  // --- End Dependency Injection ---

  // Helper to get current user ID, throws NotAuthenticatedException if null
  String _getCurrentUserId() {
    // Use FirebaseAuth and uid
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _logger.e('User ID is null, operation requires authentication.');
      throw NotAuthenticatedException(
          'User must be logged in to perform this operation.');
    }
    return userId;
  }

  @override
  Future<void> updateJourney(Journey journey) async {
    try {
      // Use user ID check primarily for logging or if rules aren't set up
      final userId = _getCurrentUserId();
      _logger.d('Updating journey ID: ${journey.id} for user: $userId');

      // Prepare data, remove id and potentially user_id if handled by rules
      final journeyData = journey.toJson();
      journeyData.remove('id');
      // journeyData.remove('user_id'); // Keep if needed for rules/queries
      // Consider adding an 'updated_at' timestamp
      journeyData['updated_at'] = FieldValue.serverTimestamp();

      // Use Firestore update by document ID
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('journeys')
          .doc(journey.id)
          .update(journeyData);

      _logger.i('Successfully updated journey ID: ${journey.id}');
    } on FirebaseException catch (e, stackTrace) {
      // Catch FirebaseException
      _logger.e('[JOURNEY] Error updating journey:',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
          // Use custom exception
          'Failed to update journey: ${e.message}',
          e,
          stackTrace);
    } on NotAuthenticatedException {
      // Re-throw specific exception
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error updating journey ${journey.id}',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
          'An unexpected error occurred while updating the journey.',
          e,
          stackTrace);
    }
  }

  @override
  Future<void> deleteJourney(String journeyId) async {
    String userId =
        'unknown_user'; // Default for logging if user ID fetch fails
    try {
      userId = _getCurrentUserId();
      _logger
          .d('Attempting to delete journey ID: $journeyId for user: $userId');

      // --- 1. Delete associated images from Firebase Storage ---
      final storagePath = '$userId/$journeyId';
      _logger.d('Listing files in storage path: $storagePath for deletion.');

      try {
        final listResult = await _storage.ref().child(storagePath).listAll();
        final fileRefsToDelete = listResult.items;

        if (fileRefsToDelete.isNotEmpty) {
          _logger
              .d('Deleting ${fileRefsToDelete.length} files from storage...');
          // Delete all files concurrently
          await Future.wait(fileRefsToDelete.map((ref) => ref.delete()));
          _logger.d('Storage files deleted.');
        } else {
          _logger.d('No files found in storage path $storagePath to delete.');
        }
        // Catch FirebaseException for storage operations
      } on FirebaseException catch (e, stackTrace) {
        _logger.e('FirebaseException deleting journey content $journeyId',
            error: e, stackTrace: stackTrace);
        // Decide if this is critical - maybe only log and continue to delete DB record?
        // For now, we'll throw a specific exception.
        throw ImageDeleteException(
            'Failed to delete images from storage: ${e.message}',
            e,
            stackTrace);
      }

      // --- 2. Delete the journey record from Firestore ---
      _logger.d('Deleting journey record ID: $journeyId from database.');
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('journeys')
          .doc(journeyId)
          .delete();
      // Note: Firestore rules should prevent unauthorized deletion

      _logger.i(
          'Successfully deleted journey ID: $journeyId and associated data.');
    } on FirebaseException catch (e, stackTrace) {
      // Catch Firestore exceptions
      _logger.e('[JOURNEY] Error deleting journey:',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
          'Failed to delete journey record: ${e.message}', e, stackTrace);
    } on NotAuthenticatedException {
      // Re-throw specific exception
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error deleting journey $journeyId',
          error: e, stackTrace: stackTrace);
      // Determine if it was storage or db based on where it happened?
      // For now, throw generic DatabaseOperationException
      throw DatabaseOperationException(
          'An unexpected error occurred while deleting the journey.',
          e,
          stackTrace);
    }
  }

  @override
  Stream<List<JourneyImageInfo>> getJourneyImagesStream(String journeyId) {
    _logger.d('[REPO STREAM] Creating image stream for journey $journeyId');
    try {
      // Use Firestore snapshots stream
      // IMPORTANT: Path corrected to use subcollection within journey
      final query = _firestore
          .collection('users')
          .doc(_getCurrentUserId()) // Use helper to ensure user ID
          .collection('journeys')
          .doc(journeyId)
          .collection('images')
          .orderBy('uploadedAt', descending: true); // Order by upload time

      final stream = query.snapshots(); // Get the stream of QuerySnapshots

      // Map the stream data
      return stream.map((querySnapshot) {
        _logger.d(
            '[REPO STREAM MAP] Stream emitted ${querySnapshot.docs.length} docs for journey $journeyId');
        return querySnapshot.docs
            .map((doc) {
              try {
                // Map Firestore document to JourneyImageInfo, adding document ID
                final data = doc.data();
                // ID is implicitly the document ID
                final info =
                    JourneyImageInfo.fromJson(data).copyWith(id: doc.id);
                _logger.d(
                    '[REPO STREAM MAP INNER] Mapped doc ${doc.id} to: ${info.id}, ${info.url}, ${info.lastProcessedAt}');
                return info;
              } catch (e, stackTrace) {
                _logger.e(
                    '[REPO STREAM MAP INNER] Error mapping item: ${doc.id}',
                    error: e,
                    stackTrace: stackTrace);
                return null; // Indicate mapping failure
              }
            })
            .where((item) => item != null) // Filter out failed mappings
            .cast<JourneyImageInfo>()
            .toList();
      }).handleError((error, stackTrace) {
        // Add error handling to the stream
        _logger.e('[REPO STREAM] Error in image stream for journey $journeyId',
            error: error, stackTrace: stackTrace);
        throw DatabaseFetchException(
            'Failed to fetch images: ${error.toString()}', error, stackTrace);
      });
    } catch (e, stackTrace) {
      _logger.e(
          '[REPO STREAM] Error creating Firestore stream for journey $journeyId',
          error: e,
          stackTrace: stackTrace);
      // Return an error stream or rethrow, depending on desired behavior
      return Stream.error(DatabaseFetchException(
          'Failed to create image stream: $e', e, stackTrace));
    }
  }

  @override
  Future<Journey> addJourney(Journey journey) async {
    final userId = _getCurrentUserId(); // Use helper
    _logger.i('Adding journey: ${journey.title} for user: $userId');
    try {
      // Add user ID and timestamps if not already set
      final journeyWithMeta = journey.copyWith(
        userId: userId,
        // createdAt: DateTime.now(), // Add if model supports it
        // updatedAt: DateTime.now(), // Add if model supports it
      );
      final docRef = await _firestore
          .collection('users')
          .doc(userId) // Use obtained userId
          .collection('journeys')
          .add(journeyWithMeta.toJson());
      _logger.i('Journey added with ID: ${docRef.id}');
      // Return the Journey object with the new ID
      return journeyWithMeta.copyWith(id: docRef.id);
    } on FirebaseException catch (e, s) {
      _logger.e('FirebaseException adding journey: ${e.message}',
          error: e, stackTrace: s);
      throw DatabaseOperationException(
          'Failed to add journey: ${e.code}', e, s);
    } catch (e, s) {
      _logger.e('Unknown error adding journey', error: e, stackTrace: s);
      throw DatabaseOperationException(
          'An unexpected error occurred while adding the journey.', e, s);
    }
  }

  @override
  Stream<Journey?> getJourneyStream(String journeyId) {
    final userId = _getCurrentUserId(); // Use helper
    _logger
        .d('Setting up stream for single journey: $journeyId for user $userId');
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('journeys')
        .doc(journeyId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        _logger.d('Received snapshot for journey $journeyId');
        return Journey.fromJson(snapshot.data()!).copyWith(id: snapshot.id);
      } else {
        _logger.w('Journey $journeyId does not exist or has no data.');
        return null;
      }
    }).handleError((error, stackTrace) {
      _logger.e('[JOURNEY] Error getting journey by ID:',
          error: error, stackTrace: stackTrace);
      throw DatabaseFetchException(
          'Failed to fetch journey details: ${error.toString()}',
          error,
          stackTrace);
    });
  }

  @override
  Future<JourneyImageInfo> uploadJourneyImage(
      String journeyId, List<int> imageBytes, String fileName) async {
    final userId = _getCurrentUserId(); // Use helper
    _logger
        .i('Uploading image $fileName to journey $journeyId for user $userId');

    // Construct the storage path using user ID
    final imagePath = 'users/$userId/journeys/$journeyId/images/$fileName';
    final imageRef = _storage.ref().child(imagePath);

    try {
      // Use Uint8List here as required by putData
      final uploadTask = await imageRef.putData(Uint8List.fromList(imageBytes));
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      _logger.i('Image uploaded successfully: $downloadUrl');

      // Use correct constructor parameters for JourneyImageInfo
      final imageInfo = JourneyImageInfo(
        id: '', // Firestore will generate ID
        url: downloadUrl,
        imagePath: imagePath, // Use the storage path
        // Initialize other fields as needed
        hasPotentialText: null,
        lastProcessedAt: null,
        detectedText: null,
        detectedTotalAmount: null,
        detectedCurrency: null,
        isInvoiceGuess: false,
      );

      final docRef = await _firestore
          .collection('users')
          .doc(userId) // Use obtained userId
          .collection('journeys')
          .doc(journeyId)
          .collection('images')
          .add(imageInfo.toJson()); // Use the toJson method

      _logger.i('Image metadata added to Firestore with ID: ${docRef.id}');
      // Return the JourneyImageInfo object with the new ID
      return imageInfo.copyWith(id: docRef.id);
    } on FirebaseException catch (e, s) {
      _logger.e('FirebaseException uploading image: ${e.message}',
          error: e, stackTrace: s);
      if (e.code == 'object-not-found') {
        throw ImageUploadException('Storage object not found.', e, s);
      } else if (e.code == 'unauthorized') {
        throw NotAuthenticatedException(
            'Unauthorized to upload image. Check Storage rules.');
      } else {
        throw ImageUploadException(
            'Firebase error during upload: ${e.code}', e, s);
      }
    } catch (e, s) {
      _logger.e('Unknown error uploading image', error: e, stackTrace: s);
      throw ImageUploadException(
          'An unexpected error occurred while uploading the image.', e, s);
    }
  }

  @override
  Future<void> deleteJourneyImage(
      String journeyId, String imageId, String fileName) async {
    final userId = _getCurrentUserId(); // Use helper
    _logger.i(
        'Deleting image $fileName (ID: $imageId) from journey $journeyId for user $userId');

    // Construct the storage path using user ID
    final imagePath = 'users/$userId/journeys/$journeyId/images/$fileName';
    final imageRef = _storage.ref().child(imagePath);
    final docRef = _firestore
        .collection('users')
        .doc(userId) // Use obtained userId
        .collection('journeys')
        .doc(journeyId)
        .collection('images')
        .doc(imageId);

    try {
      // Start both deletions, prioritize Firestore doc deletion
      await docRef.delete();
      _logger.i('Firestore document for image $imageId deleted.');

      try {
        await imageRef.delete();
        _logger.i('Storage file $fileName deleted.');
      } on FirebaseException catch (storageError, storageStackTrace) {
        // Log storage deletion error but don't throw if Firestore deletion succeeded
        _logger.e(
            'FirebaseException deleting storage file $fileName: ${storageError.message}',
            error: storageError,
            stackTrace: storageStackTrace);
      } catch (storageError, storageStackTrace) {
        _logger.e('Unknown error deleting storage file $fileName',
            error: storageError, stackTrace: storageStackTrace);
      }
    } on FirebaseException catch (e, s) {
      _logger.e('FirebaseException deleting image metadata: ${e.message}',
          error: e, stackTrace: s);
      throw DatabaseOperationException(
          'Failed to delete image metadata: ${e.code}', e, s);
    } catch (e, s) {
      _logger.e('Unknown error deleting image', error: e, stackTrace: s);
      throw DatabaseOperationException(
          'An unexpected error occurred while deleting the image.', e, s);
    }
  }

  // --- Add Method to Delete Single Journey Image ---
  Future<void> deleteSingleJourneyImage(
      String imageId, String imagePath) async {
    // Get user ID for logging/potential rules
    final userId = _getCurrentUserId(); // Throws if not logged in
    _logger.d(
        'Attempting to delete single image. ID: $imageId, Path: $imagePath, User: $userId');

    // Flag to track if storage deletion succeeded
    bool storageDeleteSucceeded = false;

    if (imagePath.isEmpty) {
      _logger.w(
          'Image path is empty for image ID $imageId. Cannot delete from storage. Attempting DB delete only.');
      // Proceed directly to DB delete
    } else {
      // 1. Delete from Storage
      try {
        _logger.d('Deleting image from storage: $imagePath');
        await _storage.ref().child(imagePath).delete();
        _logger.d('Successfully deleted image from storage: $imagePath');
        storageDeleteSucceeded = true;
        // Catch FirebaseException for storage
      } on FirebaseException catch (e, stackTrace) {
        _logger.e('FirebaseException deleting image $imagePath',
            error: e, stackTrace: stackTrace);
        // If object not found, maybe proceed? For now, treat as failure.
        if (e.code == 'object-not-found') {
          _logger.w(
              'Image $imagePath not found in storage, proceeding to delete DB record.');
          storageDeleteSucceeded =
              true; // Treat as success for DB deletion logic
        } else {
          throw ImageDeleteException(
              'Failed to delete image from storage: ${e.message}',
              e,
              stackTrace);
        }
      } catch (e, stackTrace) {
        // Catch other potential errors during storage removal
        _logger.e('Unexpected error deleting image from storage $imagePath',
            error: e, stackTrace: stackTrace);
        throw ImageDeleteException(
            'An unexpected error occurred during storage deletion.',
            e,
            stackTrace);
      }
    }

    // 2. Delete from Database (only if storage deletion wasn't explicitly blocked by error)
    try {
      _logger.d('Deleting image record from DB: $imageId');
      await _firestore.collection('journey_images').doc(imageId).delete();
      _logger.i('Successfully deleted image record from DB: $imageId');
      // Catch FirebaseException for database
    } on FirebaseException catch (e, stackTrace) {
      _logger.e('FirebaseException deleting image record $imageId',
          error: e, stackTrace: stackTrace);
      // If storage delete succeeded but DB failed, log warning
      if (storageDeleteSucceeded) {
        _logger.w(
            'Storage file $imagePath deleted, but failed to delete DB reference for ID $imageId. Manual cleanup might be needed.');
      }
      throw DatabaseOperationException(
          'DB delete failed: ${e.message}', e, stackTrace);
    } on NotAuthenticatedException {
      // Re-throw specific exception
      rethrow;
    } catch (e, stackTrace) {
      // Catch other potential errors during DB deletion
      _logger.e('Unexpected error deleting image record $imageId',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
          'An unexpected error occurred during DB deletion.', e, stackTrace);
    }
  }

  // --- End Method to Delete Single Journey Image ---

  // --- ADDED Implementation for fetchUserJourneys ---
  @override
  Stream<List<Journey>> fetchUserJourneys() {
    final userId = _getCurrentUserId(); // Use helper
    _logger.d('Setting up stream for user journeys: $userId');
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('journeys')
        // .orderBy('startDate', descending: true) // Optional: Order journeys
        .snapshots()
        .map((snapshot) {
      _logger.d(
          'Received journey snapshot with ${snapshot.docs.length} documents.');
      return snapshot.docs
          .map((doc) => Journey.fromJson(doc.data()).copyWith(id: doc.id))
          .toList();
    }).handleError((error, stackTrace) {
      _logger.e('[JOURNEY] Error getting journeys:',
          error: error, stackTrace: stackTrace);
      throw DatabaseFetchException(
          'Failed to fetch journeys: ${error.toString()}', error, stackTrace);
    });
  }
  // --- End fetchUserJourneys ---
}
