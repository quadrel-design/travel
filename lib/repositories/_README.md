# Repositories Directory

This directory contains all the repository classes for the Travel application. These classes abstract data access operations and provide a clean API for fetching, storing, and manipulating data from various sources like Firebase.

## File Overview

### `auth_repository.dart`
Defines the abstract interface for authentication operations, including user sign-in, sign-up, sign-out, and password management. Provides a clean separation between authentication logic and concrete implementations.

### `firebase_auth_repository.dart`
Implements the `AuthRepository` interface using Firebase Authentication, handling user registration, email/password sign-in, Google sign-in, and account management functions with proper error handling and logging.

### `invoice_repository.dart`
Defines the abstract interface for invoice and project operations, including methods to fetch, create, update, and delete projects, as well as handling invoice images and analysis.

### `firestore_invoice_repository.dart`
Implements the `InvoiceRepository` interface using Firebase Firestore, managing the structure of projects, invoices, and related data in the database with comprehensive error handling.

### `expense_repository.dart`
Handles CRUD operations for expense data associated with invoices, including creating, updating, deleting, and streaming expense records from Firestore with proper user-based security.

### `repository_exceptions.dart`
Defines a set of custom exception classes for the repository layer, providing specific error types like `DatabaseFetchException`, `ImageUploadException`, and `NotAuthenticatedException` for better error handling throughout the app.

## Usage Example

```dart
// Example: Fetching user projects
final repository = ref.read(invoiceRepositoryProvider);
final projectsStream = repository.fetchUserProjects();

// Example: Creating a new expense
final expense = Expense(
  projectId: 'project123',
  title: 'Dinner',
  amount: 42.50,
  date: DateTime.now(),
  category: 'Food',
  paidBy: 'user123',
  sharedWith: ['user123', 'user456'],
);

try {
  final createdExpense = await expenseRepository.createExpense(
    'project123',
    'invoice456',
    expense
  );
  // Handle success
} on NotAuthenticatedException {
  // Handle authentication error
} on DatabaseOperationException catch (e) {
  // Handle database error
}
``` 