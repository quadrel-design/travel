import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:travel/models/journey.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/widgets/app_title.dart';
import 'package:travel/constants/app_routes.dart'; // Import routes
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import
import 'package:travel/repositories/journey_repository.dart'; // Add import
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
  final JourneyRepository _journeyRepository;
  final AuthRepository _authRepository;

  HomeScreenNotifier(this._journeyRepository, this._authRepository) 
      : super(const HomeScreenState()) {
    loadJourneys(); // Load journeys on initialization
  }

  Future<void> loadJourneys() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final userId = _authRepository.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }
      final loadedJourneys = await _journeyRepository.fetchUserJourneys(userId);
      state = state.copyWith(journeys: loadedJourneys, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: 'Failed to load journeys', isLoading: false);
    }
  }
}

// Create the Provider
final homeScreenProvider = StateNotifierProvider<HomeScreenNotifier, HomeScreenState>((ref) {
  final journeyRepo = ref.watch(journeyRepositoryProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  return HomeScreenNotifier(journeyRepo, authRepo);
});

// --- End State Management Setup ---


// Change to ConsumerStatefulWidget
class HomeScreen extends ConsumerStatefulWidget {
  final String title; // Keep title if passed via routing

  const HomeScreen({Key? key, required this.title}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

// Change to ConsumerState
class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Remove local state variables managed by Riverpod
  // bool _isLoading = true;
  // String? _error;
  // List<Journey> _journeys = [];
  
  // Remove repository instances, access via ref
  // final JourneyRepository _journeyRepository = JourneyRepository();
  // final AuthRepository _authRepository = AuthRepository();

  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    // Initial load triggered by provider initialization
    // Optional: Trigger refresh here if needed on screen init
    // WidgetsBinding.instance.addPostFrameCallback((_) { 
    //   ref.read(homeScreenProvider.notifier).loadJourneys();
    // });
  }

  // Remove _loadJourneys function - logic moved to Notifier
  // Future<void> _loadJourneys() async { ... }

  void _goToCreateJourney() {
    context.push(AppRoutes.createJourney).then((_) {
       ref.read(homeScreenProvider.notifier).loadJourneys(); 
    });
  }
  
  void _refreshJourneys() {
     ref.read(homeScreenProvider.notifier).loadJourneys();
  }

  @override
  Widget build(BuildContext context) {
    final screenState = ref.watch(homeScreenProvider);
    final journeys = screenState.journeys;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context); // Get Material theme

    Widget bodyContent;
    if (screenState.isLoading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (screenState.error != null) {
      bodyContent = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(screenState.error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 10),
            // Use Material Button (styling from theme)
            ElevatedButton( 
              onPressed: _refreshJourneys,
              child: Text(l10n.homeScreenRetryButton)
            )
          ],
        ),
      );
    } else if (journeys.isEmpty) {
      bodyContent = Center(child: Text(l10n.homeScreenNoJourneys));
    } else {
      bodyContent = ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8), 
        itemCount: journeys.length,
        itemBuilder: (context, index) {
          final journey = journeys[index];
          final dateRange = '${_dateFormat.format(journey.startDate)} - ${_dateFormat.format(journey.endDate)}';

          return Card( 
            // Styling (elevation, shape, margin, color) comes from antonettiCardTheme
            child: ListTile( 
              // Styling (padding, density, text) comes from antonettiListTileTheme & textTheme
              title: Text(journey.title), 
              subtitle: Text(
                '${journey.description}\n$dateRange',
                 maxLines: 2, 
                 overflow: TextOverflow.ellipsis, 
              ),
              trailing: Icon(Icons.chevron_right, color: theme.colorScheme.outline), // Material icon
              onTap: () {
                context.push(AppRoutes.journeyDetail, extra: journey);
              },
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const AppTitle(), 
        actions: [
          // Replace ShadButton with IconButton
          IconButton(
            icon: const Icon(Icons.settings_outlined), // Material icon
            tooltip: 'App Settings', // TODO: Localize
            onPressed: () => context.push(AppRoutes.appSettings),
          ),
        ],
      ),
      body: bodyContent,
      floatingActionButton: FloatingActionButton(
         onPressed: _goToCreateJourney,
         tooltip: l10n.homeScreenAddJourneyTooltip,
         child: const Icon(Icons.add), 
       ),
    );
  }
}
