import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';
import 'storage_service.dart';

class GoogleCloudStorageClient implements StorageService {
  final FirebaseStorage _storage;
  final Logger _logger;

  GoogleCloudStorageClient({
    required FirebaseStorage storage,
    required Logger logger,
  })  : _storage = storage,
        _logger = logger;

  @override
  Future<String> uploadFile({
    required String path,
    required Uint8List data,
    required String contentType,
    Map<String, String>? metadata,
  }) async {
    try {
      final ref = _storage.ref().child(path);
      final settableMetadata = SettableMetadata(
        contentType: contentType,
        customMetadata: metadata,
      );

      await ref.putData(data, settableMetadata);
      return await ref.getDownloadURL();
    } catch (e, stackTrace) {
      _logger.e('Error uploading file to Google Cloud Storage',
          error: e, stackTrace: stackTrace);
      throw StorageException('Failed to upload file: $e');
    }
  }

  @override
  Future<void> deleteFile(String path) async {
    try {
      final ref = _storage.ref().child(path);
      await ref.delete();
    } catch (e, stackTrace) {
      _logger.e('Error deleting file from Google Cloud Storage',
          error: e, stackTrace: stackTrace);
      throw StorageException('Failed to delete file: $e');
    }
  }

  @override
  Future<String> getDownloadUrl(String path) async {
    try {
      final ref = _storage.ref().child(path);
      return await ref.getDownloadURL();
    } catch (e, stackTrace) {
      _logger.e('Error getting download URL from Google Cloud Storage',
          error: e, stackTrace: stackTrace);
      throw StorageException('Failed to get download URL: $e');
    }
  }

  @override
  Future<bool> fileExists(String path) async {
    try {
      final ref = _storage.ref().child(path);
      try {
        await ref.getMetadata();
        return true;
      } catch (e) {
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('Error checking file existence in Google Cloud Storage',
          error: e, stackTrace: stackTrace);
      throw StorageException('Failed to check file existence: $e');
    }
  }

  @override
  Future<List<String>> listFiles(String path) async {
    try {
      final ref = _storage.ref().child(path);
      final result = await ref.listAll();
      return result.items.map((item) => item.fullPath).toList();
    } catch (e, stackTrace) {
      _logger.e('Error listing files in Google Cloud Storage',
          error: e, stackTrace: stackTrace);
      throw StorageException('Failed to list files: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getFileMetadata(String path) async {
    try {
      final ref = _storage.ref().child(path);
      final metadata = await ref.getMetadata();
      return {
        'contentType': metadata.contentType,
        'size': metadata.size,
        'updated': metadata.updated,
        'metadata': metadata.customMetadata,
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
