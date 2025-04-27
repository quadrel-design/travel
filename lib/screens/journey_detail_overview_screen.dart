import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:travel/constants/app_routes.dart';
import 'package:travel/models/journey.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
// import 'package:travel/widgets/app_title.dart'; // Unused import

class JourneyDetailOverviewScreen extends StatelessWidget {
  final Journey journey;

  const JourneyDetailOverviewScreen({
    super.key,
    required this.journey,
  });

  // Helper function to build styled link cards
  Widget _buildOverviewLinkCard(BuildContext context,
      {required String label, required VoidCallback onTap}) {
    // L10n instance
    final l10n = AppLocalizations.of(context)!;

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
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToInvoiceCapture(BuildContext context) {
    final fullPath =
        '/home/journey-detail/${journey.id}/invoice-capture-overview';
    context.push(fullPath, extra: journey);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // Get l10n

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
                label: l10n.journeyDetailInfoLabel, // Use l10n
                onTap: () {
              // --- Construct path with ID for sub-route ---
              context.push('${AppRoutes.journeyDetail}/${journey.id}/info',
                  extra: journey);
            }),
            _buildOverviewLinkCard(context,
                label: l10n.journeyDetailExpensesLabel, // Use l10n
                onTap: () {
              // This one was correct
              context.push('${AppRoutes.journeyDetail}/${journey.id}/expenses');
            }),
            _buildOverviewLinkCard(context,
                label: l10n.journeyDetailParticipantsLabel, // Use l10n
                onTap: () {
              // Navigate to Participants screen using GoRouter
              context.push(
                  '${AppRoutes.journeyDetail}/${journey.id}/participants');
            }),
            _buildOverviewLinkCard(context,
                label: l10n.journeyDetailImagesLabel, // Use l10n
                onTap: () {
              ScaffoldMessenger.of(context).removeCurrentSnackBar();
              _navigateToInvoiceCapture(context);
            }),
          ],
        ),
      ),
    );
  }
}
