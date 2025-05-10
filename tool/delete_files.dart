import 'dart:io';
import 'package:logger/logger.dart';
import '../lib/services/gcs_file_service.dart';

void main() async {
  final logger = Logger();
  final gcsService = GcsFileService(
    backendBaseUrl:
        'http://localhost:3000', // Update this with your backend URL
  );

  try {
    // Get the list of files to delete from command line arguments
    final filesToDelete =
        Platform.environment['FILES_TO_DELETE']?.split(',') ?? [];

    if (filesToDelete.isEmpty) {
      logger.w(
          'No files specified to delete. Set FILES_TO_DELETE environment variable with comma-separated file names.');
      exit(1);
    }

    logger.i('Starting file deletion...');

    for (final fileName in filesToDelete) {
      try {
        logger.i('Deleting file: $fileName');
        await gcsService.deleteFile(fileName: fileName);
        logger.i('Successfully deleted: $fileName');
      } catch (e) {
        logger.e('Failed to delete $fileName', error: e);
      }
    }

    logger.i('File deletion completed');
  } catch (e, stackTrace) {
    logger.e('Error during file deletion', error: e, stackTrace: stackTrace);
    exit(1);
  }
}
