/// Expense Repository
///
/// Defines the repository for managing expense data associated with invoices,
/// interacting with Firebase Firestore.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel/models/expense.dart';
import 'package:travel/repositories/repository_exceptions.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Repository class for handling expense CRUD operations.
/// TODO: Migrate this repository to use PostgreSQL backend.
class ExpenseRepository {
  // final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Logger _logger;

  ExpenseRepository({
    // required FirebaseFirestore firestore, // Firestore dependency removed
    required FirebaseAuth auth,
    required Logger logger,
  })  : // _firestore = firestore,
        _auth = auth,
        _logger = logger {
    _logger.w(
        'ExpenseRepository is using a non-functional stub implementation. Needs migration to PostgreSQL.');
  }

  String _getCurrentUserId() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      _logger.e('User ID is null, operation requires authentication.');
      throw NotAuthenticatedException(
          'User must be logged in to perform this operation.');
    }
    return userId;
  }

  // CollectionReference<Map<String, dynamic>> _getExpensesCollection(
  //     String userId, String projectId, String invoiceId) {
  //   return _firestore
  //       .collection('users')
  //       .doc(userId)
  //       .collection('projects')
  //       .doc(projectId)
  //       .collection('invoices')
  //       .doc(invoiceId)
  //       .collection('expenses');
  // }

  Future<Expense> createExpense(
    String projectId,
    String invoiceId,
    Expense expense,
  ) async {
    _getCurrentUserId(); // Check auth
    _logger
        .w('createExpense is not implemented for PostgreSQL. Returning stub.');
    // throw UnimplementedError('createExpense is not implemented for PostgreSQL yet.');
    return expense.copyWith(
        id: 'stub_expense_id_${DateTime.now().millisecondsSinceEpoch}'); // Return a stub
  }

  Future<void> updateExpense(
    String projectId,
    String invoiceId,
    Expense expense,
  ) async {
    _getCurrentUserId(); // Check auth
    _logger.w('updateExpense is not implemented for PostgreSQL.');
    // throw UnimplementedError('updateExpense is not implemented for PostgreSQL yet.');
  }

  Future<void> deleteExpense(
    String projectId,
    String invoiceId,
    String expenseId,
  ) async {
    _getCurrentUserId(); // Check auth
    _logger.w('deleteExpense is not implemented for PostgreSQL.');
    // throw UnimplementedError('deleteExpense is not implemented for PostgreSQL yet.');
  }

  Stream<List<Expense>> getExpensesStream(
    String projectId,
    String invoiceId,
  ) {
    _getCurrentUserId(); // Check auth
    _logger.w(
        'getExpensesStream is not implemented for PostgreSQL. Returning empty stream.');
    return Stream.value([]);
    // throw UnimplementedError('getExpensesStream is not implemented for PostgreSQL yet.');
  }
}
