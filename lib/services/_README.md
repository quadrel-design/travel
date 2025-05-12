# Services Directory

This directory contains all the service classes for the Travel application. Services handle external API interactions, cloud services, and business logic that isn't directly tied to the UI or data persistence.

## File Overview

### `auth/auth_service.dart`
Defines the abstract interface for authentication operations with a custom User model and methods for sign-in, sign-up, sign-out, and user profile management.

### `auth/custom_auth_service.dart`
Implements the `AuthService` interface using JWT token-based authentication, handling token management, renewal, and API communication with a custom auth backend.

### `user_subscription_service.dart`
Manages the user's subscription status (pro/free) by interacting with Firebase Auth custom claims and a backend API, providing methods to get and toggle subscription status.

### `cloud_run_ocr_service.dart`
Provides methods to interact with OCR and analysis services hosted on Cloud Run, handling image scanning, text extraction, invoice analysis, and error management.

### `gcs_file_service.dart`
Facilitates file operations with Google Cloud Storage through backend APIs, including uploading files, generating signed URLs for download, and deleting files.

### `location_service.dart`
Integrates with Google Places API to provide location-related functionalities like location search suggestions, place details retrieval, and place ID lookup.

## Usage Example

```dart
// Example: Uploading a file to Google Cloud Storage
final gcsService = GcsFileService(backendBaseUrl: 'https://your-backend.com');
try {
  final gcsPath = await gcsService.uploadFile(
    fileBytes: imageBytes,
    fileName: 'receipts/invoice_${DateTime.now().millisecondsSinceEpoch}.jpg',
    contentType: 'image/jpeg',
  );
  
  // Get a publicly accessible URL
  final downloadUrl = await gcsService.getSignedDownloadUrl(fileName: gcsPath);
} catch (e) {
  print('Upload failed: $e');
}

// Example: Toggling subscription status
final subscriptionService = UserSubscriptionService();
try {
  final newStatus = await subscriptionService.toggleSubscription();
  print('Subscription updated to: $newStatus');
} catch (e) {
  print('Failed to update subscription: $e');
}
``` 