import 'package:flutter/material.dart';
import '../models/expense.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExpenseListScreen extends StatefulWidget {
  final String journeyId;

  const ExpenseListScreen({required this.journeyId, super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  bool _isLoading = true;
  List<Expense> _expenses = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
  }

  Future<void> _fetchExpenses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client
          .from('expenses') // Assuming your table is 'expenses'
          .select()
          .eq('journey_id', widget.journeyId) // Filter by journeyId
          .order('date', ascending: false);

      final List<Expense> loadedExpenses = response
          .map((data) => Expense.fromMap(data))
          .toList();

      setState(() {
        _expenses = loadedExpenses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load expenses: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteExpense(String expenseId) async {
    // Confirmation Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Do you want to delete this expense?'),
        actions: <Widget>[
          TextButton(
            child: const Text('No'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text('Yes'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() { _isLoading = true; }); // Show loading
      try {
        await Supabase.instance.client
            .from('expenses')
            .delete()
            .eq('id', expenseId);
        await _fetchExpenses(); // Refresh list
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete expense: $e')),
          );
          setState(() { _isLoading = false; }); // Hide loading on error
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = const Center(child: Text('No expenses added yet.'));

    if (_isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      content = Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    } else if (_expenses.isNotEmpty) {
      double totalExpenses = _expenses.fold(0.0, (sum, item) => sum + item.amount);
      content = Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Total Expenses: ${NumberFormat.currency(symbol: '\$').format(totalExpenses)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _expenses.length,
              itemBuilder: (ctx, index) {
                final expense = _expenses[index];
                return _buildExpenseCard(context, expense);
              },
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchExpenses,
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildExpenseCard(BuildContext context, Expense expense) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(expense.title),
        subtitle: Text(
            '${expense.category} - ${DateFormat.yMd().format(expense.date)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(NumberFormat.currency(symbol: '\$').format(expense.amount)),
            IconButton(
              icon: const Icon(Icons.delete),
              color: Theme.of(context).colorScheme.error,
              onPressed: () => _deleteExpense(expense.id),
            ),
          ],
        ),
      ),
    );
  }
}
