/// Home Screen
///
/// Displays the main home screen after login, showing a list of the user's
/// projects/invoices fetched via a stream provider. Allows navigation to
/// project details, settings, and creating new projects.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/constants/app_routes.dart'; // Import routes
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import
import 'package:travel/providers/user_subscription_provider.dart';

// Change to ConsumerWidget (or ConsumerStatefulWidget if other state needed later)
/// The main screen displayed after successful login.
/// Shows a list of the user's projects/invoices fetched from Firestore
/// using the [userProjectsStreamProvider].
class HomeScreen extends ConsumerWidget {
  // Changed to ConsumerWidget
  const HomeScreen({super.key});

  // Removed dateFormat from here, move to build if needed locally

  /// Builds the UI for the Home Screen.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the new stream provider
    final projectsAsyncValue = ref.watch(userInvoicesStreamProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy'); // Local instance if needed

    // Helper for navigation, still needed
    void goToCreateProject() {
      context.push(AppRoutes.createProject);
      // No need to manually refresh anymore, stream provider handles updates
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.yourProjectsTitle),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final subscription = ref.watch(userSubscriptionProvider);
              final isPro = subscription == 'pro';
              return IconButton(
                icon: Icon(
                  isPro ? Icons.star : Icons.star_border,
                  color: isPro ? Colors.amber : Colors.grey,
                ),
                tooltip: isPro ? 'Pro Version' : 'Free Version',
                onPressed: () =>
                    ref.read(userSubscriptionProvider.notifier).toggle(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'App Settings',
            onPressed: () =>
                context.push('${AppRoutes.home}${AppRoutes.appSettings}'),
          ),
        ],
      ),
      // Use AsyncValue.when to handle loading/error/data states
      body: projectsAsyncValue.when(
        data: (projects) {
          if (projects.isEmpty) {
            return Center(child: Text(l10n.homeScreenNoProjects));
          }
          // Build the list view if data is available
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              final dateRange =
                  '${dateFormat.format(project.startDate)} - ${dateFormat.format(project.endDate)}';
              final subtitleText = '${project.description}\n$dateRange';

              return Card(
                child: ListTile(
                  title: Text(project.title),
                  subtitle: Text(subtitleText),
                  isThreeLine: true,
                  onTap: () {
                    // Construct the path for the nested route
                    final projectDetailPath =
                        AppRoutes.projectDetail.split('/').last;
                    context.push('/home/$projectDetailPath/${project.id}',
                        extra: project);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          // Consider logging the error stack here
          // ref.read(loggerProvider).e('Error loading projects', error: error, stackTrace: stack);
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error loading projects: $error',
                    style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 10),
                ElevatedButton(
                  // Refresh logic might need reconsideration - ref.refresh might work
                  onPressed: () => ref.refresh(userInvoicesStreamProvider),
                  child: Text(l10n.homeScreenRetryButton),
                )
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: goToCreateProject,
        tooltip: l10n.homeScreenAddProjectTooltip,
        child: const Icon(Icons.add),
      ),
    );
  }
}
