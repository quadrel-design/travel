class ServiceConfig {
  // Google Cloud Storage Configuration
  static const String gcsBucketName = 'splitbase-7ec0f.appspot.com';
  static const String gcsProjectId = 'splitbase-7ec0f';

  // Cloud Run URL for backend services
  // Using the us-central1 region for the invoice service
  static const String gcsApiBaseUrl =
      'https://gcs-backend-213342165039.us-central1.run.app';

  // NOTE: In production, these values should be retrieved from environment
  // variables or secure configuration rather than being hardcoded.

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
