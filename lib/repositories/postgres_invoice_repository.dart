import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:logger/logger.dart';
import 'package:travel/models/invoice_image_process.dart';
import 'package:travel/models/project.dart';
import 'package:travel/repositories/invoice_images_repository.dart';
import 'package:travel/repositories/mixins/image_repository_mixin.dart';
import 'package:travel/repositories/mixins/project_repository_mixin.dart';
import 'package:travel/repositories/repository_exceptions.dart';
import 'package:travel/services/gcs_file_service.dart';
import 'package:travel/repositories/base_repository_contracts.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

class PostgresInvoiceImageRepository
    with ProjectRepositoryOperationsMixin, ImageRepositoryOperationsMixin
    implements
        BaseRepository,
        BaseRepositoryForImages,
        InvoiceImagesRepository {
  final firebase_auth.FirebaseAuth _auth;
  final Logger _logger;
  final GcsFileService _gcsFileService;
  final String _baseUrl;

  PostgresInvoiceImageRepository(this._auth, this._logger, this._gcsFileService,
      {String baseUrl = 'https://gcs-backend-213342165039.us-central1.run.app'})
      : _baseUrl = baseUrl;

  // --- Implementation of BaseRepository & BaseRepositoryForImages contract requirements ---
  @override
  Logger get logger => _logger;

  @override
  String get baseUrl => _baseUrl;

  @override
  GcsFileService get gcsFileService => _gcsFileService;

  @override
  String getCurrentUserId() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _logger.w(
          '[PostgresInvoiceRepoCore] Attempted to get user ID when no user was authenticated.');
      throw NotAuthenticatedException(
          'User not authenticated. Cannot get user ID.');
    }
    return currentUser.uid;
  }

  @override
  Future<String> getAuthToken() async {
    try {
      final token = await _auth.currentUser?.getIdToken(true); // Force refresh
      if (token == null) {
        _logger.e(
            '[PostgresInvoiceRepoCore] Failed to get auth token: currentUser or token is null.');
        throw NotAuthenticatedException(
            'Failed to get authentication token: Token is null.');
      }
      return token;
    } catch (e, stackTrace) {
      _logger.e('[PostgresInvoiceRepoCore] Error getting auth token',
          error: e, stackTrace: stackTrace);
      throw NotAuthenticatedException('Failed to get authentication token: $e');
    }
  }

  @override
  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getAuthToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // @override
  // Future<InvoiceImageProcess> uploadInvoiceImage(
  //     String projectId, Uint8List fileBytes, String fileName) async {
  //   final logger = _logger;
  //   final userId = getCurrentUserId();

  //   final imageFileId =
  //       '${DateTime.now().millisecondsSinceEpoch}_${p.basename(fileName)}';
  //   logger.d(
  //       '[PostgresInvoiceRepo] Uploading image $imageFileId for project $projectId');

  //   final gcsPath =
  //       'users/$userId/projects/$projectId/invoice_images/$imageFileId${p.extension(fileName)}';

  //   try {
  //     logger.d(
  //         '[PostgresInvoiceRepo] Attempting to upload to GCS at path: $gcsPath');

  //     await _gcsFileService.uploadFile(
  //       fileBytes: fileBytes,
  //       fileName: gcsPath,
  //       contentType: lookupMimeType(fileName) ?? 'application/octet-stream',
  //     );

  //     logger.d('[PostgresInvoiceRepo] GCS upload successful for $gcsPath');

  //     final String fileContentType =
  //         lookupMimeType(fileName) ?? 'application/octet-stream';
  //     final int fileSize = fileBytes.length;

  //     final Map<String, dynamic> requestBody = {
  //       'id': imageFileId,
  //       'imagePath': gcsPath,
  //       'uploaded_at': DateTime.now().toIso8601String(),
  //       'originalFilename': fileName,
  //       'contentType': fileContentType,
  //       'size': fileSize
  //     };

  //     logger.d(
  //         '[PostgresInvoiceRepo] Creating image record in DB with body: ${json.encode(requestBody)}');

  //     final headers = await getAuthHeaders();
  //     final response = await http.post(
  //       Uri.parse('$_baseUrl/api/projects/$projectId/images'),
  //       headers: {
  //         ...headers,
  //         'Content-Type': 'application/json'
  //       },
  //       body: json.encode(requestBody),
  //     );

  //     logger.d(
  //         '[PostgresInvoiceRepo] Create image record response: ${response.statusCode}');

  //     if (response.statusCode == 201) {
  //       final Map<String, dynamic> data = json.decode(response.body);
  //       logger.i(
  //           '[PostgresInvoiceRepo] Successfully uploaded and created record for image $imageFileId');
  //       return InvoiceImageProcess.fromJson({
  //         ...data,
  //         'projectId': projectId,
  //       });
  //     } else {
  //       logger.e(
  //           '[PostgresInvoiceRepo] Failed to create image record: ${response.statusCode} ${response.body}');
  //       try {
  //         logger.w(
  //             '[PostgresInvoiceRepo] Attempting to delete orphaned GCS file: $gcsPath');
  //         await _gcsFileService.deleteFile(fileName: gcsPath);
  //       } catch (gcsDeleteError) {
  //         logger.e(
  //             '[PostgresInvoiceRepo] Failed to delete orphaned GCS file $gcsPath',
  //             error: gcsDeleteError);
  //       }
  //       throw DatabaseOperationException(
  //         'Failed to create image record: HTTP ${response.statusCode}',
  //         response.body,
  //         StackTrace.current,
  //       );
  //     }
  //   } catch (e, stackTrace) {
  //     logger.e(
  //         '[PostgresInvoiceRepo] Error uploading image $fileName for project $projectId',
  //         error: e,
  //         stackTrace: stackTrace);
  //     if (e is ImageUploadException ||
  //         e is DatabaseOperationException ||
  //         e is ArgumentError) {
  //       rethrow;
  //     }
  //     throw RepositoryException(
  //       'Failed to upload image $fileName: $e',
  //       e,
  //       stackTrace,
  //     );
  //   }
  // }

  // Methods from ProjectRepositoryOperationsMixin (to be commented out)
  // Stream<List<Project>> fetchUserProjects() => throw UnimplementedError();
  // Future<List<Project>> _fetchUserProjectsOnce() => throw UnimplementedError();
  // Stream<Project?> getProjectStream(String projectId) => throw UnimplementedError();
  // Future<Project?> _getProjectOnce(String projectId) => throw UnimplementedError();
  // Future<Project> createProject(String title, String description) => throw UnimplementedError();
  // Future<Project> addProject(Project project) => throw UnimplementedError();
  // Future<void> updateProject(Project project) => throw UnimplementedError();
  // Future<void> deleteProject(String projectId) => throw UnimplementedError();

  // Methods from ImageRepositoryOperationsMixin (to be commented out)
  // Stream<List<InvoiceImageProcess>> getProjectImagesStream(String projectId) => throw UnimplementedError();
  // Future<void> deleteInvoiceImage(String projectId, String imageId) => throw UnimplementedError();
  // Future<void> updateImageWithOcrResults(
  //   String projectId,
  //   String imageId, {
  //   bool? isInvoice,
  //   Map<String, dynamic>? invoiceAnalysis,
  //   String? status,
  //   String? ocrText,
  // }) => throw UnimplementedError();
  // Future<void> updateImageWithAnalysisDetails(
  //   String projectId,
  //   String imageId, {
  //   required Map<String, dynamic> analysisData,
  //   required bool isInvoiceConfirmed,
  //   String? status,
  //   DateTime? invoiceDate,
  // }) => throw UnimplementedError();

  // Required by InvoiceImagesRepository interface if not provided by mixins
  @override
  Stream<List<Project>> fetchUserProjects() {
    // TODO: implement fetchUserProjects
    throw UnimplementedError();
  }

  @override
  Stream<Project?> getProjectStream(String projectId) {
    // TODO: implement getProjectStream
    throw UnimplementedError();
  }

  @override
  Future<Project> addProject(Project project) {
    // TODO: implement addProject
    throw UnimplementedError();
  }

  @override
  Future<void> updateProject(Project project) {
    // TODO: implement updateProject
    throw UnimplementedError();
  }

  @override
  Future<void> deleteProject(String projectId) {
    // TODO: implement deleteProject
    throw UnimplementedError();
  }

  @override
  Future<void> updateImageWithOcrResults(String projectId, String imageId,
      {bool? isInvoice,
      Map<String, dynamic>? invoiceAnalysis,
      String? status,
      String? ocrText}) {
    // TODO: implement updateImageWithOcrResults
    throw UnimplementedError();
  }

  @override
  Future<void> updateImageWithAnalysisDetails(String projectId, String imageId,
      {required Map<String, dynamic> analysisData,
      required bool isInvoiceConfirmed,
      String? status,
      DateTime? invoiceDate}) {
    // TODO: implement updateImageWithAnalysisDetails
    throw UnimplementedError();
  }

  @override
  Future<void> deleteInvoiceImage(String projectId, String imageId) {
    // TODO: implement deleteInvoiceImage
    throw UnimplementedError();
  }

  @override
  Future<InvoiceImageProcess> uploadInvoiceImage(
      String projectId, Uint8List fileBytes, String fileName) {
    // This was the one we modified before, needs to be implemented or stubbed if mixin is out
    throw UnimplementedError();
  }

  @override
  Stream<List<InvoiceImageProcess>> getProjectImagesStream(String projectId) {
    // TODO: implement getProjectImagesStream
    throw UnimplementedError();
  }
}
