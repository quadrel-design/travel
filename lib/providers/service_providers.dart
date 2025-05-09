import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';
import '../config/service_config.dart';
import '../services/storage/storage_service.dart';
import '../services/storage/google_cloud_storage_client.dart';
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

// Firebase Storage Provider
final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

// Storage Service Provider
final storageServiceProvider = Provider<StorageService>((ref) {
  final logger = ref.watch(loggerProvider);
  final storage = ref.watch(firebaseStorageProvider);

  return GoogleCloudStorageClient(
    storage: storage,
    logger: logger,
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
