import 'package:flutter/material.dart';

class InvoiceDetailScreen extends StatelessWidget {
  final String projectId;
  final String budgetId;
  final String invoiceId;

  const InvoiceDetailScreen({
    super.key,
    required this.projectId,
    required this.budgetId,
    required this.invoiceId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Project ID: $projectId'),
            Text('Budget ID: $budgetId'),
            Text('Invoice ID: $invoiceId'),
            const SizedBox(height: 24),
            // TODO: Add invoice details, images, and expenses here
            const Text(
                'Invoice details, images, and expenses will appear here.'),
          ],
        ),
      ),
    );
  }
}
