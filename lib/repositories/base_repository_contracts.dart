import 'package:logger/logger.dart';
import 'package:travel/services/gcs_file_service.dart';
import 'dart:async'; // For Future

abstract class BaseRepository {
  Logger get logger;
  String get baseUrl;
  Future<Map<String, String>> getAuthHeaders();
  String getCurrentUserId();
  // Added getAuthToken here as it's used by both, directly or indirectly via getAuthHeaders
  // and ImageRepositoryOperationsMixin needs it directly.
  Future<String> getAuthToken();
}

abstract class BaseRepositoryForImages extends BaseRepository {
  // Extends BaseRepository, so it inherits logger, baseUrl, getAuthHeaders, getCurrentUserId, getAuthToken
  GcsFileService get gcsFileService;
  // getAuthToken is already in BaseRepository
}
