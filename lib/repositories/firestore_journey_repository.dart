// ignore_for_file: unused_field

import 'dart:async';
import 'dart:typed_data'; // Add this import for Uint8List
// Hide dart:io Platform
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as image_lib;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
// Import dart:html for Blob if on web
import 'dart:html' as html show Blob, MediaSource;
import 'package:http/http.dart' as http;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';

import '../models/journey.dart';
import '../models/journey_image_info.dart';
import 'journey_repository.dart';
import 'repository_exceptions.dart'; // Import custom exceptions

class FirestoreException implements Exception {
  final String message;
  final dynamic error;

  FirestoreException({
    required this.message,
    this.error,
  });

  @override
  String toString() => 'FirestoreException: $message';
}

// Implementation of JourneyRepository for Firebase/Firestore
class FirestoreJourneyRepository implements JourneyRepository {
  FirestoreJourneyRepository(
    this._firestore,
    this._storage,
    this._auth,
    this._logger,
  );

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final Logger _logger;

  // Helper to get current user ID, throws NotAuthenticatedException if null
  String _getCurrentUserId() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _logger.e('User ID is null, operation requires authentication.');
      throw NotAuthenticatedException(
          'User must be logged in to perform this operation.');
    }
    return userId;
  }

  // --- Journey Methods ---
  @override
  Stream<List<Journey>> fetchUserJourneys() {
    try {
      final userId = _getCurrentUserId();
      _logger.d('Setting up stream for user journeys: $userId');

      return _firestore
          .collection('users')
          .doc(userId)
          .collection('journeys')
          .snapshots()
          .map((snapshot) {
        _logger.d(
            'Received journey snapshot with ${snapshot.docs.length} documents.');
        return snapshot.docs.map((doc) {
          try {
            final data = doc.data();
            // Add the ID to the data map before conversion
            data['id'] = doc.id;
            return Journey.fromMap(data);
          } catch (e, stackTrace) {
            _logger.e('Error converting document to Journey:',
                error: e, stackTrace: stackTrace);
            // Skip invalid documents
            return null;
          }
        })
        .where((journey) => journey != null)
        .cast<Journey>()
        .toList();
      }).handleError((error, stackTrace) {
        _logger.e('Error fetching user journeys stream',
            error: error, stackTrace: stackTrace);
        throw DatabaseFetchException(
            'Failed to fetch journeys: ${error.toString()}', error, stackTrace);
      });
    } catch (e, stackTrace) {
      _logger.e('Error creating journeys stream',
          error: e, stackTrace: stackTrace);
      return Stream.error(DatabaseFetchException(
          'Failed to create journeys stream: $e', e, stackTrace));
    }
  }

  @override
  Stream<Journey?> getJourneyStream(String journeyId) {
    try {
      final userId = _getCurrentUserId();
      _logger.d(
          'Setting up stream for single journey: $journeyId for user $userId');

      return _firestore
          .collection('users')
          .doc(userId)
          .collection('journeys')
          .doc(journeyId)
          .snapshots()
          .map((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          try {
            _logger.d('Received snapshot for journey $journeyId');
            final data = snapshot.data()!;
            data['id'] = snapshot.id;
            return Journey.fromMap(data);
          } catch (e, stackTrace) {
            _logger.e('Error converting document to Journey:',
                error: e, stackTrace: stackTrace);
            return null;
          }
        } else {
          _logger.w('Journey $journeyId does not exist or has no data.');
          return null;
        }
      }).handleError((error, stackTrace) {
        _logger.e('Error fetching single journey stream ($journeyId)',
            error: error, stackTrace: stackTrace);
        throw DatabaseFetchException(
            'Failed to fetch journey details: ${error.toString()}',
            error,
            stackTrace);
      });
    } catch (e, stackTrace) {
      _logger.e('Error creating journey stream for $journeyId',
          error: e, stackTrace: stackTrace);
      return Stream.error(DatabaseFetchException(
          'Failed to create journey stream: $e', e, stackTrace));
    }
  }

  @override
  Future<Journey> addJourney(Journey journey) async {
    try {
      final userId = _getCurrentUserId();
      _logger.i('Adding journey: ${journey.title} for user: $userId');

      // Add user ID and timestamps if not already set
      final journeyWithMeta = journey.copyWith(
        userId: userId,
        // Add timestamps if the model supports it
      );

      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('journeys')
          .add(journeyWithMeta.toJson());

      _logger.i('Journey added with ID: ${docRef.id}');
      // Return the Journey object with the new ID
      return journeyWithMeta.copyWith(id: docRef.id);
    } on FirebaseException catch (e, stackTrace) {
      _logger.e('FirebaseException adding journey: ${e.message}',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
          'Failed to add journey: ${e.code}', e, stackTrace);
    } catch (e, stackTrace) {
      _logger.e('Unknown error adding journey',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
          'An unexpected error occurred while adding the journey.',
          e,
          stackTrace);
    }
  }

  @override
  Future<void> updateJourney(Journey journey) async {
    try {
      final userId = _getCurrentUserId();
      _logger.d('Updating journey ID: ${journey.id} for user: $userId');

      // Prepare data, remove id and potentially user_id if handled by rules
      final journeyData = journey.toJson();
      journeyData.remove('id');
      // Add updated_at timestamp
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
      _logger.e('FirebaseException updating journey ${journey.id}',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
          'Failed to update journey: ${e.message}', e, stackTrace);
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
      final storagePath = 'users/$userId/journeys/$journeyId';
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
      } on FirebaseException catch (e, stackTrace) {
        _logger.e('FirebaseException deleting journey content $journeyId',
            error: e, stackTrace: stackTrace);
        // Log error but continue with DB deletion
        _logger.w('Continuing with database deletion despite storage error.');
      }

      // --- 2. Delete the journey record from Firestore ---
      _logger.d('Deleting journey record ID: $journeyId from database.');
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('journeys')
          .doc(journeyId)
          .delete();

      _logger.i(
          'Successfully deleted journey ID: $journeyId and associated data.');
    } on FirebaseException catch (e, stackTrace) {
      // Catch Firestore exceptions
      _logger.e('FirebaseException deleting journey record $journeyId',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
          'Failed to delete journey record: ${e.message}', e, stackTrace);
    } on NotAuthenticatedException {
      // Re-throw specific exception
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error deleting journey $journeyId',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
          'An unexpected error occurred while deleting the journey.',
          e,
          stackTrace);
    }
  }

  // --- Journey Image Methods ---
  @override
  Stream<List<JourneyImageInfo>> getJourneyImagesStream(String journeyId) {
    try {
      final userId = _getCurrentUserId();
      final user = _auth.currentUser;

      _logger.d('[REPO STREAM] Starting image stream with:');
      _logger.d('  - Journey ID: $journeyId');
      _logger.d('  - User ID: $userId');
      _logger.d(
          '  - Auth state: ${user != null ? 'Authenticated' : 'Not authenticated'}');

      // Validate the path components
      if (userId.isEmpty || journeyId.isEmpty) {
        _logger.e('[REPO STREAM] Invalid path components:');
        _logger.e('  - User ID: ${userId.isEmpty ? 'EMPTY' : userId}');
        _logger.e('  - Journey ID: ${journeyId.isEmpty ? 'EMPTY' : journeyId}');
        return Stream.value(<JourneyImageInfo>[]);
      }

      // Get references to all the required paths
      final userDoc = _firestore.collection('users').doc(userId);
      final journeyDoc = userDoc.collection('journeys').doc(journeyId);
      final imagesCollection = journeyDoc.collection('images');

      _logger.d('[REPO STREAM] Firestore paths:');
      _logger.d('  - User doc: ${userDoc.path}');
      _logger.d('  - Journey doc: ${journeyDoc.path}');
      _logger.d('  - Images collection: ${imagesCollection.path}');

      // First verify the journey exists
      return journeyDoc.get().asStream().asyncExpand((journeySnapshot) {
        if (!journeySnapshot.exists) {
          _logger.e('[REPO STREAM] Journey document not found:');
          _logger.e('  - Path: ${journeyDoc.path}');
          return Stream.value(<JourneyImageInfo>[]);
        }

        _logger.d('[REPO STREAM] Journey document exists:');
        _logger.d('  - Data: ${journeySnapshot.data()}');

        // Query the images collection
        final query = imagesCollection.orderBy('uploadedAt', descending: true);

        return query.snapshots().map((querySnapshot) {
          _logger.d('[REPO STREAM] Images query snapshot:');
          _logger.d('  - Document count: ${querySnapshot.docs.length}');
          _logger.d('  - From cache: ${querySnapshot.metadata.isFromCache}');
          _logger.d(
              '  - Has pending writes: ${querySnapshot.metadata.hasPendingWrites}');

          if (querySnapshot.docs.isEmpty) {
            _logger.w('[REPO STREAM] No images found in collection:');
            _logger.w('  - Collection path: ${imagesCollection.path}');
            return <JourneyImageInfo>[];
          }

          final images = querySnapshot.docs
              .map((doc) {
                try {
                  final data = doc.data();
                  data['id'] = doc.id;

                  _logger.d('[REPO STREAM] Processing image document:');
                  _logger.d('  - Document ID: ${doc.id}');
                  _logger.d('  - Raw data: $data');

                  // Check for required fields
                  if (!data.containsKey('url') ||
                      !data.containsKey('image_path')) {
                    _logger.e(
                        '[REPO STREAM] Missing required fields in document ${doc.id}');
                    _logger.e('  - Available fields: ${data.keys.join(", ")}');
                    return null;
                  }

                  // Create JourneyImageInfo object
                  final info = JourneyImageInfo.fromJson(data);

                  // Validate the object
                  if (info.url.isEmpty || info.imagePath.isEmpty) {
                    _logger.e('[REPO STREAM] Invalid JourneyImageInfo object:');
                    _logger.e('  - ID: ${info.id}');
                    _logger.e('  - URL: ${info.url}');
                    _logger.e('  - Path: ${info.imagePath}');
                    return null;
                  }

                  _logger.i('[REPO STREAM] Successfully processed image:');
                  _logger.i('  - ID: ${info.id}');
                  _logger.i('  - URL: ${info.url}');
                  return info;
                } catch (e, stack) {
                  _logger.e('[REPO STREAM] Error processing document:',
                      error: e, stackTrace: stack);
                  return null;
                }
              })
              .where((info) => info != null)
              .cast<JourneyImageInfo>()
              .toList();

          _logger.i('[REPO STREAM] Stream update:');
          _logger.i('  - Total documents: ${querySnapshot.docs.length}');
          _logger.i('  - Valid images: ${images.length}');

          return images;
        });
      }).handleError((error, stackTrace) {
        _logger.e('[REPO STREAM] Stream error:',
            error: error, stackTrace: stackTrace);
        throw DatabaseFetchException(
            'Failed to fetch images', error, stackTrace);
      });
    } catch (e, stackTrace) {
      _logger.e('[REPO STREAM] Fatal error:', error: e, stackTrace: stackTrace);
      return Stream.error(DatabaseFetchException(
          'Failed to create image stream', e, stackTrace));
    }
  }

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    try {
      // For web platform, use a web-specific compression approach
      if (kIsWeb) {
        _logger.d('[REPOSITORY] Compressing image on web platform');
        // Use image package for web compression
        final image = image_lib.decodeImage(bytes);
        if (image == null) {
          throw FirestoreException(
            message: 'Failed to decode image for compression',
            error: 'Image decoding returned null',
          );
        }

        // Resize if image is too large (max 2048px on longest side)
        var resized = image;
        if (image.width > 2048 || image.height > 2048) {
          final scale = 2048 / max(image.width, image.height);
          resized = image_lib.copyResize(
            image,
            width: (image.width * scale).round(),
            height: (image.height * scale).round(),
          );
        }

        // Encode with quality setting
        final compressed = image_lib.encodeJpg(resized, quality: 85);
        return Uint8List.fromList(compressed);
      }

      // For mobile platforms, use flutter_image_compress
      _logger.d('[REPOSITORY] Compressing image on mobile platform');
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 85,
        minHeight: 1024,
        minWidth: 1024,
      );

      if (result.isEmpty) {
        throw FirestoreException(
          message: 'Failed to compress image',
          error: 'Compression returned null or empty result',
        );
      }

      return result;
    } catch (e, stackTrace) {
      _logger.e('[REPOSITORY] Error compressing image',
          error: e, stackTrace: stackTrace);
      throw FirestoreException(
        message: 'Failed to compress image: ${e.toString()}',
        error: e,
      );
    }
  }

  Future<String> _getImageDownloadUrl(
      String userId, String journeyId, String fileName) async {
    try {
      // Use the same path structure as upload
      final storagePath = 'users/$userId/journeys/$journeyId/images/$fileName';
      _logger.d('[REPOSITORY] Getting download URL:');
      _logger.d('  - Storage path: $storagePath');

      final ref = _storage.ref().child(storagePath);
      _logger.d('  - Full ref path: ${ref.fullPath}');
      _logger.d('  - Bucket: ${ref.bucket}');

      try {
        // First check if the file exists and get its metadata
        final metadata = await ref.getMetadata();
        _logger.d('[REPOSITORY] File metadata:');
        _logger.d('  - Content type: ${metadata.contentType}');
        _logger.d('  - Created: ${metadata.timeCreated}');
        _logger.d('  - Custom metadata: ${metadata.customMetadata}');
      } catch (e) {
        _logger.e('[REPOSITORY] File does not exist in storage:', error: e);
        throw FirestoreException(
          message: 'Image file not found in storage: $storagePath',
          error: e,
        );
      }

      if (kIsWeb) {
        // For web platform, we need to ensure proper headers
        final downloadUrl = await ref.getDownloadURL();
        _logger.d('[REPOSITORY] Raw download URL: $downloadUrl');

        // Get the token for authenticated access
        final token = await _auth.currentUser?.getIdToken();

        // Create URL with token for authenticated access
        final uri = Uri.parse(downloadUrl);
        final newUri = uri.replace(queryParameters: {
          ...uri.queryParameters,
          if (token != null) 'token': token,
          'alt': 'media',
          'cache-control': 'no-cache',
        });

        final finalUrl = newUri.toString();
        _logger.d('[REPOSITORY] Modified download URL for web: $finalUrl');

        // Verify the URL is accessible
        try {
          final response = await http.head(Uri.parse(finalUrl));
          _logger.d('[REPOSITORY] URL verification:');
          _logger.d('  - Status code: ${response.statusCode}');
          _logger.d('  - Headers: ${response.headers}');

          if (response.statusCode != 200) {
            throw FirestoreException(
              message: 'Failed to verify image URL: ${response.statusCode}',
              error: 'HTTP ${response.statusCode}',
            );
          }
        } catch (e) {
          _logger.e('[REPOSITORY] Failed to verify URL:', error: e);
          // Don't throw here, still return the URL as it might work in the browser
        }

        return finalUrl;
      } else {
        // For mobile, use standard SDK method
        final downloadUrl = await ref.getDownloadURL();
        _logger.d('[REPOSITORY] SDK generated download URL: $downloadUrl');
        return downloadUrl;
      }
    } catch (e, stackTrace) {
      _logger.e('[REPOSITORY] Error getting download URL:',
          error: e, stackTrace: stackTrace);
      throw FirestoreException(
        message: 'Failed to generate download URL: $fileName',
        error: e,
      );
    }
  }

  @override
  Future<JourneyImageInfo> uploadJourneyImage(
    String journeyId,
    List<int> imageBytes,
    String fileName,
  ) async {
    final userId = _getCurrentUserId();
    // Generate a unique ID for the image document
    final imageId = const Uuid().v4();
    // Use the original fileName for storage, but prefix with timestamp to avoid collisions
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storageFileName = '${timestamp}_$fileName';

    // Ensure consistent paths between upload and download
    final storagePath =
        'users/$userId/journeys/$journeyId/images/$storageFileName';
    final firestorePath = 'users/$userId/journeys/$journeyId/images';

    _logger.d('[REPOSITORY] Upload paths:');
    _logger.d('  - Storage path: $storagePath');
    _logger.d('  - Firestore collection: $firestorePath');
    _logger.d('  - Image ID: $imageId');

    try {
      // Compress image data
      _logger.d('[REPOSITORY] Starting image compression...');
      final finalImageData =
          await _compressImage(Uint8List.fromList(imageBytes));
      _logger.d(
          '[REPOSITORY] Compression complete. Final size: ${finalImageData.length} bytes');

      // 1. Upload to Storage
      final storageRef = _storage.ref().child(storagePath);
      _logger.d('[REPOSITORY] Storage reference:');
      _logger.d('  - Full path: ${storageRef.fullPath}');
      _logger.d('  - Bucket: ${storageRef.bucket}');

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': userId,
          'journeyId': journeyId,
          'imageId': imageId,
          'originalFileName': fileName,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      // Upload the file
      UploadTask uploadTask;
      if (kIsWeb) {
        _logger.d('[REPOSITORY] Web platform, calling putBlob');
        final blob = html.Blob([finalImageData], 'image/jpeg');
        uploadTask = storageRef.putBlob(blob, metadata);
      } else {
        _logger.d('[REPOSITORY] Mobile platform, calling putData');
        uploadTask = storageRef.putData(finalImageData, metadata);
      }

      // Wait for upload to complete
      await uploadTask;
      _logger.i('[REPOSITORY] Storage upload successful');

      // 2. Get the download URL
      _logger.d('[REPOSITORY] Getting download URL...');
      final downloadUrl =
          await _getImageDownloadUrl(userId, journeyId, storageFileName);
      _logger.i('[REPOSITORY] Got download URL: $downloadUrl');

      // 3. Create Firestore document
      final now = DateTime.now();
      final imageInfo = JourneyImageInfo(
        id: imageId,
        url: downloadUrl,
        imagePath: storagePath, // Use the same path for consistency
        hasPotentialText: null,
        lastProcessedAt: null,
        detectedText: null,
        detectedTotalAmount: null,
        detectedCurrency: null,
        isInvoiceGuess: false,
      );

      _logger.d('[REPOSITORY] Creating Firestore document:');
      _logger.d('  - Collection: $firestorePath');
      _logger.d('  - Document ID: $imageId');

      final docData = {
        ...imageInfo.toJson(),
        'uploadedAt': FieldValue.serverTimestamp(),
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'storageRef': storagePath, // Add storage reference for verification
      };

      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('journeys')
          .doc(journeyId)
          .collection('images')
          .doc(imageId);

      await docRef.set(docData);
      _logger.i('[REPOSITORY] Firestore document created successfully');

      // Log final paths for verification
      _logger.d('[REPOSITORY] Final paths:');
      _logger.d('  - Storage: $storagePath');
      _logger.d('  - Firestore doc: ${docRef.path}');
      _logger.d('  - Download URL: $downloadUrl');

      return imageInfo;
    } catch (e, stackTrace) {
      _logger.e('[REPOSITORY] Error during upload process:',
          error: e, stackTrace: stackTrace);
      throw FirestoreException(
        message: 'Failed during upload process: ${e.toString()}',
        error: e,
      );
    }
  }

  @override
  Future<void> deleteJourneyImage(
      String journeyId, String imageId, String fileName) async {
    try {
      final userId = _getCurrentUserId();
      _logger.i(
          'Deleting image $fileName (ID: $imageId) from journey $journeyId for user $userId');

      // Construct the storage path
      final imagePath = 'users/$userId/journeys/$journeyId/images/$fileName';
      final imageRef = _storage.ref().child(imagePath);
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('journeys')
          .doc(journeyId)
          .collection('images')
          .doc(imageId);

      // Start with Firestore document deletion
      await docRef.delete();
      _logger.i('Firestore document for image $imageId deleted.');

      // Then attempt storage file deletion
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
    } on FirebaseException catch (e, stackTrace) {
      _logger.e('FirebaseException deleting image metadata: ${e.message}',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
          'Failed to delete image metadata: ${e.code}', e, stackTrace);
    } catch (e, stackTrace) {
      _logger.e('Unknown error deleting image',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
          'An unexpected error occurred while deleting the image.',
          e,
          stackTrace);
    }
  }

  @override
  Future<void> updateImageWithOcrResults(
    String journeyId,
    String imageId, {
    required bool hasText,
    String? detectedText,
    double? totalAmount,
    String? currency,
    bool? isInvoice,
    String? location,
  }) async {
    try {
      final userId = _getCurrentUserId();
      _logger.d('[REPOSITORY] Updating image $imageId with OCR results');

      // Reference to the image document
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('journeys')
          .doc(journeyId)
          .collection('images')
          .doc(imageId);

      // Prepare update data
      final now = DateTime.now();
      final updateData = {
        'hasPotentialText': hasText,
        'lastProcessedAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      // Add optional fields if they're provided
      if (detectedText != null) {
        updateData['detectedText'] = detectedText;
      }

      if (totalAmount != null) {
        updateData['detectedTotalAmount'] = totalAmount;
      }

      if (currency != null) {
        updateData['detectedCurrency'] = currency;
      }

      if (isInvoice != null) {
        updateData['isInvoiceGuess'] = isInvoice;
      }

      if (location != null) {
        updateData['location'] = location;
      }

      // Update the document
      await docRef.update(updateData);
      _logger.i(
          '[REPOSITORY] Successfully updated image $imageId with OCR results');
    } catch (e, stackTrace) {
      _logger.e('[REPOSITORY] Error updating image with OCR results:',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
        'Failed to update image with OCR results: ${e.toString()}',
        e,
        stackTrace,
      );
    }
  }
}
