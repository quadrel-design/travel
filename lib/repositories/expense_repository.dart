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
      String userId, String projectId, String budgetId, String invoiceId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('projects')
        .doc(projectId)
        .collection('budgets')
        .doc(budgetId)
        .collection('invoices')
        .doc(invoiceId)
        .collection('expenses');
  }

  /// Creates a new expense document in Firestore under a specific invoice.
  ///
  /// Parameters:
  ///  - [projectId]: The ID of the project this invoice belongs to.
  ///  - [budgetId]: The ID of the budget this invoice belongs to.
  ///  - [invoiceId]: The ID of the invoice this expense belongs to.
  ///  - [expense]: The [Expense] object to create.
  ///
  /// Returns the created [Expense] object with its Firestore ID.
  /// Throws [DatabaseOperationException] on failure.
  /// Throws [NotAuthenticatedException] if the user is not logged in.
  Future<Expense> createExpense(
    String projectId,
    String budgetId,
    String invoiceId,
    Expense expense,
  ) async {
    final userId = _getCurrentUserId();
    _logger.i(
        'Creating expense for project $projectId, budget $budgetId, invoice $invoiceId, user $userId');
    try {
      final dataToSave = expense.toJson();
      dataToSave['updatedAt'] = FieldValue.serverTimestamp();
      final docRef =
          await _getExpensesCollection(userId, projectId, budgetId, invoiceId)
              .add(dataToSave);
      _logger.i('Expense created with ID: ${docRef.id}');
      return expense.copyWith(id: docRef.id);
    } catch (e, stackTrace) {
      _logger.e('Error creating expense', error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
          'Failed to create expense: ${e.toString()}', e, stackTrace);
    }
  }

  /// Updates an existing expense document in Firestore.
  ///
  /// Parameters:
  ///  - [projectId]: The ID of the project this invoice belongs to.
  ///  - [budgetId]: The ID of the budget this invoice belongs to.
  ///  - [invoiceId]: The ID of the invoice this expense belongs to.
  ///  - [expense]: The [Expense] object to update.
  ///
  /// Throws [DatabaseOperationException] on failure.
  /// Throws [NotAuthenticatedException] if the user is not logged in.
  Future<void> updateExpense(
    String projectId,
    String budgetId,
    String invoiceId,
    Expense expense,
  ) async {
    final userId = _getCurrentUserId();
    _logger.i(
        'Updating expense ${expense.id} for project $projectId, budget $budgetId, invoice $invoiceId, user $userId');
    try {
      final dataToUpdate = expense.toJson();
      dataToUpdate.remove('id');
      dataToUpdate['updatedAt'] = FieldValue.serverTimestamp();
      await _getExpensesCollection(userId, projectId, budgetId, invoiceId)
          .doc(expense.id)
          .update(dataToUpdate);
      _logger.i('Expense updated successfully');
    } catch (e, stackTrace) {
      _logger.e('Error updating expense', error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
          'Failed to update expense: ${e.toString()}', e, stackTrace);
    }
  }

  /// Deletes an expense document from Firestore.
  ///
  /// Parameters:
  ///  - [projectId]: The ID of the project this invoice belongs to.
  ///  - [budgetId]: The ID of the budget this invoice belongs to.
  ///  - [invoiceId]: The ID of the invoice this expense belongs to.
  ///  - [expenseId]: The ID of the expense to delete.
  ///
  /// Throws [DatabaseOperationException] on failure.
  /// Throws [NotAuthenticatedException] if the user is not logged in.
  Future<void> deleteExpense(
    String projectId,
    String budgetId,
    String invoiceId,
    String expenseId,
  ) async {
    final userId = _getCurrentUserId();
    _logger.i(
        'Deleting expense $expenseId from project $projectId, budget $budgetId, invoice $invoiceId, user $userId');
    try {
      await _getExpensesCollection(userId, projectId, budgetId, invoiceId)
          .doc(expenseId)
          .delete();
      _logger.i('Expense deleted successfully');
    } catch (e, stackTrace) {
      _logger.e('Error deleting expense', error: e, stackTrace: stackTrace);
      throw DatabaseOperationException(
          'Failed to delete expense: ${e.toString()}', e, stackTrace);
    }
  }

  /// Returns a stream of all expenses for a specific invoice.
  ///
  /// Parameters:
  ///  - [projectId]: The ID of the project this invoice belongs to.
  ///  - [budgetId]: The ID of the budget this invoice belongs to.
  ///  - [invoiceId]: The ID of the invoice to get expenses for.
  ///
  /// Returns a [Stream] of [List<Expense>].
  /// Throws [DatabaseFetchException] on failure.
  /// Throws [NotAuthenticatedException] if the user is not logged in.
  Stream<List<Expense>> getExpensesStream(
    String projectId,
    String budgetId,
    String invoiceId,
  ) {
    final userId = _getCurrentUserId();
    _logger.d(
        'Creating expense stream for project $projectId, budget $budgetId, invoice $invoiceId, user $userId');
    try {
      final query =
          _getExpensesCollection(userId, projectId, budgetId, invoiceId)
              .orderBy('date', descending: true);
      return query.snapshots().map((snapshot) {
        _logger.d(
            '[EXPENSE STREAM] Received snapshot with ${snapshot.docs.length} expense docs for project $projectId, budget $budgetId, invoice $invoiceId');
        return snapshot.docs
            .map((doc) {
              try {
                final data = doc.data();
                return Expense.fromJson({...data, 'id': doc.id});
              } catch (e, stackTrace) {
                _logger.e(
                  '[EXPENSE STREAM] Error parsing expense document ${doc.id}:',
                  error: e,
                  stackTrace: stackTrace,
                );
                return null;
              }
            })
            .where((expense) => expense != null)
            .cast<Expense>()
            .toList();
      }).handleError((error, stackTrace) {
        _logger.e(
          '[EXPENSE STREAM] Error in expense stream for project $projectId, budget $budgetId, invoice $invoiceId:',
          error: error,
          stackTrace: stackTrace,
        );
        throw DatabaseFetchException(
            'Failed to fetch expenses: $error', error, stackTrace);
      });
    } catch (e, stackTrace) {
      _logger.e(
        '[EXPENSE STREAM] Error creating expense stream for project $projectId, budget $budgetId, invoice $invoiceId:',
        error: e,
        stackTrace: stackTrace,
      );
      return Stream.error(DatabaseFetchException(
          'Failed to create expense stream: $e', e, stackTrace));
    }
  }
}
