// ignore_for_file: unused_field

import 'dart:async';
import 'dart:typed_data'; // Add this import for Uint8List
// dart:html is web-only, replaced by cross-platform alternative
// import 'dart:html' show MediaSource;
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as image_lib;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
// Removing unused http import
// import 'package:http/http.dart' as http;
// Conditionally import html only for web platform
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';

// Conditionally import dart:html for web platform only
// ignore: avoid_web_libraries_in_flutter
// import 'dart:html' if (dart.library.html) 'package:flutter/foundation.dart'
//     as html;

import '../models/journey.dart';
import '../models/invoice_capture_process.dart';
import 'invoice_repository.dart';
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

// Implementation of InvoiceRepository for Firebase/Firestore
class FirestoreInvoiceRepository implements InvoiceRepository {
  FirestoreInvoiceRepository(
    this._firestore,
    this._storage,
    this._auth,
    this._logger,
  );

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final Logger _logger;

  // Cache collection references to avoid recreating them
  CollectionReference<Map<String, dynamic>> _getUserJourneysCollection(
          String userId) =>
      _firestore.collection('users').doc(userId).collection('journeys');

  CollectionReference<Map<String, dynamic>> _getImagesCollection(
          String userId, String journeyId) =>
      _getUserJourneysCollection(userId).doc(journeyId).collection('images');

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

      return _getUserJourneysCollection(userId).snapshots().map((snapshot) {
        _logger.d(
            'Received journey snapshot with ${snapshot.docs.length} documents.');
        return snapshot.docs
            .map((doc) {
              try {
                final data = doc.data();
                data['id'] = doc.id;
                return Journey.fromMap(data);
              } catch (e) {
                _logger.e('Error parsing Journey:', error: e);
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

      return _getUserJourneysCollection(userId)
          .doc(journeyId)
          .snapshots()
          .map((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          try {
            _logger.d('Received snapshot for journey $journeyId');
            final data = snapshot.data()!;
            data['id'] = snapshot.id;
            return Journey.fromMap(data);
          } catch (e) {
            _logger.e('Error parsing Journey:', error: e);
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

      final docRef = await _getUserJourneysCollection(userId)
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
      await _getUserJourneysCollection(userId)
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
      await _getUserJourneysCollection(userId).doc(journeyId).delete();

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
  Stream<List<InvoiceCaptureProcess>> getInvoiceImagesStream(String journeyId) {
    try {
      final userId = _getCurrentUserId();
      if (journeyId.isEmpty) {
        return Stream<List<InvoiceCaptureProcess>>.value([]);
      }

      final journeyDoc = _getUserJourneysCollection(userId).doc(journeyId);

      return journeyDoc
          .get()
          .asStream()
          .asyncExpand<List<InvoiceCaptureProcess>>((journeySnapshot) {
        if (!journeySnapshot.exists) {
          return Stream<List<InvoiceCaptureProcess>>.value([]);
        }

        return _getImagesCollection(userId, journeyId)
            .orderBy('uploaded_at', descending: true)
            .snapshots()
            .map<List<InvoiceCaptureProcess>>((snapshot) {
          return snapshot.docs
              .map((doc) {
                try {
                  final data = doc.data();
                  data['id'] = doc.id;

                  if (!data.containsKey('url') ||
                      !data.containsKey('image_path')) {
                    return null;
                  }

                  final info = InvoiceCaptureProcess.fromJson(data);
                  return info.url.isNotEmpty && info.imagePath.isNotEmpty
                      ? info
                      : null;
                } catch (e) {
                  _logger.e('Error parsing image document', error: e);
                  return null;
                }
              })
              .where((info) => info != null)
              .cast<InvoiceCaptureProcess>()
              .toList();
        });
      }).handleError((error, stackTrace) {
        throw DatabaseFetchException(
            'Failed to fetch images', error, stackTrace);
      });
    } catch (e, stackTrace) {
      return Stream<List<InvoiceCaptureProcess>>.error(DatabaseFetchException(
          'Failed to create image stream', e, stackTrace));
    }
  }

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    try {
      if (kIsWeb) {
        final image = image_lib.decodeImage(bytes);
        if (image == null) {
          throw FirestoreException(
              message: 'Failed to decode image', error: null);
        }

        var resized = image;
        if (image.width > 2048 || image.height > 2048) {
          final scale = 2048 / max(image.width, image.height);
          resized = image_lib.copyResize(
            image,
            width: (image.width * scale).round(),
            height: (image.height * scale).round(),
          );
        }

        return Uint8List.fromList(image_lib.encodeJpg(resized, quality: 85));
      } else {
        final result = await FlutterImageCompress.compressWithList(
          bytes,
          quality: 85,
          minHeight: 1024,
          minWidth: 1024,
        );

        if (result.isEmpty) {
          throw FirestoreException(
              message: 'Failed to compress image', error: null);
        }

        return result;
      }
    } catch (e, stackTrace) {
      _logger.e('Error compressing image', error: e, stackTrace: stackTrace);
      throw FirestoreException(message: 'Failed to compress image', error: e);
    }
  }

  Future<String> _getImageDownloadUrl(
      String userId, String journeyId, String fileName) async {
    final storagePath = 'users/$userId/journeys/$journeyId/images/$fileName';
    final ref = _storage.ref().child(storagePath);

    try {
      await ref.getMetadata();

      if (kIsWeb) {
        final downloadUrl = await ref.getDownloadURL();
        final token = await _auth.currentUser?.getIdToken();

        final uri = Uri.parse(downloadUrl);
        final newUri = uri.replace(queryParameters: {
          ...uri.queryParameters,
          if (token != null) 'token': token,
          'alt': 'media',
          'cache-control': 'no-cache',
        });

        return newUri.toString();
      } else {
        return await ref.getDownloadURL();
      }
    } catch (e, stackTrace) {
      _logger.e('Error getting download URL', error: e, stackTrace: stackTrace);
      throw FirestoreException(
          message: 'Failed to generate download URL', error: e);
    }
  }

  @override
  Future<InvoiceCaptureProcess> uploadInvoiceImage(
    String journeyId,
    Uint8List imageBytes,
    String fileName,
  ) async {
    final userId = _getCurrentUserId();
    final imageId = const Uuid().v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storageFileName = '${timestamp}_$fileName';
    final storagePath =
        'users/$userId/journeys/$journeyId/images/$storageFileName';

    try {
      // Compress image
      final compressedImage = await _compressImage(imageBytes);

      // Upload to storage
      final storageRef = _storage.ref().child(storagePath);
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

      // Upload based on platform
      if (kIsWeb) {
        // For web platform, use putData instead
        await storageRef.putData(compressedImage, metadata);
      } else {
        await storageRef.putData(compressedImage, metadata);
      }

      // Get download URL
      final downloadUrl =
          await _getImageDownloadUrl(userId, journeyId, storageFileName);

      // Create image info object
      final now = DateTime.now();
      final imageInfo = InvoiceCaptureProcess(
        id: imageId,
        url: downloadUrl,
        imagePath: storagePath,
        hasPotentialText: null,
        lastProcessedAt: null,
        detectedText: null,
        detectedTotalAmount: null,
        detectedCurrency: null,
        isInvoiceGuess: false,
      );

      // Store in Firestore
      final docData = {
        ...imageInfo.toJson(),
        'uploaded_at': FieldValue.serverTimestamp(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'storage_ref': storagePath,
      };

      await _getImagesCollection(userId, journeyId).doc(imageId).set(docData);

      return imageInfo;
    } catch (e, stackTrace) {
      _logger.e('Error uploading image', error: e, stackTrace: stackTrace);
      throw FirestoreException(message: 'Failed to upload image', error: e);
    }
  }

  @override
  Future<void> deleteInvoiceImage(String journeyId, String imageId) async {
    try {
      final userId = _getCurrentUserId();

      // Get the image document to find the storage path
      final imageDoc =
          await _getImagesCollection(userId, journeyId).doc(imageId).get();

      if (!imageDoc.exists) {
        throw DatabaseOperationException(
            'Image not found', null, StackTrace.current);
      }

      // Delete from storage first
      final imageInfo = InvoiceCaptureProcess.fromJson(imageDoc.data()!);
      await _storage.ref().child(imageInfo.imagePath).delete();

      // Then delete from Firestore
      await _getImagesCollection(userId, journeyId).doc(imageId).delete();
    } catch (e, stackTrace) {
      throw DatabaseOperationException('Failed to delete image', e, stackTrace);
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
    String? status,
  }) async {
    try {
      final userId = _getCurrentUserId();

      final data = <String, dynamic>{
        'has_potential_text': hasText,
        'updated_at': FieldValue.serverTimestamp(),
        if (detectedText != null) 'detected_text': detectedText,
        if (totalAmount != null) 'detected_total_amount': totalAmount,
        if (currency != null) 'detected_currency': currency,
        if (isInvoice != null) 'is_invoice_guess': isInvoice,
        if (status != null) 'status': status,
      };

      await _getImagesCollection(userId, journeyId).doc(imageId).update(data);
    } catch (e, stackTrace) {
      throw DatabaseOperationException(
          'Failed to update OCR results', e, stackTrace);
    }
  }
}
