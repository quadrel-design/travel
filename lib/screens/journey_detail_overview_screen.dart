import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:travel/constants/app_routes.dart';
import 'package:travel/models/journey.dart';
// import 'package:travel/widgets/app_title.dart'; // Unused import

class JourneyDetailOverviewScreen extends StatelessWidget {
  final Journey journey;

  const JourneyDetailOverviewScreen({super.key, required this.journey});

  // Updated helper function for the new card style
  Widget _buildOverviewLinkCard(BuildContext context, {
    // Remove icon parameter
    required String label,
    required VoidCallback onTap
  }) {
    // final theme = Theme.of(context); // REMOVED
    // final borderColor = theme.dividerColor; // No longer needed
    // final cardColor = Colors.white; 

    return Card(
      // Explicit styling removed - will now use antonettiCardTheme defaults
      clipBehavior: Clip.antiAlias, // Keep clipBehavior
      // elevation: 0, // REMOVED
      // color: Colors.white, // REMOVED
      // shape: RoundedRectangleBorder( // REMOVED
      //   borderRadius: BorderRadius.circular(8.0),
      // ), // REMOVED
      child: InkWell(
        onTap: onTap,
        // borderRadius: BorderRadius.circular(12), // InkWell uses Card shape
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              label, 
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
              textAlign: TextAlign.center, 
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context); 

    return Scaffold(
      // Set background color for the page
      backgroundColor: Colors.grey.shade200, // Example grey background
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.go(AppRoutes.home), 
        ),
        title: Text(journey.title), 
        centerTitle: true,
        // Consider matching AppBar style (e.g., white background) if desired
      ),
      body: Padding(
        // Use 1.0 padding to match spacing
        padding: const EdgeInsets.all(1.0), 
        child: GridView.count(
          crossAxisCount: 2, 
          // Set spacing to 1.0 for thin white lines
          crossAxisSpacing: 1.0,
          mainAxisSpacing: 1.0,
          children: [
            // Use the updated helper function
            _buildOverviewLinkCard(context, 
              label: 'Info', // TODO: Localize
              onTap: () { 
                context.push('${AppRoutes.journeyDetail}/info', extra: journey);
              }
            ),
             _buildOverviewLinkCard(context, 
              label: 'Expenses', // TODO: Localize
              onTap: () { 
                // TODO: Navigate to Expenses screen 
                print('Tapped Expenses'); 
              }
            ),
             _buildOverviewLinkCard(context, 
              label: 'Participants', // TODO: Localize
              onTap: () { 
                // TODO: Navigate to Participants screen
                print('Tapped Participants'); 
              }
            ),
             _buildOverviewLinkCard(context, 
              label: 'Images', // TODO: Localize
              onTap: () { 
                ScaffoldMessenger.of(context).removeCurrentSnackBar();
                context.push('${AppRoutes.journeyDetail}/gallery', extra: journey);
              }
            ),
          ],
        ),
      ),
    );
  }
} 