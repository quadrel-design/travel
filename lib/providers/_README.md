# Providers Directory

This directory contains all the [Riverpod](https://riverpod.dev/) providers for the Travel application. Providers are responsible for managing application state and connecting the UI to data sources and services.

## File Overview

### `user_subscription_provider.dart`
Manages user subscription status (pro/free) stored in Firebase Auth claims, providing reactivity and toggling capabilities throughout the app.

### `repository_providers.dart`
Central access point for data repositories, Firebase services, and stream providers for reactive data access. Contains providers for Firestore, Auth, and various repositories.

### `logging_provider.dart`
Provides a configured logger instance for consistent application-wide logging with appropriate log levels based on environment.

### `journey_form_provider.dart`
Manages state for journey creation and editing forms, including loading states, validation, error handling, and CRUD operations.

### `project_form_provider.dart`
Handles state management for project creation and editing forms, with loading indicators, error messages, and form submission logic.

### `invoice_capture_provider.dart`
Manages invoice image capture, OCR processing, and analysis state, including processing status, errors, and results.

### `service_providers.dart`
Provides access to application services like file uploads, API clients, and other utility services needed throughout the app.

## Usage Example

```dart
// Example: Reading the user's subscription status
final subscription = ref.watch(userSubscriptionProvider);
if (subscription == 'pro') {
  // Show pro features
}

// Example: Toggling subscription
ref.read(userSubscriptionProvider.notifier).toggle();
``` 