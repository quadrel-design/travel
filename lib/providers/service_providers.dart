import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../config/service_config.dart';
import '../services/gcs_file_service.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/custom_auth_service.dart';

// Logger Provider
final loggerProvider = Provider<Logger>((ref) {
  return Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );
});

// GCS File Service Provider
final gcsFileServiceProvider = Provider<GcsFileService>((ref) {
  return GcsFileService(
    backendBaseUrl: ServiceConfig.gcsApiBaseUrl,
  );
});

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  final logger = ref.watch(loggerProvider);

  return CustomAuthService(
    apiBaseUrl: ServiceConfig.authApiBaseUrl,
    logger: logger,
  );
});
