import 'dart:typed_data'; // For Uint8List
import 'dart:async';

// Firebase Imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Remove Supabase import
// import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:logger/logger.dart'; // Import Logger
import '../models/invoice_image_process.dart';
import 'repository_exceptions.dart'; // Import custom exceptions
import '../models/project.dart';
import '../services/gcs_file_service.dart';

/// Interface for invoice-related operations
abstract class InvoiceRepository {
  /// Fetches a stream of all projects for the current user
  Stream<List<Project>> fetchUserProjects();

  /// Gets a stream for a specific project
  Stream<Project?> getProjectStream(String projectId);

  /// Gets a stream of images for a specific invoice in a project
  Stream<List<InvoiceImageProcess>> getInvoiceImagesStream(
      String projectId, String invoiceId);

  /// Adds a new project
  Future<Project> addProject(Project project);

  /// Updates an existing project
  Future<void> updateProject(Project project);

  /// Deletes a project
  Future<void> deleteProject(String projectId);

  /// Updates image info with OCR results
  Future<void> updateImageWithOcrResults(
    String projectId,
    String invoiceId,
    String imageId, {
    bool? isInvoice,
    Map<String, dynamic>? invoiceAnalysis,
  });

  /// Updates image info with full analysis details from Gemini
  Future<void> updateImageWithAnalysisDetails(
    String projectId,
    String invoiceId,
    String imageId, {
    required Map<String, dynamic> analysisData,
    required bool isInvoiceConfirmed,
    String?
        status, // Optional: to set a specific status like 'analysis_complete'
  });

  /// Deletes a project image
  Future<void> deleteInvoiceImage(
      String projectId, String invoiceId, String imageId);

  /// Uploads a project image
  Future<InvoiceImageProcess> uploadInvoiceImage(
    String projectId,
    String invoiceId,
    Uint8List fileBytes,
    String fileName,
  );

  /// Returns a stream of all invoice images for all invoices in a project.
  Stream<List<InvoiceImageProcess>> getProjectImagesStream(String projectId);
}

class ProjectRepositoryImpl implements InvoiceRepository {
  // --- Dependency Injection ---
  // Replace SupabaseClient with Firestore and Storage
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Logger _logger;
  final GcsFileService _gcsFileService;

  // Update constructor
  ProjectRepositoryImpl(
      this._firestore, this._auth, this._logger, this._gcsFileService);
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
  Future<void> updateProject(Project project) async {
    try {
      // Use user ID check primarily for logging or if rules aren't set up
      final userId = _getCurrentUserId();
      _logger.d('Updating project ID: ${project.id} for user: $userId');

      // Prepare data, remove id and potentially user_id if handled by rules
      final projectData = project.toJson();
      projectData.remove('id');
      // projectData.remove('user_id'); // Keep if needed for rules/queries
      // Consider adding an 'updatedAt' timestamp
      projectData['updatedAt'] = FieldValue.serverTimestamp();

      // Use Firestore update by document ID
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('projects')
          .doc(project.id)
          .collection('invoices')
          .doc(project.id)
          .update(projectData);

      _logger.i('Successfully updated project ID: ${project.id}');
    } on FirebaseException catch (e, stackTrace) {
      // Catch FirebaseException
      _logger.e('[PROJECT] Error updating project:',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
          // Use custom exception
          'Failed to update project: ${e.message}',
          e,
          stackTrace);
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
      final storagePath = 'users/$userId/projects/$projectId';
      _logger.d('Listing files in storage path: $storagePath for deletion.');

      try {
        // Remove: final listResult = await _gcsFileService.listFilesInDirectory(storagePath);

        // Delete all files concurrently
        // Remove: await Future.wait(fileRefsToDelete.map((ref) => _gcsFileService.deleteFile(fileName: ref.name!)));
        _logger.d('Storage files deleted.');
      } on FirebaseException catch (e, stackTrace) {
        _logger.e('FirebaseException deleting project content $projectId',
            error: e, stackTrace: stackTrace);
        throw ImageDeleteException(
            'Failed to delete images from storage: ${e.message}',
            e,
            stackTrace);
      }

      // --- 2. Delete the project record from Firestore ---
      _logger.d('Deleting project record ID: $projectId from database.');
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('projects')
          .doc(projectId)
          .delete();

      _logger.i(
          'Successfully deleted project ID: $projectId and associated data.');
    } on FirebaseException catch (e, stackTrace) {
      _logger.e('[PROJECT] Error deleting project:',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
          'Failed to delete project record: ${e.message}', e, stackTrace);
    } on NotAuthenticatedException {
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

  @override
  Stream<List<InvoiceImageProcess>> getInvoiceImagesStream(
      String projectId, String invoiceId) {
    final userId = _getCurrentUserId();
    print('[STREAM] Using userId: $userId');
    _logger.d(
        '[REPO STREAM] Creating image stream for project $projectId, invoice $invoiceId');
    try {
      final query = _firestore
          .collection('users')
          .doc(userId)
          .collection('projects')
          .doc(projectId)
          .collection('invoices')
          .doc(invoiceId)
          .collection('invoice_images');
      final stream = query.snapshots();
      return stream.map((querySnapshot) {
        _logger.d(
            '[REPO STREAM MAP] Stream emitted \\${querySnapshot.docs.length} docs for project $projectId, invoice $invoiceId');
        return querySnapshot.docs
            .map((doc) {
              try {
                final data = doc.data();
                print('Firestore image doc: $data');
                final info =
                    InvoiceImageProcess.fromJson(data).copyWith(id: doc.id);
                print('Parsed image info: $info');
                return info;
              } catch (e, stackTrace) {
                print('Error parsing image doc: $e');
                print('Stack trace: $stackTrace');
                return null;
              }
            })
            .where((item) => item != null)
            .cast<InvoiceImageProcess>()
            .toList();
      }).handleError((error, stackTrace) {
        _logger.e(
            '[REPO STREAM] Error in image stream for project $projectId, invoice $invoiceId',
            error: error,
            stackTrace: stackTrace);
        throw DatabaseFetchException(
            'Failed to fetch images: \\${error.toString()}', error, stackTrace);
      });
    } catch (e, stackTrace) {
      _logger.e(
          '[REPO STREAM] Error creating Firestore stream for project $projectId, invoice $invoiceId',
          error: e,
          stackTrace: stackTrace);
      return Stream.error(DatabaseFetchException(
          'Failed to create image stream: $e', e, stackTrace));
    }
  }

  @override
  Future<Project> addProject(Project project) async {
    final userId = _getCurrentUserId(); // Use helper
    _logger.i('Adding project: ${project.title} for user: $userId');
    try {
      // Add user ID and timestamps if not already set
      final projectWithMeta = project.copyWith(
        userId: userId,
        // createdAt: DateTime.now(), // Add if model supports it
        // updatedAt: DateTime.now(), // Add if model supports it
      );
      final docRef = await _firestore
          .collection('users')
          .doc(userId) // Use obtained userId
          .collection('projects')
          .doc(project.id)
          .collection('invoices')
          .add(projectWithMeta.toJson());
      _logger.i('Project added with ID: ${docRef.id}');
      // Return the Project object with the new ID
      return projectWithMeta.copyWith(id: docRef.id);
    } on FirebaseException catch (e, s) {
      _logger.e('FirebaseException adding project: ${e.message}',
          error: e, stackTrace: s);
      throw DatabaseOperationException(
          'Failed to add project: ${e.code}', e, s);
    } catch (e, s) {
      _logger.e('Unknown error adding project', error: e, stackTrace: s);
      throw DatabaseOperationException(
          'An unexpected error occurred while adding the project.', e, s);
    }
  }

  @override
  Stream<Project?> getProjectStream(String projectId) {
    final userId = _getCurrentUserId(); // Use helper
    _logger
        .d('Setting up stream for single project: $projectId for user $userId');
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('projects')
        .doc(projectId)
        .collection('invoices')
        .doc(projectId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        _logger.d('Received snapshot for project $projectId');
        return Project.fromJson(snapshot.data()!).copyWith(id: snapshot.id);
      } else {
        _logger.w('Project $projectId does not exist or has no data.');
        return null;
      }
    }).handleError((error, stackTrace) {
      _logger.e('[PROJECT] Error getting project by ID:',
          error: error, stackTrace: stackTrace);
      throw DatabaseFetchException(
          'Failed to fetch project details: ${error.toString()}',
          error,
          stackTrace);
    });
  }

  @override
  Future<InvoiceImageProcess> uploadInvoiceImage(String projectId,
      String invoiceId, Uint8List fileBytes, String fileName) async {
    final userId = _getCurrentUserId();
    _logger
        .i('Uploading image $fileName to project $projectId for user $userId');

    // Generate a unique image ID
    final imageId = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();

    final imagePath =
        'users/$userId/projects/$projectId/invoices/$invoiceId/invoice_images/$fileName';
    final imageRef =
        await _gcsFileService.getSignedDownloadUrl(fileName: imagePath);

    try {
      // Use correct constructor parameters for InvoiceImageProcess
      final imageInfo = InvoiceImageProcess(
        id: imageId,
        url: '',
        imagePath: imagePath,
        invoiceId: invoiceId,
        lastProcessedAt: now,
        location: null,
        invoiceAnalysis: null,
      );

      final docData = {
        ...imageInfo.toJson(),
        'uploadedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('projects')
          .doc(projectId)
          .collection('invoices')
          .doc(invoiceId)
          .collection('invoice_images')
          .doc(imageId)
          .set(docData, SetOptions(merge: true));

      _logger.i('Image metadata added to Firestore with ID: $imageId');
      return imageInfo;
    } catch (e, s) {
      _logger.e('Unknown error uploading image', error: e, stackTrace: s);
      throw ImageUploadException(
          'An unexpected error occurred while uploading the image.', e, s);
    }
  }

  @override
  Future<void> deleteInvoiceImage(
      String projectId, String invoiceId, String imageId) async {
    try {
      final userId = _getCurrentUserId();
      final imageDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('projects')
          .doc(projectId)
          .collection('invoices')
          .doc(invoiceId)
          .collection('invoice_images')
          .doc(imageId)
          .get();

      if (!imageDoc.exists) {
        throw DatabaseOperationException(
          'Image not found',
          null,
          StackTrace.current,
        );
      }

      final imageInfo = InvoiceImageProcess.fromJson(imageDoc.data()!);

      // Delete from Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('projects')
          .doc(projectId)
          .collection('invoices')
          .doc(invoiceId)
          .collection('invoice_images')
          .doc(imageId)
          .delete();

      _logger.i('Successfully deleted image $imageId from project $projectId');
    } catch (e, stackTrace) {
      _logger.e('Error deleting project image',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
        'Failed to delete project image: ${e.toString()}',
        e,
        stackTrace,
      );
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
      _logger
          .d('Updating image $imageId in project $projectId with OCR results');

      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('projects')
          .doc(projectId)
          .collection('invoices')
          .doc(invoiceId)
          .collection('invoice_images')
          .doc(imageId)
          .update(data);

      _logger.i(
          'Successfully updated OCR results for image $imageId in project $projectId');
    } catch (e, stackTrace) {
      _logger.e('Error updating image OCR results',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
        'Failed to update image OCR results: ${e.toString()}',
        e,
        stackTrace,
      );
    }
  }

  // --- Add Method to Delete Single Invoice Image ---
  Future<void> deleteSingleInvoiceImage(
      String projectId, String imageId, String imagePath) async {
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
        await _gcsFileService.deleteFile(fileName: imagePath);
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
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('projects')
          .doc(projectId)
          .collection('invoices')
          .doc(projectId)
          .collection('invoice_images')
          .doc(imageId)
          .delete();
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

  // --- End Method to Delete Single Invoice Image ---

  // Add new helpers for the new structure
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

  @override
  Stream<List<Project>> fetchUserProjects() {
    final userId = _getCurrentUserId();
    _logger.d('Setting up stream for user projects: $userId');
    return _getProjectsCollection(userId).snapshots().map((snapshot) {
      _logger.d(
          'Received project snapshot with ${snapshot.docs.length} documents.');
      return snapshot.docs
          .map((doc) => Project.fromJson(doc.data()).copyWith(id: doc.id))
          .toList();
    }).handleError((error, stackTrace) {
      _logger.e('[PROJECT] Error getting projects:',
          error: error, stackTrace: stackTrace);
      throw DatabaseFetchException(
          'Failed to fetch projects: ${error.toString()}', error, stackTrace);
    });
  }

  @override
  Stream<List<InvoiceImageProcess>> getProjectImagesStream(String projectId) {
    final userId = _getCurrentUserId();
    _logger.d('Setting up stream for project images: $projectId');
    final invoicesCollection = _getInvoicesCollection(userId, projectId);
    return invoicesCollection.snapshots().asyncMap((invoicesSnapshot) async {
      final allImages = <InvoiceImageProcess>[];
      for (final invoiceDoc in invoicesSnapshot.docs) {
        final invoiceId = invoiceDoc.id;
        final imagesCollection =
            _getInvoiceImagesCollection(userId, projectId, invoiceId);
        final imagesSnapshot = await imagesCollection.get();
        for (final doc in imagesSnapshot.docs) {
          try {
            final data = doc.data();
            data['id'] = doc.id;
            if (!data.containsKey('url') || !data.containsKey('imagePath')) {
              _logger.w(
                  '[DEBUG] Skipping doc ${doc.id} due to missing url or imagePath');
              continue;
            }
            allImages.add(InvoiceImageProcess.fromJson(data));
          } catch (e) {
            _logger.e('[DEBUG] Error parsing doc ${doc.id}: $e');
          }
        }
      }
      return allImages;
    }).handleError((error, stackTrace) {
      _logger.e('[PROJECT] Error getting project images:',
          error: error, stackTrace: stackTrace);
      throw DatabaseFetchException(
          'Failed to fetch project images: ${error.toString()}',
          error,
          stackTrace);
    });
  }

  @override
  Future<void> updateImageWithAnalysisDetails(
    String projectId,
    String invoiceId,
    String imageId, {
    required Map<String, dynamic> analysisData,
    required bool isInvoiceConfirmed,
    String?
        status, // Optional: to set a specific status like 'analysis_complete'
  }) async {
    // Implementation of updateImageWithAnalysisDetails method
  }
}
