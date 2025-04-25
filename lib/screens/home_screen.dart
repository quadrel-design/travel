import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:travel/models/journey.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/constants/app_routes.dart'; // Import routes
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import
import 'package:travel/repositories/auth_repository.dart'; // Add import

// --- State Management using StateNotifierProvider ---

// Define the state for the HomeScreen
@immutable
class HomeScreenState {
  final List<Journey> journeys;
  final bool isLoading;
  final String? error;

  const HomeScreenState({
    this.journeys = const [],
    this.isLoading = true,
    this.error,
  });

  HomeScreenState copyWith({
    List<Journey>? journeys,
    bool? isLoading,
    String? error,
    bool clearError = false, // Helper to clear error
  }) {
    return HomeScreenState(
      journeys: journeys ?? this.journeys,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// Create the StateNotifier
class HomeScreenNotifier extends StateNotifier<HomeScreenState> {
  final AuthRepository _authRepository;

  HomeScreenNotifier(this._authRepository) : super(const HomeScreenState()) {
    loadJourneys(); // Load journeys on initialization
  }

  Future<void> loadJourneys() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final userId = _authRepository.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }
      final loadedJourneys = <Journey>[];
      if (!mounted) return;
      state = state.copyWith(journeys: loadedJourneys, isLoading: false);
    } catch (e) {
      state = state.copyWith(
          error: 'Failed to load journeys: $e', isLoading: false);
    }
  }
}

// Create the Provider
final homeScreenProvider =
    StateNotifierProvider<HomeScreenNotifier, HomeScreenState>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return HomeScreenNotifier(authRepo);
});

// --- End State Management Setup ---

// Change to ConsumerWidget (or ConsumerStatefulWidget if other state needed later)
class HomeScreen extends ConsumerWidget {
  // Changed to ConsumerWidget
  const HomeScreen({super.key});

  // Removed dateFormat from here, move to build if needed locally

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the new stream provider
    final journeysAsyncValue = ref.watch(userJourneysStreamProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy'); // Local instance if needed

    // Helper for navigation, still needed
    void goToCreateJourney() {
      context.push(AppRoutes.createJourney);
      // No need to manually refresh anymore, stream provider handles updates
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.yourJourneysTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'App Settings',
            onPressed: () => context.push(AppRoutes.appSettings),
          ),
        ],
      ),
      // Use AsyncValue.when to handle loading/error/data states
      body: journeysAsyncValue.when(
        data: (journeys) {
          if (journeys.isEmpty) {
            return Center(child: Text(l10n.homeScreenNoJourneys));
          }
          // Build the list view if data is available
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: journeys.length,
            itemBuilder: (context, index) {
              final journey = journeys[index];
              final dateRange =
                  '${dateFormat.format(journey.startDate)} - ${dateFormat.format(journey.endDate)}';
              final subtitleText = '${journey.description}\n$dateRange';

              return Card(
                child: ListTile(
                  title: Text(journey.title),
                  subtitle: Text(subtitleText),
                  isThreeLine: true,
                  onTap: () {
                    // Construct the path for the nested route
                    final journeyDetailPath =
                        AppRoutes.journeyDetail.split('/').last;
                    context.push('/home/$journeyDetailPath/${journey.id}',
                        extra: journey);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          // Consider logging the error stack here
          // ref.read(loggerProvider).e('Error loading journeys', error: error, stackTrace: stack);
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error loading journeys: $error',
                    style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 10),
                ElevatedButton(
                  // Refresh logic might need reconsideration - ref.refresh might work
                  onPressed: () => ref.refresh(userJourneysStreamProvider),
                  child: Text(l10n.homeScreenRetryButton),
                )
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: goToCreateJourney,
        tooltip: l10n.homeScreenAddJourneyTooltip,
        child: const Icon(Icons.add),
      ),
    );
  }
}
