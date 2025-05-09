import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';
import '../services/storage/storage_service.dart';
import '../config/service_config.dart';

class StorageMigration {
  final FirebaseStorage _firebaseStorage;
  final StorageService _gcsStorage;
  final Logger _logger;

  StorageMigration({
    required FirebaseStorage firebaseStorage,
    required StorageService gcsStorage,
    required Logger logger,
  })  : _firebaseStorage = firebaseStorage,
        _gcsStorage = gcsStorage,
        _logger = logger;

  Future<void> migrateUserFiles(String userId) async {
    try {
      _logger.i('Starting migration for user: $userId');

      // Get all files from Firebase Storage
      final firebaseRefs = await _listAllFiles('users/$userId');

      for (final ref in firebaseRefs) {
        try {
          // Download file from Firebase
          final data = await ref.getData();
          if (data == null) {
            _logger.w('No data found for file: ${ref.fullPath}');
            continue;
          }

          // Get metadata
          final metadata = await ref.getMetadata();

          // Upload to Google Cloud Storage
          await _gcsStorage.uploadFile(
            path: ref.fullPath,
            data: data,
            contentType: metadata.contentType ?? 'application/octet-stream',
            metadata: metadata.customMetadata,
          );

          _logger.i('Successfully migrated file: ${ref.fullPath}');
        } catch (e, stackTrace) {
          _logger.e('Error migrating file: ${ref.fullPath}',
              error: e, stackTrace: stackTrace);
        }
      }

      _logger.i('Completed migration for user: $userId');
    } catch (e, stackTrace) {
      _logger.e('Error during migration for user: $userId',
          error: e, stackTrace: stackTrace);
      throw StorageMigrationException('Failed to migrate user files: $e');
    }
  }

  Future<List<Reference>> _listAllFiles(String path) async {
    final List<Reference> allFiles = [];
    final result = await _firebaseStorage.ref().child(path).listAll();

    // Add files from current directory
    allFiles.addAll(result.items);

    // Recursively process subdirectories
    for (final prefix in result.prefixes) {
      allFiles.addAll(await _listAllFiles(prefix.fullPath));
    }

    return allFiles;
  }
}

class StorageMigrationException implements Exception {
  final String message;
  StorageMigrationException(this.message);

  @override
  String toString() => 'StorageMigrationException: $message';
}
