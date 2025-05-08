import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:travel/models/budget.dart';

class BudgetOverviewScreen extends StatelessWidget {
  final String projectId;
  final String budgetId;

  const BudgetOverviewScreen({
    super.key,
    required this.projectId,
    required this.budgetId,
  });

  Future<Budget?> _fetchBudget() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('projects')
        .doc(projectId)
        .collection('budgets')
        .doc(budgetId)
        .get();
    if (!doc.exists) return null;
    return Budget.fromJson(doc.data()!);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Budget?>(
      future: _fetchBudget(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(
            body: Center(child: Text('Budget not found.')),
          );
        }
        final budget = snapshot.data!;
        return Scaffold(
          appBar: AppBar(
            title: Text('Budget: ${budget.name}'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Budget Name: ${budget.name}',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Budget Sum: 4${budget.sum.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 24),
                // TODO: Add more budget details or invoice list here
                const Text('Invoices for this budget will be shown here.'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              // TODO: Implement scan invoice logic or navigation
            },
            child: const Icon(Icons.document_scanner),
            tooltip: 'Scan Invoice',
          ),
        );
      },
    );
  }
}
