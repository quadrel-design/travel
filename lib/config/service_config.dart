import 'package:flutter_dotenv/flutter_dotenv.dart';

class ServiceConfig {
  // Google Cloud Storage Configuration
  static const String gcsBucketName = 'splitbase-7ec0f.appspot.com';
  static const String gcsProjectId = 'splitbase-7ec0f';

  // Authentication Configuration
  static const String authApiBaseUrl =
      'https://splitbase-7ec0f.firebaseapp.com';
  static const int tokenExpirationHours = 24;

  // Storage Paths
  static String getUserStoragePath(String userId) => 'users/$userId';
  static String getProjectStoragePath(String userId, String projectId) =>
      '${getUserStoragePath(userId)}/projects/$projectId';
  static String getInvoiceStoragePath(
          String userId, String projectId, String invoiceId) =>
      '${getProjectStoragePath(userId, projectId)}/invoices/$invoiceId';
}
