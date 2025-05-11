/// Firestore Invoice Repository Implementation
///
/// Provides a concrete implementation of the InvoiceRepository interface using
/// Firebase Firestore for database operations and Firebase Storage for image handling.
library;

import 'dart:async';
import 'dart:typed_data'; // Add this import for Uint8List
// dart:html is web-only, replaced by cross-platform alternative
// import 'dart:html' show MediaSource;
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as image_lib;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
// Conditionally import html only for web platform
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_storage/firebase_storage.dart'; // Remove this line
import 'package:logger/logger.dart';

// Conditionally import dart:html for web platform only
// ignore: avoid_web_libraries_in_flutter
// import 'dart:html' if (dart.library.html) 'package:flutter/foundation.dart'
//     as html;

import '../models/invoice_image_process.dart';
import '../models/project.dart';
import 'invoice_repository.dart';
import 'repository_exceptions.dart'; // Import custom exceptions
import 'package:travel/services/gcs_file_service.dart';

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
    this._auth,
    this._logger,
    this._gcsFileService,
  );

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Logger _logger;
  final GcsFileService _gcsFileService;

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

      // --- 1. Delete associated images from GCS ---
      final storagePath = 'users/$userId/projects/$projectId/invoices';
      _logger
          .d('Would delete files in storage path: $storagePath for deletion.');
      // TODO: Implement recursive deletion of all files in GCS for this project
      // This may require listing all image paths from Firestore and calling _gcsFileService.deleteFile for each

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
  Stream<List<InvoiceImageProcess>> getInvoiceImagesStream(
      String projectId, String invoiceId) {
    try {
      final userId = _getCurrentUserId();
      _logger.d(
          '[DEBUG] getInvoiceImagesStream: userId=$userId, projectId=$projectId, invoiceId=$invoiceId');
      if (projectId.isEmpty || invoiceId.isEmpty) {
        return Stream<List<InvoiceImageProcess>>.value([]);
      }
      final imagesCollection = _firestore
          .collection('users')
          .doc(userId)
          .collection('projects')
          .doc(projectId)
          .collection('invoices')
          .doc(invoiceId)
          .collection('invoice_images')
          .orderBy('uploadedAt', descending: true);

      _logger.d(
          '[DEBUG] Using Firestore path: users/$userId/projects/$projectId/invoices/$invoiceId/invoice_images');

      return imagesCollection.snapshots().asyncMap((snapshot) async {
        _logger.d(
            '[DEBUG] Received ${snapshot.docs.length} documents from Firestore');
        for (final doc in snapshot.docs) {
          _logger
              .d('[DEBUG] Raw Firestore doc: id=${doc.id}, data=${doc.data()}');
        }
        final futures = snapshot.docs.map((doc) async {
          try {
            final data = doc.data();
            data['id'] = doc.id;
            if (!data.containsKey('imagePath')) {
              _logger.w(
                  '[DEBUG] Skipping doc \${doc.id} due to missing imagePath');
              return null;
            }
            // Fetch latest analysis
            final analysis =
                await _getLatestAnalysis(userId, projectId, invoiceId, doc.id);
            data['invoiceAnalysis'] = analysis?['invoiceAnalysis'];
            return InvoiceImageProcess.fromJson(data);
          } catch (e) {
            _logger.e('[DEBUG] Error parsing doc ${doc.id}: $e');
            return null;
          }
        });
        final results = await Future.wait(futures);
        return results
            .where((info) => info != null)
            .cast<InvoiceImageProcess>()
            .toList();
      }).handleError((error, stackTrace) {
        _logger.e('[DEBUG] Error in stream:',
            error: error, stackTrace: stackTrace);
        throw DatabaseFetchException(
            'Failed to fetch images', error, stackTrace);
      });
    } catch (e, stackTrace) {
      _logger.e('[DEBUG] Error creating stream:',
          error: e, stackTrace: stackTrace);
      return Stream<List<InvoiceImageProcess>>.error(DatabaseFetchException(
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

  @override
  Future<InvoiceImageProcess> uploadInvoiceImage(
    String projectId,
    String invoiceId,
    Uint8List fileBytes,
    String fileName,
  ) async {
    final userId = _getCurrentUserId();
    final imageId = const Uuid().v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storageFileName = '${timestamp}_$fileName';
    final storagePath =
        'users/$userId/projects/$projectId/invoices/$invoiceId/invoice_images/$storageFileName';
    try {
      // Upload to GCS via backend
      await _gcsFileService.uploadFile(
        fileName: storagePath,
        fileBytes: fileBytes,
        contentType: 'image/jpeg',
      );

      final now = DateTime.now();
      final imageInfo = InvoiceImageProcess(
        id: imageId,
        url: '', // Do not store signed URL
        imagePath: storagePath,
        invoiceId: invoiceId,
        lastProcessedAt: now,
        location: null,
        invoiceAnalysis: null,
      );
      final docData = <String, dynamic>{
        ...imageInfo.toJson(),
        'uploadedAt': FieldValue.serverTimestamp(),
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'storageRef': storagePath,
      };
      await _getInvoiceImagesCollection(userId, projectId, invoiceId)
          .doc(imageId)
          .set(docData, SetOptions(merge: true));
      return imageInfo;
    } catch (e, stackTrace) {
      _logger.e('Error uploading image', error: e, stackTrace: stackTrace);
      throw FirestoreException(message: 'Failed to upload image', error: e);
    }
  }

  @override
  Future<void> deleteInvoiceImage(
      String projectId, String invoiceId, String imageId) async {
    try {
      final userId = _getCurrentUserId();
      final imagesCollection =
          _getInvoiceImagesCollection(userId, projectId, invoiceId);
      final imageDoc = await imagesCollection.doc(imageId).get();
      if (!imageDoc.exists) {
        throw DatabaseOperationException(
            'Image not found', null, StackTrace.current);
      }
      final imageInfo = InvoiceImageProcess.fromJson(imageDoc.data()!);
      // Delete from GCS via backend
      await _gcsFileService.deleteFile(fileName: imageInfo.imagePath);
      await imagesCollection.doc(imageId).delete();

      // Clean up: if this was the last image, delete the invoice doc itself
      final remainingImages = await imagesCollection.get();
      if (remainingImages.size == 0) {
        await _getInvoicesCollection(userId, projectId).doc(invoiceId).delete();
      }
    } catch (e, stackTrace) {
      throw DatabaseOperationException('Failed to delete image', e, stackTrace);
    }
  }

  @override
  Future<void> updateImageWithOcrResults(
    String projectId,
    String invoiceId,
    String imageId, {
    bool? isInvoice,
    Map<String, dynamic>? invoiceAnalysis,
  }) async {
    try {
      final userId = _getCurrentUserId();
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _getInvoiceImagesCollection(userId, projectId, invoiceId)
          .doc(imageId)
          .update(data);
      if (invoiceAnalysis != null) {
        await _getInvoiceImagesCollection(userId, projectId, invoiceId)
            .doc(imageId)
            .collection('analyses')
            .doc('latest')
            .set({
          'invoiceAnalysis': invoiceAnalysis,
          'updatedAt': FieldValue.serverTimestamp()
        }, SetOptions(merge: true));
      }
    } catch (e, stackTrace) {
      throw DatabaseOperationException(
          'Failed to update OCR results', e, stackTrace);
    }
  }

  // Helper to get the latest analysis for an image
  Future<Map<String, dynamic>?> _getLatestAnalysis(
      String userId, String projectId, String invoiceId, String imageId) async {
    final analysisDoc =
        await _getInvoiceImagesCollection(userId, projectId, invoiceId)
            .doc(imageId)
            .collection('analyses')
            .doc('latest')
            .get();
    return analysisDoc.exists ? analysisDoc.data() : null;
  }

  /// Returns a stream of all invoice images for all invoices in a project.
  @override
  Stream<List<InvoiceImageProcess>> getProjectImagesStream(String projectId) {
    try {
      final userId = _getCurrentUserId();
      _logger.d(
          '[DEBUG] getProjectImagesStream: userId=$userId, projectId=$projectId');
      final invoicesCollection = _getInvoicesCollection(userId, projectId);
      return invoicesCollection.snapshots().asyncMap((invoicesSnapshot) async {
        List<InvoiceImageProcess> allImages = [];
        for (final invoiceDoc in invoicesSnapshot.docs) {
          final invoiceId = invoiceDoc.id;
          final imagesCollection =
              invoicesCollection.doc(invoiceId).collection('invoice_images');
          final imagesSnapshot = await imagesCollection.get();
          allImages.addAll(imagesSnapshot.docs.map((doc) {
            try {
              final data = doc.data();
              data['id'] = doc.id;
              if (!data.containsKey('imagePath')) {
                _logger.w(
                    '[DEBUG] Skipping doc \${doc.id} due to missing imagePath');
                return null;
              }
              return InvoiceImageProcess.fromJson(data);
            } catch (e) {
              _logger.e('[DEBUG] Error parsing doc \${doc.id}: $e');
              return null;
            }
          }).whereType<InvoiceImageProcess>());
        }
        return allImages;
      }).handleError((error, stackTrace) {
        throw DatabaseFetchException(
            'Failed to fetch project images', error, stackTrace);
      });
    } catch (e, stackTrace) {
      return Stream<List<InvoiceImageProcess>>.error(DatabaseFetchException(
          'Failed to create project image stream', e, stackTrace));
    }
  }
}
