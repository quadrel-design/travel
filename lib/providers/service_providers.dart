import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../config/service_config.dart';
import '../services/gcs_file_service.dart';
import '../services/cloud_run_ocr_service.dart';
import '../services/invoice_processing_service.dart';

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

// Invoice Processing Service Provider
final invoiceProcessingServiceProvider =
    Provider<InvoiceProcessingService>((ref) {
  return InvoiceProcessingService(ref);
});

/// Provider to get a signed GCS download URL for a given image path.
/// It caches the Future based on the imagePath.
final signedUrlProvider =
    FutureProvider.autoDispose.family<String, String>((ref, imagePath) async {
  if (imagePath.isEmpty) {
    // Or throw an error, or return a specific placeholder for errors
    return '';
  }
  final gcsService = ref.read(gcsFileServiceProvider);
  // The Future itself is cached by Riverpod per imagePath.
  // If the URL can expire and you need to force refresh after some time,
  // more complex logic would be needed (e.g., using a custom StreamProvider
  // or managing expiry times explicitly). For now, this relies on Riverpod's
  // default Future caching and autoDispose behavior.
  return gcsService.getSignedDownloadUrl(fileName: imagePath);
});
