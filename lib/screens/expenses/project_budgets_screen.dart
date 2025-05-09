import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart'; // Remove unused import
import 'package:travel/models/expense.dart';
import 'package:intl/intl.dart';
import 'package:travel/screens/expenses/budget_create_screen.dart';
import 'package:travel/screens/expenses/budget_overview_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:supabase_flutter/supabase_flutter.dart'; // Removed

/// Displays a list of budgets for the given project.
/// Allows creating a new budget and viewing budget details.
class ProjectBudgetsScreen extends StatelessWidget {
  final String projectId;

  const ProjectBudgetsScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in.')),
      );
    }
    final budgetsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('projects')
        .doc(projectId)
        .collection('budgets');
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: budgetsRef.orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No budgets yet.'));
          }
          final budgets = snapshot.data!.docs;
          return ListView.separated(
            itemCount: budgets.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final data = budgets[index].data();
              return ListTile(
                title: Text(data['name'] ?? ''),
                subtitle:
                    Text('Sum: €${(data['sum'] ?? 0).toStringAsFixed(2)}'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BudgetOverviewScreen(
                        projectId: projectId,
                        budgetId: data['id'],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push<String>(
            MaterialPageRoute(
              builder: (_) => BudgetCreateScreen(projectId: projectId),
            ),
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Create New Budget',
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
                  if (!value.contains(',') && value.isNotEmpty) {}
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
              final sharedWithList = _sharedWithString
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              final newExpense = Expense(
                id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
                projectId: '',
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

class _Budget {
  final String name;
  final double sum;
  _Budget({required this.name, required this.sum});
}
