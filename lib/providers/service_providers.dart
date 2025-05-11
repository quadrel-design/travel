import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../config/service_config.dart';
import '../services/gcs_file_service.dart';
import '../services/cloud_run_ocr_service.dart';

// Logger Provider
final loggerProvider = Provider<Logger>((ref) => Logger());

// GCS File Service Provider
final gcsFileServiceProvider = Provider<GcsFileService>((ref) {
  return GcsFileService(
    backendBaseUrl: ServiceConfig.gcsApiBaseUrl,
  );
});

// GCS OCR Service Provider
final cloudRunOcrServiceProvider = Provider<CloudRunOcrService>((ref) {
  final logger = ref.watch(loggerProvider);
  return CloudRunOcrService(
    logger: logger,
    baseUrl: ServiceConfig.gcsApiBaseUrl,
  );
});
