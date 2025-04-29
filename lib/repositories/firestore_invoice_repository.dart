/// Firestore Invoice Repository Implementation
///
/// Provides a concrete implementation of the InvoiceRepository interface using
/// Firebase Firestore for database operations and Firebase Storage for image handling.
library;
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

import '../models/invoice_capture_process.dart';
import '../models/project.dart';
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
/// Implements the [InvoiceRepository] interface using Firebase services.
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
  CollectionReference<Map<String, dynamic>> _getProjectsCollection(
          String userId) =>
      _firestore.collection('users').doc(userId).collection('projects');

  CollectionReference<Map<String, dynamic>> _getInvoicesCollection(
          String userId, String projectId) =>
      _getProjectsCollection(userId).doc(projectId).collection('invoices');

  CollectionReference<Map<String, dynamic>> _getInvoiceImagesCollection(
          String userId, String projectId, String invoiceId) =>
      _getInvoicesCollection(userId, projectId)
          .doc(invoiceId)
          .collection('invoice_images');

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

  // --- Project Methods ---
  @override
  Stream<List<Project>> fetchUserProjects() {
    try {
      final userId = _getCurrentUserId();
      _logger.d('Setting up stream for user projects: $userId');

      return _getProjectsCollection(userId).snapshots().map((snapshot) {
        _logger.d(
            'Received project snapshot with ${snapshot.docs.length} documents.');
        return snapshot.docs
            .map((doc) {
              try {
                final data = doc.data();
                data['id'] = doc.id;
                return Project.fromMap(data);
              } catch (e) {
                _logger.e('Error parsing Project:', error: e);
                return null;
              }
            })
            .where((project) => project != null)
            .cast<Project>()
            .toList();
      }).handleError((error, stackTrace) {
        _logger.e('Error fetching user projects stream',
            error: error, stackTrace: stackTrace);
        throw DatabaseFetchException(
            'Failed to fetch projects: ${error.toString()}', error, stackTrace);
      });
    } catch (e, stackTrace) {
      _logger.e('Error creating projects stream',
          error: e, stackTrace: stackTrace);
      return Stream.error(DatabaseFetchException(
          'Failed to create projects stream: $e', e, stackTrace));
    }
  }

  @override
  Stream<Project?> getProjectStream(String projectId) {
    try {
      final userId = _getCurrentUserId();
      _logger.d(
          'Setting up stream for single project: $projectId for user $userId');

      return _getProjectsCollection(userId)
          .doc(projectId)
          .snapshots()
          .map((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          try {
            _logger.d('Received snapshot for project $projectId');
            final data = snapshot.data()!;
            data['id'] = snapshot.id;
            return Project.fromMap(data);
          } catch (e) {
            _logger.e('Error parsing Project:', error: e);
            return null;
          }
        } else {
          _logger.w('Project $projectId does not exist or has no data.');
          return null;
        }
      }).handleError((error, stackTrace) {
        _logger.e('Error fetching single project stream ($projectId)',
            error: error, stackTrace: stackTrace);
        throw DatabaseFetchException(
            'Failed to fetch project details: ${error.toString()}',
            error,
            stackTrace);
      });
    } catch (e, stackTrace) {
      _logger.e('Error creating project stream for $projectId',
          error: e, stackTrace: stackTrace);
      return Stream.error(DatabaseFetchException(
          'Failed to create project stream: $e', e, stackTrace));
    }
  }

  @override
  Future<Project> addProject(Project project) async {
    try {
      final userId = _getCurrentUserId();
      _logger.i('Adding project: ${project.title} for user: $userId');

      // Add user ID and timestamps if not already set
      final projectWithMeta = project.copyWith(
        userId: userId,
        // Add timestamps if the model supports it
      );

      final docRef =
          await _getProjectsCollection(userId).add(projectWithMeta.toJson());

      _logger.i('Project added with ID: ${docRef.id}');
      // Return the Project object with the new ID
      return projectWithMeta.copyWith(id: docRef.id);
    } on FirebaseException catch (e, stackTrace) {
      _logger.e('FirebaseException adding project: ${e.message}',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
          'Failed to add project: ${e.code}', e, stackTrace);
    } catch (e, stackTrace) {
      _logger.e('Unknown error adding project',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
          'An unexpected error occurred while adding the project.',
          e,
          stackTrace);
    }
  }

  @override
  Future<void> updateProject(Project project) async {
    try {
      final userId = _getCurrentUserId();
      _logger.d('Updating project ID: ${project.id} for user: $userId');

      // Prepare data, remove id and potentially user_id if handled by rules
      final projectData = project.toJson();
      projectData.remove('id');
      // Add updatedAt timestamp
      projectData['updatedAt'] = FieldValue.serverTimestamp();

      // Use Firestore update by document ID
      await _getProjectsCollection(userId).doc(project.id).update(projectData);

      _logger.i('Successfully updated project ID: ${project.id}');
    } on FirebaseException catch (e, stackTrace) {
      _logger.e('FirebaseException updating project ${project.id}',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
          'Failed to update project: ${e.message}', e, stackTrace);
    } on NotAuthenticatedException {
      // Re-throw specific exception
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error updating project ${project.id}',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
          'An unexpected error occurred while updating the project.',
          e,
          stackTrace);
    }
  }

  @override
  Future<void> deleteProject(String projectId) async {
    String userId =
        'unknown_user'; // Default for logging if user ID fetch fails
    try {
      userId = _getCurrentUserId();
      _logger
          .d('Attempting to delete project ID: $projectId for user: $userId');

      // --- 1. Delete associated images from Firebase Storage ---
      final storagePath = 'users/$userId/projects/$projectId/invoices';
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
        _logger.e('FirebaseException deleting project content $projectId',
            error: e, stackTrace: stackTrace);
        // Log error but continue with DB deletion
        _logger.w('Continuing with database deletion despite storage error.');
      }

      // --- 2. Delete the project record from Firestore ---
      _logger.d('Deleting project record ID: $projectId from database.');
      await _getProjectsCollection(userId).doc(projectId).delete();

      _logger.i(
          'Successfully deleted project ID: $projectId and associated data.');
    } on FirebaseException catch (e, stackTrace) {
      // Catch Firestore exceptions
      _logger.e('FirebaseException deleting project record $projectId',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
          'Failed to delete project record: ${e.message}', e, stackTrace);
    } on NotAuthenticatedException {
      // Re-throw specific exception
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error deleting project $projectId',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
          'An unexpected error occurred while deleting the project.',
          e,
          stackTrace);
    }
  }

  // --- Project Image Methods ---
  @override
  Stream<List<InvoiceCaptureProcess>> getInvoiceImagesStream(
      String projectId, String invoiceId) {
    try {
      final userId = _getCurrentUserId();
      if (projectId.isEmpty || invoiceId.isEmpty) {
        return Stream<List<InvoiceCaptureProcess>>.value([]);
      }
      final imagesCollection =
          _getInvoiceImagesCollection(userId, projectId, invoiceId)
              .orderBy('uploadedAt', descending: true);
      return imagesCollection.snapshots().map((snapshot) {
        print(
            '[REPO DEBUG] Firestore snapshot docs count: \\${snapshot.docs.length}');
        for (final doc in snapshot.docs) {
          print('[REPO DEBUG] Raw doc data: \\${doc.data()}');
        }
        return snapshot.docs
            .map((doc) {
              try {
                final data = doc.data();
                print('[REPO DEBUG] Parsing doc: \\${doc.id} data: \\${data}');
                data['id'] = doc.id;
                if (!data.containsKey('url') ||
                    !data.containsKey('imagePath')) {
                  print(
                      '[REPO DEBUG] Skipping doc \\${doc.id} due to missing url or imagePath');
                  return null;
                }
                final info = InvoiceCaptureProcess.fromJson(data);
                print('[REPO DEBUG] Parsed InvoiceCaptureProcess: \\${info}');
                return info.url.isNotEmpty && info.imagePath.isNotEmpty
                    ? info
                    : null;
              } catch (e) {
                print('[REPO DEBUG] Error parsing doc \\${doc.id}: \\${e}');
                return null;
              }
            })
            .where((info) => info != null)
            .cast<InvoiceCaptureProcess>()
            .toList();
      }).handleError((error, stackTrace) {
        print('[REPO DEBUG] Error in image stream: \\${error}');
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
      String userId, String projectId, String fileName) async {
    final storagePath =
        'users/$userId/projects/$projectId/invoices/main/invoice_images/$fileName';
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
    String projectId,
    Uint8List imageBytes,
    String fileName,
  ) async {
    final userId = _getCurrentUserId();
    final imageId = const Uuid().v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storageFileName = '${timestamp}_$fileName';
    final storagePath =
        'users/$userId/projects/$projectId/invoices/main/invoice_images/$storageFileName';

    try {
      // Compress image
      final compressedImage = await _compressImage(imageBytes);

      // Upload to storage
      final storageRef = _storage.ref().child(storagePath);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': userId,
          'projectId': projectId,
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
          await _getImageDownloadUrl(userId, projectId, storageFileName);

      // Create image info object
      final now = DateTime.now();
      final imageInfo = InvoiceCaptureProcess(
        id: imageId,
        url: downloadUrl,
        imagePath: storagePath,
        isInvoiceGuess: false,
        status: 'ready', // Set initial status to ready for scan
      );

      // Store in Firestore
      final docData = {
        ...imageInfo.toJson(),
        'uploadedAt': FieldValue.serverTimestamp(),
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'storageRef': storagePath,
        'status': 'ready', // Ensure status is set in Firestore
      };

      await _getInvoiceImagesCollection(userId, projectId, 'main')
          .doc(imageId)
          .set(docData);

      return imageInfo;
    } catch (e, stackTrace) {
      _logger.e('Error uploading image', error: e, stackTrace: stackTrace);
      throw FirestoreException(message: 'Failed to upload image', error: e);
    }
  }

  @override
  Future<void> deleteInvoiceImage(String projectId, String imageId) async {
    try {
      final userId = _getCurrentUserId();

      // Get the image document to find the storage path
      final imageDoc =
          await _getInvoiceImagesCollection(userId, projectId, imageId)
              .doc(imageId)
              .get();

      if (!imageDoc.exists) {
        throw DatabaseOperationException(
            'Image not found', null, StackTrace.current);
      }

      // Delete from storage first
      final imageInfo = InvoiceCaptureProcess.fromJson(imageDoc.data()!);
      await _storage.ref().child(imageInfo.imagePath).delete();

      // Then delete from Firestore
      await _getInvoiceImagesCollection(userId, projectId, imageId)
          .doc(imageId)
          .delete();
    } catch (e, stackTrace) {
      throw DatabaseOperationException('Failed to delete image', e, stackTrace);
    }
  }

  @override
  Future<void> updateImageWithOcrResults(
    String projectId,
    String imageId, {
    bool? isInvoice,
    String? status,
  }) async {
    try {
      final userId = _getCurrentUserId();

      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        if (isInvoice != null) 'is_invoice_guess': isInvoice,
        if (status != null) 'status': status,
      };

      await _getInvoiceImagesCollection(userId, projectId, imageId)
          .doc(imageId)
          .update(data);
    } catch (e, stackTrace) {
      throw DatabaseOperationException(
          'Failed to update OCR results', e, stackTrace);
    }
  }
}
