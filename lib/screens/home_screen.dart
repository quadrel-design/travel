import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
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
      print("Error loading journeys: $e");
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
    final l10n = AppLocalizations.of(context)!; // Get l10n

    Widget bodyContent;
    if (screenState.isLoading) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (screenState.error != null) {
      bodyContent = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(screenState.error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 10),
            ShadButton(
              onPressed: _refreshJourneys,
              child: Text(l10n.homeScreenRetryButton) // Use l10n
            )
          ],
        ),
      );
    } else if (journeys.isEmpty) {
      bodyContent = Center(child: Text(l10n.homeScreenNoJourneys)); // Use l10n
    } else {
      bodyContent = ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: journeys.length,
        itemBuilder: (context, index) {
          final journey = journeys[index];
          return GestureDetector(
            onTap: () {
              context.push('/journey-detail', extra: journey);
              print('Navigating to detail for: ${journey.title}');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ShadCard(
                title: Text(journey.title, style: ShadTheme.of(context).textTheme.h4),
                description: Text(journey.description),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'From: ${_dateFormat.format(journey.start_date)}\n'
                    'To:     ${_dateFormat.format(journey.end_date)}',
                    style: ShadTheme.of(context).textTheme.muted,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const AppTitle(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshJourneys,
            tooltip: l10n.homeScreenRefreshTooltip, // Use l10n
          ),
          ShadButton.ghost(
            icon: const Icon(LucideIcons.circleUserRound, size: 20),
            onPressed: () => context.go(AppRoutes.appSettings),
          ),
        ],
      ),
      body: bodyContent,
      floatingActionButton: FloatingActionButton(
         onPressed: _goToCreateJourney,
         tooltip: l10n.homeScreenAddJourneyTooltip, // Use l10n
         child: const Icon(Icons.add), 
       ),
    );
  }
}
