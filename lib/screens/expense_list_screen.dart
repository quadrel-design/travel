import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:intl/intl.dart'; // For formatting
// Import model
import 'package:travel/providers/repository_providers.dart'; // Import provider

// Change to ConsumerWidget
class ExpenseListScreen extends ConsumerWidget {
  // Screen needs context about which Journey it belongs to.
  final String journeyId;

  const ExpenseListScreen({super.key, required this.journeyId});

  @override
  // Add WidgetRef ref
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the provider, passing the journeyId
    final asyncDetectedSums = ref.watch(detectedSumsProvider(journeyId));

    // Prepare currency formatter (adjust locale as needed)
    final currencyFormatter = NumberFormat.currency(locale: 'de_DE', symbol: '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detected Expenses'), // Changed title slightly
      ),
      body: asyncDetectedSums.when(
        // --- Loading State --- 
        loading: () => const Center(child: CircularProgressIndicator()),
        // --- Error State --- 
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Error loading detected sums: $error', // Basic error message
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // --- Data State --- 
        data: (sums) {
          if (sums.isEmpty) {
            return const Center(
              child: Text('No detected expense sums found yet.'), // Message when list is empty
            );
          }
          // Display the list
          return ListView.builder(
            itemCount: sums.length,
            itemBuilder: (context, index) {
              final item = sums[index];
              return ListTile(
                // leading: // Optional: Could show a thumbnail if image_url is fetched
                title: Text(
                  // Format amount and currency
                  '${currencyFormatter.format(item.detectedTotalAmount ?? 0)} ${item.detectedCurrency ?? ''}'.trim(),
                ),
                subtitle: Text(
                  // Show when it was processed
                  'Detected on: ${item.lastProcessedAt != null ? DateFormat.yMd().add_jm().format(item.lastProcessedAt!.toLocal()) : 'Unknown'}',
                ),
                // trailing: // Optional: Icon to indicate source (detected)
                // onTap: // Optional: Navigate to the specific image?
              );
            },
          );
        },
      ),
      // floatingActionButton: ... 
    );
  }
} 