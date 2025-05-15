import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:travel/models/invoice_image_process.dart';
import 'package:travel/models/project.dart';
import 'package:travel/repositories/invoice_images_repository.dart';
import 'package:travel/repositories/repository_exceptions.dart';
import 'package:travel/services/gcs_file_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:path/path.dart' as p;
import 'package:mime/mime.dart';
import 'dart:async';

/// PostgreSQL implementation of the InvoiceImagesRepository interface
///
/// This implementation uses REST API calls to the backend server
/// which interacts with the PostgreSQL database. It replaces the
/// Firestore-based implementation with HTTP requests.
class PostgresInvoiceImageRepository implements InvoiceImagesRepository {
  final firebase_auth.FirebaseAuth _auth;
  final Logger _logger;
  final GcsFileService _gcsFileService;
  final String _baseUrl;

  PostgresInvoiceImageRepository(this._auth, this._logger, this._gcsFileService,
      {String baseUrl = 'https://gcs-backend-213342165039.us-central1.run.app'})
      : _baseUrl = baseUrl;

  String _getCurrentUserId() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw NotAuthenticatedException('User not authenticated');
    }
    return currentUser.uid;
  }

  Future<String> _getAuthToken() async {
    try {
      final token = await _auth.currentUser?.getIdToken() ?? '';
      return token;
    } catch (e) {
      _logger.e('Error getting auth token', error: e);
      throw NotAuthenticatedException('Failed to get authentication token');
    }
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getAuthToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  @override
  Stream<List<Project>> fetchUserProjects() {
    // Instead of a stream, we'll use a Future and convert it to a Stream
    // This will be refreshed when the UI calls for a refresh
    return Stream.fromFuture(_fetchUserProjectsOnce());
  }

  Future<List<Project>> _fetchUserProjectsOnce() async {
    final userId = _getCurrentUserId();
    _logger.d('Fetching projects for user: $userId');

    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/projects'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        _logger.e('Error fetching user projects: ${response.statusCode}',
            error: response.body);
        throw DatabaseFetchException(
          'Failed to fetch projects: HTTP ${response.statusCode}',
          null,
          StackTrace.current,
        );
      }

      final data = json.decode(response.body) as List<dynamic>;
      final projects = data.map((json) => Project.fromJson(json)).toList();

      _logger.d('Fetched ${projects.length} projects for user $userId');
      return projects;
    } catch (e, stackTrace) {
      _logger.e('Error fetching user projects',
          error: e, stackTrace: stackTrace);
      throw DatabaseFetchException(
        'Failed to fetch projects: $e',
        e,
        stackTrace,
      );
    }
  }

  @override
  Stream<Project?> getProjectStream(String projectId) {
    return Stream.fromFuture(_getProjectOnce(projectId));
  }

  Future<Project?> _getProjectOnce(String projectId) async {
    final userId = _getCurrentUserId();
    _logger.d('Fetching single project: $projectId for user $userId');

    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/projects/$projectId'),
        headers: headers,
      );

      if (response.statusCode == 404) {
        _logger.w('Project not found: $projectId');
        return null;
      }

      if (response.statusCode != 200) {
        _logger.e('Error fetching project: ${response.statusCode}',
            error: response.body);
        throw DatabaseFetchException(
          'Failed to fetch project: HTTP ${response.statusCode}',
          null,
          StackTrace.current,
        );
      }

      final data = json.decode(response.body);
      final project = Project.fromJson(data);

      _logger.d('Fetched project $projectId for user $userId');
      return project;
    } catch (e, stackTrace) {
      _logger.e('Error fetching single project',
          error: e, stackTrace: stackTrace);
      throw DatabaseFetchException(
        'Failed to fetch project: $e',
        e,
        stackTrace,
      );
    }
  }

  @override
  Stream<List<InvoiceImageProcess>> getProjectImagesStream(String projectId) {
    final userId = _getCurrentUserId();
    _logger.d(
        '[PostgresInvoiceRepo] Getting project images stream for project ID: $projectId, User ID: $userId');

    // Polling mechanism
    final controller = StreamController<List<InvoiceImageProcess>>();

    Future<void> fetchImages() async {
      if (controller.isClosed) return;
      try {
        final headers = await _getAuthHeaders();
        final response = await http.get(
          Uri.parse(
              '$_baseUrl/api/projects/$projectId/images'), // Use the endpoint for all project images
          headers: headers,
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final images = data
              .map((jsonItem) => InvoiceImageProcess.fromJson({
                    ...jsonItem as Map<String, dynamic>,
                    'projectId':
                        projectId, // Ensure projectId is part of the object
                    // 'invoiceId': jsonItem['invoiceId'] ?? '', // invoiceId is no longer expected from backend
                  }))
              .toList();
          if (!controller.isClosed) {
            controller.add(images);
          }
        } else {
          _logger.e(
              '[PostgresInvoiceRepo] Failed to fetch project images: ${response.statusCode} ${response.body}');
          if (!controller.isClosed) {
            controller.addError(DatabaseOperationException(
              'Failed to fetch project images: HTTP ${response.statusCode}',
            ));
          }
        }
      } catch (e, stackTrace) {
        _logger.e('[PostgresInvoiceRepo] Error fetching project images',
            error: e, stackTrace: stackTrace);
        if (!controller.isClosed) {
          controller.addError(DatabaseOperationException(
            'Error fetching project images: $e',
            e,
            stackTrace,
          ));
        }
      }
    }

    // Initial fetch
    fetchImages();

    // Set up periodic refresh
    final timer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (controller.isClosed) {
        timer.cancel();
        return;
      }
      fetchImages();
    });

    controller.onCancel = () {
      _logger.d(
          '[PostgresInvoiceRepo] Cancelling project images stream for $projectId');
      timer.cancel();
      controller.close();
    };

    return controller.stream;
  }

  @override
  Future<Project> createProject(String title, String description) async {
    final userId = _getCurrentUserId();
    _logger.d('Creating project for user: $userId');

    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/projects'),
        headers: headers,
        body: json.encode({
          'title': title,
          'description': description,
        }),
      );

      if (response.statusCode != 201) {
        _logger.e('Error creating project: ${response.statusCode}',
            error: response.body);
        throw DatabaseOperationException(
          'Failed to create project: HTTP ${response.statusCode}',
          null,
          StackTrace.current,
        );
      }

      final data = json.decode(response.body);
      final project = Project.fromJson(data);

      _logger.d('Created project ${project.id} for user $userId');
      return project;
    } catch (e, stackTrace) {
      _logger.e('Error creating project', error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
        'Failed to create project: $e',
        e,
        stackTrace,
      );
    }
  }

  @override
  Future<void> deleteProject(String projectId) async {
    final userId = _getCurrentUserId();
    _logger.d('Deleting project: $projectId for user $userId');

    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/projects/$projectId'),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        _logger.e('Error deleting project: ${response.statusCode}',
            error: response.body);
        throw DatabaseOperationException(
          'Failed to delete project: HTTP ${response.statusCode}',
          null,
          StackTrace.current,
        );
      }

      _logger.d('Deleted project $projectId for user $userId');
    } catch (e, stackTrace) {
      _logger.e('Error deleting project', error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
        'Failed to delete project: $e',
        e,
        stackTrace,
      );
    }
  }

  @override
  Future<InvoiceImageProcess> uploadInvoiceImage(
      String projectId, Uint8List fileBytes, String fileName) async {
    final userId = _getCurrentUserId();
    final logger = _logger;

    final imageId =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(fileName)}';
    logger.d(
        '[PostgresInvoiceRepo] Uploading image $imageId for project $projectId');

    final gcsPath =
        'users/$userId/projects/$projectId/invoice_images/$imageId${p.extension(fileName)}';

    try {
      logger.d(
          '[PostgresInvoiceRepo] Attempting to upload to GCS at path: $gcsPath');

      await _gcsFileService.uploadFile(
        fileBytes: fileBytes,
        fileName: gcsPath,
        contentType: lookupMimeType(fileName) ?? 'application/octet-stream',
      );

      logger.d('[PostgresInvoiceRepo] GCS upload successful for $gcsPath');

      final String fileContentType =
          lookupMimeType(fileName) ?? 'application/octet-stream';
      final int fileSize = fileBytes.length;

      final Map<String, dynamic> requestBody = {
        'id': imageId,
        'project_id': projectId,
        'imagePath': gcsPath,
        'uploaded_at': DateTime.now().toIso8601String(),
        'originalFilename': fileName,
        'contentType': fileContentType,
        'size': fileSize
      };

      logger.d(
          '[PostgresInvoiceRepo] Creating image record in DB with body: ${json.encode(requestBody)}');

      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/projects/$projectId/images'),
        headers: headers,
        body: json.encode(requestBody),
      );

      logger.d(
          '[PostgresInvoiceRepo] Create image record response: ${response.statusCode}');

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        logger.i(
            '[PostgresInvoiceRepo] Successfully uploaded and created record for image $imageId');
        return InvoiceImageProcess.fromJson({
          ...data,
          'projectId': projectId,
        });
      } else {
        logger.e(
            '[PostgresInvoiceRepo] Failed to create image record: ${response.statusCode} ${response.body}');
        try {
          logger.w(
              '[PostgresInvoiceRepo] Attempting to delete orphaned GCS file: $gcsPath');
          await _gcsFileService.deleteFile(fileName: gcsPath);
        } catch (gcsDeleteError) {
          logger.e(
              '[PostgresInvoiceRepo] Failed to delete orphaned GCS file $gcsPath',
              error: gcsDeleteError);
        }
        throw DatabaseOperationException(
          'Failed to create image record: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }
    } catch (e, stackTrace) {
      logger.e('[PostgresInvoiceRepo] Error uploading image $fileName',
          error: e, stackTrace: stackTrace);
      if (e is ImageUploadException || e is DatabaseOperationException) {
        rethrow;
      }
      throw RepositoryException(
        'Failed to upload image $fileName: $e',
        e,
        stackTrace,
      );
    }
  }

  @override
  Future<void> deleteInvoiceImage(String projectId, String imageId) async {
    final userId = _getCurrentUserId();
    _logger.d(
        '[PostgresInvoiceRepo] Deleting image $imageId from project $projectId');

    try {
      final headers = await _getAuthHeaders();
      final deleteResponse = await http.delete(
        Uri.parse('$_baseUrl/api/projects/$projectId/images/$imageId'),
        headers: headers,
      );

      if (deleteResponse.statusCode != 204) {
        _logger.e(
            '[PostgresInvoiceRepo] Error deleting image from DB: ${deleteResponse.statusCode} ${deleteResponse.body}');
        throw DatabaseOperationException(
          'Failed to delete image record from DB: HTTP ${deleteResponse.statusCode}',
          deleteResponse.body,
          StackTrace.current,
        );
      }

      _logger.d(
          '[PostgresInvoiceRepo] Deleted image $imageId from DB for project $projectId');
    } catch (e, stackTrace) {
      _logger.e('[PostgresInvoiceRepo] Error deleting image',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
        'Failed to delete image: $e',
        e,
        stackTrace,
      );
    }
  }

  @override
  Future<void> updateImageWithOcrResults(
    String projectId,
    String imageId, {
    bool? isInvoice,
    Map<String, dynamic>? invoiceAnalysis,
  }) async {
    final userId = _getCurrentUserId();
    _logger.i(
        '[PostgresInvoiceRepo] Updating OCR results for image $imageId in project $projectId');

    try {
      final Map<String, dynamic> updateData = {
        'lastProcessedAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (isInvoice != null) {
        updateData['isInvoiceGuess'] = isInvoice;
      }

      if (invoiceAnalysis != null) {
        updateData['invoiceAnalysis'] = invoiceAnalysis;
      }

      final headers = await _getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$_baseUrl/api/projects/$projectId/images/$imageId/ocr'),
        headers: headers,
        body: json.encode(updateData),
      );

      if (response.statusCode != 200) {
        _logger.e(
            '[PostgresInvoiceRepo] Error updating OCR results: ${response.statusCode}',
            error: response.body);
        throw DatabaseOperationException(
          'Failed to update OCR results: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }

      _logger.i(
          '[PostgresInvoiceRepo] Successfully updated OCR results for image $imageId');
    } catch (e, stackTrace) {
      _logger.e('[PostgresInvoiceRepo] Error updating OCR results',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
        'Failed to update OCR results: $e',
        e,
        stackTrace,
      );
    }
  }

  @override
  Future<void> updateImageWithAnalysisDetails(
    String projectId,
    String imageId, {
    required Map<String, dynamic> analysisData,
    required bool isInvoiceConfirmed,
    String? status,
  }) async {
    final userId = _getCurrentUserId();
    _logger.i(
        '[PostgresInvoiceRepo] Updating analysis details for image $imageId in project $projectId');

    try {
      final Map<String, dynamic> updateData = {
        'invoiceAnalysis': analysisData,
        'isInvoiceGuess': isInvoiceConfirmed,
        'lastProcessedAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (status != null) {
        updateData['status'] = status;
      } else {
        updateData['status'] = isInvoiceConfirmed
            ? 'analysis_complete_invoice'
            : 'analysis_complete_not_invoice';
      }

      if (analysisData.containsKey('date') && analysisData['date'] is String) {
        final DateTime? parsedDate =
            DateTime.tryParse(analysisData['date'] as String);
        if (parsedDate != null) {
          updateData['invoiceDate'] = parsedDate.toIso8601String();
        }
      }

      final headers = await _getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$_baseUrl/api/projects/$projectId/images/$imageId/analysis'),
        headers: headers,
        body: json.encode(updateData),
      );

      if (response.statusCode != 200) {
        _logger.e(
            '[PostgresInvoiceRepo] Error updating analysis details: ${response.statusCode}',
            error: response.body);
        throw DatabaseOperationException(
          'Failed to update analysis details: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }

      _logger.i(
          '[PostgresInvoiceRepo] Successfully updated analysis details for image $imageId');
    } catch (e, stackTrace) {
      _logger.e('[PostgresInvoiceRepo] Error updating analysis details',
          error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
        'Failed to update analysis details: $e',
        e,
        stackTrace,
      );
    }
  }

  @override
  Future<Project> addProject(Project project) async {
    final userId = _getCurrentUserId();
    _logger.d('Adding project for user: $userId');

    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/projects'),
        headers: headers,
        body: json.encode(project.toJson()),
      );

      if (response.statusCode != 201) {
        _logger.e('Error adding project: ${response.statusCode}',
            error: response.body);
        throw DatabaseOperationException(
          'Failed to add project: HTTP ${response.statusCode}',
          null,
          StackTrace.current,
        );
      }

      final data = json.decode(response.body);
      final createdProject = Project.fromJson(data);

      _logger.d('Added project ${createdProject.id} for user $userId');
      return createdProject;
    } catch (e, stackTrace) {
      _logger.e('Error adding project', error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
        'Failed to add project: $e',
        e,
        stackTrace,
      );
    }
  }

  @override
  Future<void> updateProject(Project project) async {
    final userId = _getCurrentUserId();
    final projectId = project.id;
    _logger.d('Updating project: $projectId for user $userId');

    try {
      final headers = await _getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$_baseUrl/api/projects/$projectId'),
        headers: headers,
        body: json.encode(project.toJson()),
      );

      if (response.statusCode != 200) {
        _logger.e('Error updating project: ${response.statusCode}',
            error: response.body);
        throw DatabaseOperationException(
          'Failed to update project: HTTP ${response.statusCode}',
          null,
          StackTrace.current,
        );
      }

      _logger.d('Updated project $projectId for user $userId');
    } catch (e, stackTrace) {
      _logger.e('Error updating project', error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
        'Failed to update project: $e',
        e,
        stackTrace,
      );
    }
  }
}
