import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BudgetCreateScreen extends StatefulWidget {
  final String projectId;
  const BudgetCreateScreen({super.key, required this.projectId});

  @override
  State<BudgetCreateScreen> createState() => _BudgetCreateScreenState();
}

class _BudgetCreateScreenState extends State<BudgetCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  String _budgetName = '';
  double? _budgetSum;
  bool _isLoading = false;

  Future<void> _saveBudget() async {
    setState(() => _isLoading = true);
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final budgetsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('projects')
        .doc(widget.projectId)
        .collection('budgets');
    final docRef = budgetsRef.doc();
    await docRef.set({
      'id': docRef.id,
      'name': _budgetName,
      'sum': _budgetSum ?? 0.0,
      'createdAt': DateTime.now().toIso8601String(),
      'invoiceIds': <String>[],
    });
    setState(() => _isLoading = false);
    if (mounted) {
      Navigator.of(context).pop(docRef.id);
    }
  }

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
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Budget Sum'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter a sum';
                  final parsed = double.tryParse(value);
                  if (parsed == null) return 'Enter a valid number';
                  return null;
                },
                onSaved: (value) =>
                    _budgetSum = double.tryParse(value ?? '') ?? 0.0,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState?.validate() ?? false) {
                          _formKey.currentState?.save();
                          _saveBudget();
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
