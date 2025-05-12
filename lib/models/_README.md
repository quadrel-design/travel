# Models Directory

This directory contains all the data models for the Travel application. These models define the core domain entities, their properties, and serialization/deserialization methods.

## File Overview

### `user.dart`
Defines the `User` model representing an application user with authentication details, profile information, and project references. Includes methods for JSON serialization, validation, and project management.

### `project.dart`
Defines the `Project` model representing a travel project/trip with destination, dates, budget, and completion status. Supports JSON serialization and includes error handling for date parsing.

### `expense.dart`
Defines the `Expense` model for tracking financial expenses associated with a project, including amount, category, payment details, and expense sharing between users.

### `invoice_image_process.dart`
Defines the `InvoiceImageProcess` model for managing captured invoice images, their storage paths, OCR-extracted text, and analysis results from AI processing.

### `invoice_image_status.dart`
Defines the `InvoiceImageStatus` enum which tracks the processing status of invoice images through various stages: upload, OCR, analysis, and any error states.

## Usage Example

```dart
// Example: Creating a new expense
final expense = Expense(
  projectId: 'project123',
  title: 'Dinner',
  amount: 42.50,
  date: DateTime.now(),
  category: 'Food',
  paidBy: 'user123',
  sharedWith: ['user123', 'user456'],
  description: 'Team dinner'
);

// Example: Converting to JSON
final jsonData = expense.toJson();
``` 