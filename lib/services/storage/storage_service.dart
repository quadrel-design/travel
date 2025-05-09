import 'dart:typed_data';

abstract class StorageService {
  /// Uploads a file to storage and returns the download URL
  Future<String> uploadFile({
    required String path,
    required Uint8List data,
    required String contentType,
    Map<String, String>? metadata,
  });

  /// Deletes a file from storage
  Future<void> deleteFile(String path);

  /// Gets a download URL for a file
  Future<String> getDownloadUrl(String path);

  /// Checks if a file exists
  Future<bool> fileExists(String path);

  /// Lists files in a directory
  Future<List<String>> listFiles(String path);

  /// Gets file metadata
  Future<Map<String, dynamic>> getFileMetadata(String path);
}
