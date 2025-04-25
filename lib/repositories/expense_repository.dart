import 'package:logger/logger.dart';
import 'package:travel/models/expense.dart';

class ExpenseRepository {
  final Logger _logger;

  ExpenseRepository({required Logger logger}) : _logger = logger;

  Future<void> createExpense(Expense expense) async {
    try {
      // Implementation here
    } catch (e, stackTrace) {
      _logger.e(
        '[EXPENSE] Error creating expense:',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> updateExpense(Expense expense) async {
    try {
      // Implementation here
    } catch (e, stackTrace) {
      _logger.e(
        '[EXPENSE] Error updating expense:',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    try {
      // Implementation here
    } catch (e, stackTrace) {
      _logger.e(
        '[EXPENSE] Error deleting expense:',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<Expense>> getExpenses() async {
    try {
      // Implementation here
      return [];
    } catch (e, stackTrace) {
      _logger.e(
        '[EXPENSE] Error getting expenses:',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
