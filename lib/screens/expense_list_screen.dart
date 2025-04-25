import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Keep Riverpod import
// import 'package:go_router/go_router.dart';
// import 'package:travel/constants/app_routes.dart';
// import 'package:travel/providers/repository_providers.dart'; // Remove unused import
// import 'package:intl/intl.dart'; // Remove unused import
// Import model
// import 'package:travel/providers/repository_providers.dart'; // Import provider

// Change to ConsumerWidget
class ExpenseListScreen extends ConsumerWidget {
  // Screen needs context about which Journey it belongs to.
  final String journeyId;

  const ExpenseListScreen({super.key, required this.journeyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // final detectedSumsAsync = ref.watch(detectedSumsProvider(journeyId)); // Comment this line
    // final expensesAsync = ref.watch(expensesProvider(journeyId)); // Assuming this exists

    // Placeholder build method for now
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses (Temporarily Disabled)')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Expense list and totals are temporarily unavailable while Journey features are being migrated.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      // We might need to comment out or provide a dummy FAB if it relied on _addExpense
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () { /* TODO: Re-enable add expense */ },
      //   child: const Icon(Icons.add),
      // ),
    );
  }
}
