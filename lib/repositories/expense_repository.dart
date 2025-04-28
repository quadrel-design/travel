/// Expense Repository
///
/// Defines the repository for managing expense data associated with invoices,
/// interacting with Firebase Firestore.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:travel/models/expense.dart';
import 'package:travel/repositories/repository_exceptions.dart';

/// Repository class for handling expense CRUD operations in Firestore.
class ExpenseRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Logger _logger;

  /// Creates an instance of [ExpenseRepository].
  /// Requires instances of [FirebaseFirestore], [FirebaseAuth], and [Logger].
  ExpenseRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required Logger logger,
  })  : _firestore = firestore,
        _auth = auth,
        _logger = logger;

  // Helper to get current user ID, throws NotAuthenticatedException if null
  String _getCurrentUserId() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _logger.e('User ID is null, operation requires authentication.');
      throw NotAuthenticatedException(
          'User must be logged in to perform this operation.');
    }
    return userId;
  }

  // Helper to get the expenses subcollection reference
  CollectionReference<Map<String, dynamic>> _getExpensesCollection(
      String userId, String invoiceId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('invoices')
        .doc(invoiceId)
        .collection('expenses');
  }

  /// Creates a new expense document in Firestore under a specific invoice.
  ///
  /// Parameters:
  ///  - [invoiceId]: The ID of the invoice this expense belongs to.
  ///  - [expense]: The [Expense] object to create.
  ///
  /// Returns the created [Expense] object with its Firestore ID.
  /// Throws [DatabaseOperationException] on failure.
  /// Throws [NotAuthenticatedException] if the user is not logged in.
  Future<Expense> createExpense(String invoiceId, Expense expense) async {
    final userId = _getCurrentUserId();
    _logger.i('Creating expense for invoice $invoiceId, user $userId');
    try {
      // Prepare data, ensuring user ID is set if model expects it
      final dataToSave = expense.toJson();
      // Explicitly set userId if model doesn't handle it automatically
      // dataToSave['userId'] = userId;
      // Add created_at/updated_at if model doesn't handle them
      // dataToSave['createdAt'] = FieldValue.serverTimestamp();
      dataToSave['updatedAt'] = FieldValue.serverTimestamp();

      final docRef =
          await _getExpensesCollection(userId, invoiceId).add(dataToSave);

      _logger.i('Expense created with ID: ${docRef.id}');
      // Fetch the created doc to return the full object with server timestamp
      final newDoc = await docRef.get();
      return Expense.fromJson({...newDoc.data()!, 'id': newDoc.id});
    } on FirebaseException catch (e, stackTrace) {
      _logger.e(
        '[EXPENSE] FirebaseException creating expense for invoice $invoiceId:',
        error: e,
        stackTrace: stackTrace,
      );
      throw DatabaseOperationException(
          'Failed to create expense: ${e.message}', e, stackTrace);
    } catch (e, stackTrace) {
      _logger.e(
        '[EXPENSE] Error creating expense for invoice $invoiceId:',
        error: e,
        stackTrace: stackTrace,
      );
      throw DatabaseOperationException(
          'An unexpected error occurred creating the expense.', e, stackTrace);
    }
  }

  /// Updates an existing expense document in Firestore.
  ///
  /// Parameters:
  ///  - [invoiceId]: The ID of the invoice this expense belongs to.
  ///  - [expense]: The [Expense] object with updated data (must include expense ID).
  ///
  /// Throws [DatabaseOperationException] on failure.
  /// Throws [NotAuthenticatedException] if the user is not logged in.
  Future<void> updateExpense(String invoiceId, Expense expense) async {
    if (expense.id.isEmpty) {
      throw ArgumentError('Expense ID must be provided for update.');
    }
    final userId = _getCurrentUserId();
    _logger.i(
        'Updating expense ${expense.id} for invoice $invoiceId, user $userId');
    try {
      final dataToUpdate = expense.toJson();
      dataToUpdate.remove('id'); // Don't update the ID field
      dataToUpdate['updatedAt'] =
          FieldValue.serverTimestamp(); // Use server timestamp

      await _getExpensesCollection(userId, invoiceId)
          .doc(expense.id)
          .update(dataToUpdate);

      _logger.i('Expense ${expense.id} updated successfully.');
    } on FirebaseException catch (e, stackTrace) {
      _logger.e(
        '[EXPENSE] FirebaseException updating expense ${expense.id} for invoice $invoiceId:',
        error: e,
        stackTrace: stackTrace,
      );
      throw DatabaseOperationException(
          'Failed to update expense: ${e.message}', e, stackTrace);
    } catch (e, stackTrace) {
      _logger.e(
        '[EXPENSE] Error updating expense ${expense.id} for invoice $invoiceId:',
        error: e,
        stackTrace: stackTrace,
      );
      throw DatabaseOperationException(
          'An unexpected error occurred updating the expense.', e, stackTrace);
    }
  }

  /// Deletes an expense document from Firestore.
  ///
  /// Parameters:
  ///  - [invoiceId]: The ID of the invoice this expense belongs to.
  ///  - [expenseId]: The ID of the expense to delete.
  ///
  /// Throws [DatabaseOperationException] on failure.
  /// Throws [NotAuthenticatedException] if the user is not logged in.
  Future<void> deleteExpense(String invoiceId, String expenseId) async {
    final userId = _getCurrentUserId();
    _logger
        .i('Deleting expense $expenseId from invoice $invoiceId, user $userId');
    try {
      await _getExpensesCollection(userId, invoiceId).doc(expenseId).delete();
      _logger.i('Expense $expenseId deleted successfully.');
    } on FirebaseException catch (e, stackTrace) {
      _logger.e(
        '[EXPENSE] FirebaseException deleting expense $expenseId from invoice $invoiceId:',
        error: e,
        stackTrace: stackTrace,
      );
      throw DatabaseOperationException(
          'Failed to delete expense: ${e.message}', e, stackTrace);
    } catch (e, stackTrace) {
      _logger.e(
        '[EXPENSE] Error deleting expense $expenseId from invoice $invoiceId:',
        error: e,
        stackTrace: stackTrace,
      );
      throw DatabaseOperationException(
          'An unexpected error occurred deleting the expense.', e, stackTrace);
    }
  }

  /// Retrieves a real-time stream of expenses for a specific invoice.
  ///
  /// Parameters:
  ///  - [invoiceId]: The ID of the invoice to fetch expenses for.
  ///
  /// Returns a [Stream] of a list of [Expense] objects.
  /// Emits an error wrapped in [DatabaseFetchException] if fetching fails.
  /// Throws [NotAuthenticatedException] if the user is not logged in.
  Stream<List<Expense>> getExpensesStream(String invoiceId) {
    final userId = _getCurrentUserId();
    _logger.d('Creating expense stream for invoice $invoiceId, user $userId');
    try {
      final query = _getExpensesCollection(userId, invoiceId)
          .orderBy('date', descending: true); // Example: order by date

      return query.snapshots().map((snapshot) {
        _logger.d(
            '[EXPENSE STREAM] Received snapshot with ${snapshot.docs.length} expense docs for invoice $invoiceId');
        return snapshot.docs
            .map((doc) {
              try {
                final data = doc.data();
                // Assuming Expense model has a fromJson factory
                return Expense.fromJson({...data, 'id': doc.id});
              } catch (e, stackTrace) {
                _logger.e(
                  '[EXPENSE STREAM] Error parsing expense document ${doc.id}:',
                  error: e,
                  stackTrace: stackTrace,
                );
                return null; // Skip faulty documents
              }
            })
            .where((expense) => expense != null)
            .cast<Expense>()
            .toList();
      }).handleError((error, stackTrace) {
        _logger.e(
          '[EXPENSE STREAM] Error in expense stream for invoice $invoiceId:',
          error: error,
          stackTrace: stackTrace,
        );
        // Wrap the error in a specific exception
        throw DatabaseFetchException(
            'Failed to fetch expenses: ${error.toString()}', error, stackTrace);
      });
    } catch (e, stackTrace) {
      _logger.e(
        '[EXPENSE STREAM] Error creating expense stream for invoice $invoiceId:',
        error: e,
        stackTrace: stackTrace,
      );
      // Return an error stream if initial setup fails
      return Stream.error(DatabaseFetchException(
          'Failed to create expense stream: $e', e, stackTrace));
    }
  }
}
