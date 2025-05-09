import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:travel/models/budget.dart';
import 'package:travel/screens/invoices/invoice_capture_overview_screen.dart';
import 'package:travel/screens/invoices/invoice_detail_screen.dart';

/// Displays the details of a single budget and allows scanning invoices.
/// Shows real-time updates using StreamBuilder.
class BudgetOverviewScreen extends StatelessWidget {
  final String projectId;
  final String budgetId;

  const BudgetOverviewScreen({
    super.key,
    required this.projectId,
    required this.budgetId,
  });

  Stream<Budget?> _budgetStream() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('projects')
        .doc(projectId)
        .collection('budgets')
        .doc(budgetId)
        .snapshots()
        .map((doc) => doc.exists ? Budget.fromJson(doc.data()!) : null);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _invoiceStream() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('projects')
        .doc(projectId)
        .collection('budgets')
        .doc(budgetId)
        .collection('invoices')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Budget?>(
      stream: _budgetStream(),
      builder: (context, budgetSnapshot) {
        if (budgetSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!budgetSnapshot.hasData || budgetSnapshot.data == null) {
          return const Scaffold(
            body: Center(child: Text('Budget not found.')),
          );
        }
        final budget = budgetSnapshot.data!;
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
                Text('Budget Sum: €${budget.sum.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 24),
                Text('Invoices:',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _invoiceStream(),
                    builder: (context, invoiceSnapshot) {
                      if (invoiceSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (invoiceSnapshot.hasError) {
                        return Center(child: Text('Error loading invoices'));
                      }
                      final docs = invoiceSnapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(
                            child: Text('No invoices for this budget.'));
                      }
                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final data = docs[index].data();
                          final invoiceId = docs[index].id;
                          return ListTile(
                            title: Text(data['title'] ?? 'Invoice'),
                            subtitle: Text('Amount: €${data['amount'] ?? 0}'),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => InvoiceDetailScreen(
                                    projectId: projectId,
                                    budgetId: budgetId,
                                    invoiceId: invoiceId,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
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
