import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:travel/constants/app_routes.dart';
import 'package:travel/models/journey.dart';
// import 'package:travel/widgets/app_title.dart'; // Unused import

class JourneyDetailOverviewScreen extends StatelessWidget {
  final Journey journey;

  const JourneyDetailOverviewScreen({super.key, required this.journey});

  // Helper to build the overview cards
  Widget _buildOverviewCard(BuildContext context, { 
    required IconData icon, 
    required String label, 
    required VoidCallback onTap 
  }) {
    // final theme = Theme.of(context); // Unused variable
    return Card(
      // Use theme card styling
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12), // Match card shape
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(label, style: Theme.of(context).textTheme.titleSmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context); // Unused variable
    // TODO: Localize labels

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.go(AppRoutes.home), // Go back to home
        ),
        title: Text(journey.title), // Use journey title
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        // Use GridView for the overview cards
        child: GridView.count(
          crossAxisCount: 2, // 2 cards per row
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          children: [
            _buildOverviewCard(context, 
              icon: Icons.info_outline,
              label: 'Info', 
              onTap: () { 
                // Navigate to the nested info route, passing journey
                context.push('${AppRoutes.journeyDetail}/info', extra: journey); 
              }
            ),
             _buildOverviewCard(context, 
              icon: Icons.account_balance_wallet_outlined,
              label: 'Expenses', 
              onTap: () { 
                // TODO: Navigate to Expenses screen 
              }
            ),
             _buildOverviewCard(context, 
              icon: Icons.people_outline,
              label: 'Participants', 
              onTap: () { 
                // TODO: Navigate to Participants screen
              }
            ),
             _buildOverviewCard(context, 
              icon: Icons.image_outlined,
              label: 'Images', 
              onTap: () { 
                // Explicitly remove any current SnackBar before navigating
                ScaffoldMessenger.of(context).removeCurrentSnackBar();
                // Navigate to the gallery route, passing the journey object
                context.push('${AppRoutes.journeyDetail}/gallery', extra: journey);
              }
            ),
          ],
        ),
      ),
    );
  }
} 