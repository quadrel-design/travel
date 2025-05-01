import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExpenseListScreen extends ConsumerWidget {
  final String projectId;

  const ExpenseListScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses (Temporarily Disabled)')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Expense list and totals are temporarily unavailable while project features are being migrated.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
