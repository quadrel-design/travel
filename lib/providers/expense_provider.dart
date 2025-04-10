import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../services/database_helper.dart';

class ExpenseProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Expense> _expenses = [];
  double _totalExpenses = 0;

  List<Expense> get expenses => _expenses;
  double get totalExpenses => _totalExpenses;

  Future<void> loadExpensesForJourney(String journeyId) async {
    _expenses = await _dbHelper.readExpensesForJourney(journeyId);
    _calculateTotalExpenses();
    notifyListeners();
  }

  Future<void> addExpense(Expense expense) async {
    await _dbHelper.createExpense(expense);
    await loadExpensesForJourney(expense.journeyId);
  }

  Future<void> updateExpense(Expense expense) async {
    await _dbHelper.updateExpense(expense);
    await loadExpensesForJourney(expense.journeyId);
  }

  Future<void> deleteExpense(String id, String journeyId) async {
    await _dbHelper.deleteExpense(id);
    await loadExpensesForJourney(journeyId);
  }

  void _calculateTotalExpenses() {
    _totalExpenses = _expenses.fold(0, (sum, expense) => sum + expense.amount);
  }
} 