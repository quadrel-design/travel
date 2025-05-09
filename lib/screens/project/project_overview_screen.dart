import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:travel/constants/app_routes.dart';
import 'package:travel/models/project.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProjectDetailOverviewScreen extends StatelessWidget {
  final Project project;

  const ProjectDetailOverviewScreen({
    super.key,
    required this.project,
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

  void _navigateToInvoiceCapture(BuildContext context, String invoiceId) {
    final fullPath =
        '/home/project-detail/${project.id}/invoice-capture-overview?invoiceId=$invoiceId';
    context.push(fullPath, extra: project);
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
        title: Text(project.title),
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
                label: l10n.projectDetailInfoLabel, // Use l10n
                onTap: () {
              // --- Construct path with ID for sub-route ---
              context.push('${AppRoutes.projectDetail}/${project.id}/info',
                  extra: project);
            }),
            _buildOverviewLinkCard(context,
                label: l10n.projectDetailExpensesLabel, // Use l10n
                onTap: () {
              // Route to the expenses screen for this project
              context.push('/home/project-detail/${project.id}/expenses');
            }),
            _buildOverviewLinkCard(context,
                label: l10n.projectDetailParticipantsLabel, // Use l10n
                onTap: () {
              // Navigate to Participants screen using GoRouter
              context.push(
                  '${AppRoutes.projectDetail}/${project.id}/participants');
            }),
            _buildOverviewLinkCard(context,
                label: l10n.projectDetailImagesLabel, // Use l10n
                onTap: () async {
              ScaffoldMessenger.of(context).removeCurrentSnackBar();
              final userId = FirebaseAuth.instance.currentUser?.uid;
              if (userId == null) return;
              final budgetsRef = FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('projects')
                  .doc(project.id)
                  .collection('budgets');
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Select Budget'),
                  content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: budgetsRef.snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }
                      final budgets = snapshot.data!.docs;
                      if (budgets.isEmpty) {
                        return const Text('No budgets found.');
                      }
                      return SizedBox(
                        width: 300,
                        height: 200,
                        child: ListView.builder(
                          itemCount: budgets.length,
                          itemBuilder: (context, index) {
                            final data = budgets[index].data();
                            return ListTile(
                              title: Text(data['name'] ?? 'Unnamed'),
                              onTap: () {
                                Navigator.of(context).pop();
                                context.push(
                                  '/home/project-detail/${project.id}/invoice-capture-overview',
                                  extra: {
                                    'project': project,
                                    'budgetId': data['id'],
                                  },
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
