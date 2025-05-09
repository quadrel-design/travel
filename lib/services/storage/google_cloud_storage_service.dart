import 'dart:typed_data';
import 'package:google_cloud_storage/google_cloud_storage.dart';
import 'package:logger/logger.dart';
import 'storage_service.dart';

class GoogleCloudStorageService implements StorageService {
  final GoogleCloudStorage _storage;
  final String _bucketName;
  final Logger _logger;

  GoogleCloudStorageService({
    required GoogleCloudStorage storage,
    required String bucketName,
    required Logger logger,
  })  : _storage = storage,
        _bucketName = bucketName,
        _logger = logger;

  @override
  Future<String> uploadFile({
    required String path,
    required Uint8List data,
    required String contentType,
    Map<String, String>? metadata,
  }) async {
    try {
      final bucket = _storage.bucket(_bucketName);
      final blob = bucket.blob(path);

      await blob.writeBytes(
        data,
        contentType: contentType,
        metadata: metadata,
      );

      return await getDownloadUrl(path);
    } catch (e, stackTrace) {
      _logger.e('Error uploading file to Google Cloud Storage',
          error: e, stackTrace: stackTrace);
      throw StorageException('Failed to upload file: $e');
    }
  }

  @override
  Future<void> deleteFile(String path) async {
    try {
      final bucket = _storage.bucket(_bucketName);
      final blob = bucket.blob(path);
      await blob.delete();
    } catch (e, stackTrace) {
      _logger.e('Error deleting file from Google Cloud Storage',
          error: e, stackTrace: stackTrace);
      throw StorageException('Failed to delete file: $e');
    }
  }

  @override
  Future<String> getDownloadUrl(String path) async {
    try {
      final bucket = _storage.bucket(_bucketName);
      final blob = bucket.blob(path);
      return await blob.signedUrl(
        Duration(hours: 1), // URL expires in 1 hour
        method: 'GET',
      );
    } catch (e, stackTrace) {
      _logger.e('Error getting download URL from Google Cloud Storage',
          error: e, stackTrace: stackTrace);
      throw StorageException('Failed to get download URL: $e');
    }
  }

  @override
  Future<bool> fileExists(String path) async {
    try {
      final bucket = _storage.bucket(_bucketName);
      final blob = bucket.blob(path);
      return await blob.exists();
    } catch (e, stackTrace) {
      _logger.e('Error checking file existence in Google Cloud Storage',
          error: e, stackTrace: stackTrace);
      throw StorageException('Failed to check file existence: $e');
    }
  }

  @override
  Future<List<String>> listFiles(String path) async {
    try {
      final bucket = _storage.bucket(_bucketName);
      final blobs = await bucket.list(prefix: path);
      return blobs.map((blob) => blob.name).toList();
    } catch (e, stackTrace) {
      _logger.e('Error listing files in Google Cloud Storage',
          error: e, stackTrace: stackTrace);
      throw StorageException('Failed to list files: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getFileMetadata(String path) async {
    try {
      final bucket = _storage.bucket(_bucketName);
      final blob = bucket.blob(path);
      final metadata = await blob.metadata();
      return {
        'contentType': metadata.contentType,
        'size': metadata.size,
        'updated': metadata.updated,
        'metadata': metadata.metadata,
      };
    } catch (e, stackTrace) {
      _logger.e('Error getting file metadata from Google Cloud Storage',
          error: e, stackTrace: stackTrace);
      throw StorageException('Failed to get file metadata: $e');
    }
  }
}

class StorageException implements Exception {
  final String message;
  StorageException(this.message);

  @override
  String toString() => 'StorageException: $message';
}
