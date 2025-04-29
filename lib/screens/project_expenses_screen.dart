import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart'; // Remove unused import
import 'package:travel/models/expense.dart';
import 'package:intl/intl.dart';
// import 'package:supabase_flutter/supabase_flutter.dart'; // Removed

class ProjectExpensesScreen extends StatefulWidget {
  final String projectId;

  const ProjectExpensesScreen({super.key, required this.projectId});

  @override
  State<ProjectExpensesScreen> createState() => _ProjectExpensesScreenState();
}

class _ProjectExpensesScreenState extends State<ProjectExpensesScreen> {
  bool _isLoading = true;
  // Make _expenses final and initialize empty
  // The list will be replaced by the fetched data later
  List<Expense> _expenses = [];
  String? _error;
  // late Future<List<Expense>> _expensesFuture; // Remove unused field

  @override
  void initState() {
    super.initState();
    _fetchExpenses(); // Call fetch directly
  }

  Future<void> _fetchExpenses() async {
    if (!mounted) return; // Check if mounted at the beginning
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // TODO: Migrate to Firebase/Firestore
      // Simulate fetching data
      await Future.delayed(
          const Duration(milliseconds: 500)); // Simulate network delay
      // Replace with actual fetch logic from Firebase
      final fetchedExpenses = <Expense>[]; // Placeholder for fetched data

      if (!mounted) return; // Check again after await
      setState(() {
        _expenses = fetchedExpenses; // Assign fetched data
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load expenses: $e';
        _isLoading = false;
      });
    }
  }

  /* // Remove unused method _addExpense
  void _addExpense() async {
     // ... (content of the method)
  }
  */

  Future<void> _deleteExpense(String expenseId) async {
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

    if (confirm != true) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    try {
      // TODO: Migrate delete expense logic to Firebase
      // Simulate deletion
      await Future.delayed(const Duration(milliseconds: 300));
      // Replace with actual Firebase delete logic

      // Remove the item locally after successful simulated deletion
      final updatedExpenses = List<Expense>.from(_expenses);
      updatedExpenses.removeWhere((exp) => exp.id == expenseId);

      if (!mounted) return;
      setState(() {
        _expenses = updatedExpenses; // Update the list
        _isLoading = false; // Hide loading indicator
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete expense: $e')),
      );
      setState(() {
        _isLoading = false; // Hide loading on error
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      content = Center(
          child: Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)));
    } else if (_expenses.isEmpty) {
      content = const Center(child: Text('No expenses added yet.'));
    } else {
      double totalExpenses =
          _expenses.fold(0.0, (sum, item) => sum + item.amount);
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
            onPressed: _fetchExpenses, // Keep refresh button
          ),
          // Add button is temporarily removed as _addExpense is removed
          // IconButton(
          //   icon: const Icon(Icons.add),
          //   onPressed: _addExpense, // This method is removed
          // ),
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

// --- Add Expense Dialog (Keep separate, might not need changes yet) ---
// IMPORTANT: Ensure this dialog does NOT contain Supabase logic itself.
// If it does, that logic needs commenting/migration too.
class _AddExpenseDialog extends StatefulWidget {
  @override
  _AddExpenseDialogState createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _description = '';
  double _amount = 0.0;
  DateTime _selectedDate = DateTime.now();
  String _category = '';
  String _paidBy = '';
  String _sharedWithString = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Expense'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                decoration: const InputDecoration(labelText: 'Title*'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
                onSaved: (value) => _title = value!,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description'),
                onSaved: (value) => _description = value ?? '',
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Amount*'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null ||
                      double.tryParse(value) == null ||
                      double.parse(value) <= 0) {
                    return 'Please enter a valid positive amount';
                  }
                  return null;
                },
                onSaved: (value) => _amount = double.parse(value!),
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Category*'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a category';
                  }
                  return null;
                },
                onSaved: (value) => _category = value!,
              ),
              TextFormField(
                decoration:
                    const InputDecoration(labelText: 'Paid By (User ID)*'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter who paid';
                  }
                  // TODO: Add validation if user IDs have a specific format
                  return null;
                },
                onSaved: (value) => _paidBy = value!,
              ),
              TextFormField(
                decoration: const InputDecoration(
                    labelText: 'Shared With (User IDs, comma-separated)*'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter who shared the expense';
                  }
                  // Basic check for comma separation, can be enhanced
                  if (!value.contains(',') && value.isNotEmpty) {
                    // Allow single entry without comma
                  }
                  // TODO: Add validation for individual IDs if needed
                  return null;
                },
                onSaved: (value) => _sharedWithString = value!,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child:
                        Text('Date: ${DateFormat.yMd().format(_selectedDate)}'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null && picked != _selectedDate) {
                        setState(() {
                          _selectedDate = picked;
                        });
                      }
                    },
                    child: const Text('Change'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: const Text('Add'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              // Process sharedWith string into List<String>
              final sharedWithList = _sharedWithString
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              final newExpense = Expense(
                id: 'temp-${DateTime.now().millisecondsSinceEpoch}', // Temporary ID
                projectId:
                    '', // Will be set by the caller in _addExpense (needs migration)
                title: _title,
                description: _description.isNotEmpty ? _description : null,
                amount: _amount,
                date: _selectedDate,
                category: _category,
                paidBy: _paidBy,
                sharedWith: sharedWithList,
              );
              Navigator.of(context).pop(newExpense);
            }
          },
        ),
      ],
    );
  }
}
