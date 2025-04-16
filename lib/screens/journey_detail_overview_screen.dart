import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:travel/constants/app_routes.dart';
import 'package:travel/models/journey.dart';
// import 'package:travel/widgets/app_title.dart'; // Unused import

class JourneyDetailOverviewScreen extends StatelessWidget {
  final Journey journey;

  const JourneyDetailOverviewScreen({super.key, required this.journey});

  // Restore the helper function
  // /*
  Widget _buildOverviewLinkCard(BuildContext context, {
    required String label,
    required VoidCallback onTap
  }) {
    return Card(
      clipBehavior: Clip.antiAlias, // Keep clipBehavior
      // No explicit styling - uses theme
      child: InkWell(
        onTap: onTap,
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
  // */

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context); 

    return Scaffold(
      // Restore grey background color
      backgroundColor: Colors.grey.shade200, 
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
      // Remove placeholder body
      // body: const Center(
      //   child: Text('Overview Content Placeholder'), 
      // ),
      // Restore GridView body
      // /*
      body: Padding(
        // Use 1.0 padding to match spacing
        padding: const EdgeInsets.all(1.0), 
        child: GridView.count(
          crossAxisCount: 2, 
          // Set spacing to 1.0 for thin white lines
          crossAxisSpacing: 1.0,
          mainAxisSpacing: 1.0,
          children: [
            // Restore _buildOverviewLinkCard calls
            _buildOverviewLinkCard(context, 
              label: 'Info', // TODO: Localize
              onTap: () { 
                // --- Construct path with ID for sub-route --- 
                context.push('${AppRoutes.journeyDetail}/${journey.id}/info', extra: journey);
              }
            ),
             _buildOverviewLinkCard(context, 
              label: 'Expenses', // TODO: Localize
              onTap: () { 
                // This one was correct
                context.push('${AppRoutes.journeyDetail}/${journey.id}/expenses');
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
                // --- Construct path with ID for sub-route --- 
                context.push('${AppRoutes.journeyDetail}/${journey.id}/gallery', extra: journey);
              }
            ),
          ],
        ),
      ),
      // */
    );
  }
} 