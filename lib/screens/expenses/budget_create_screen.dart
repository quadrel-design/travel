import 'package:flutter/material.dart';

class BudgetCreateScreen extends StatefulWidget {
  const BudgetCreateScreen({super.key});

  @override
  State<BudgetCreateScreen> createState() => _BudgetCreateScreenState();
}

class _BudgetCreateScreenState extends State<BudgetCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  String _budgetName = '';
  double? _budgetSum;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Budget')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Budget Name'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter a name' : null,
                onSaved: (value) => _budgetName = value ?? '',
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Budget Sum'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter a sum';
                  final parsed = double.tryParse(value);
                  if (parsed == null) return 'Enter a valid number';
                  return null;
                },
                onSaved: (value) => _budgetSum = double.tryParse(value ?? ''),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    _formKey.currentState?.save();
                    // Return the budget data to the previous screen
                    Navigator.of(context).pop({
                      'name': _budgetName,
                      'sum': _budgetSum ?? 0.0,
                    });
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
