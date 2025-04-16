/// Base class for repository-related exceptions.
class RepositoryException implements Exception {
  final String message;
  final dynamic originalException;
  final StackTrace? stackTrace;

  RepositoryException(this.message, [this.originalException, this.stackTrace]);

  @override
  String toString() {
    String result = 'RepositoryException: $message';
    if (originalException != null) {
      result += '\nOriginal Exception: ${originalException.toString()}';
    }
    if (stackTrace != null) {
      // Optionally include stack trace if needed for debugging, but be careful exposing it
      // result += '\nStack Trace:\n$stackTrace';
    }
    return result;
  }
}

/// Exception for errors during image upload.
class ImageUploadException extends RepositoryException {
  ImageUploadException(String message, [dynamic originalException, StackTrace? stackTrace])
      : super('Image Upload Failed: $message', originalException, stackTrace);
}

/// Exception for errors during image deletion.
class ImageDeleteException extends RepositoryException {
  ImageDeleteException(String message, [dynamic originalException, StackTrace? stackTrace])
      : super('Image Deletion Failed: $message', originalException, stackTrace);
}

/// Exception for errors adding image references to the database.
class AddImageReferenceException extends RepositoryException {
  AddImageReferenceException(String message, [dynamic originalException, StackTrace? stackTrace])
      : super('Add Image Reference Failed: $message', originalException, stackTrace);
}

/// Exception for general database fetch errors.
class DatabaseFetchException extends RepositoryException {
  DatabaseFetchException(String message, [dynamic originalException, StackTrace? stackTrace])
      : super('Database Fetch Failed: $message', originalException, stackTrace);
}

/// Exception for general database operation errors (insert, update, delete).
class DatabaseOperationException extends RepositoryException {
  DatabaseOperationException(String message, [dynamic originalException, StackTrace? stackTrace])
      : super('Database Operation Failed: $message', originalException, stackTrace);
}

/// Exception when user is not authenticated for an operation.
class NotAuthenticatedException extends RepositoryException {
  NotAuthenticatedException(String message)
      : super('User Not Authenticated: $message');
} 