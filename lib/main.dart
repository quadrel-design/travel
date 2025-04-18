import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/journey_create.dart';
import 'package:go_router/go_router.dart';
import 'screens/splash_screen.dart';
import 'dart:async'; // Import dart:async for StreamSubscription
import 'screens/journey_detail_screen.dart'; // Import detail screen
import 'screens/gallery_overview_screen.dart'; // Import renamed gallery screen
import 'models/journey.dart'; // Import Journey model
import 'screens/settings/app_settings_screen.dart'; // Update import for settings screen (using current filename)
import 'repositories/auth_repository.dart'; // Import AuthRepository
// Import generated localizations delegate
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:travel/providers/repository_providers.dart'; // Import providers
import 'package:travel/constants/app_routes.dart'; // Import routes
import 'package:travel/theme/antonetti_theme.dart'; // Import the custom theme
import 'package:travel/screens/journey_detail_overview_screen.dart'; // Import new overview screen
import 'screens/expense_list_screen.dart'; // Add import for the new screen
import 'providers/logging_provider.dart'; // Add import for logger
import 'package:logger/logger.dart'; // Add Logger import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load();

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Wrap MyApp with ProviderScope
  runApp(const ProviderScope(child: MyApp()));
}

// Update redirect function to accept repository
String? determineRedirect(AuthRepository authRepo, String? currentRoute) {
  final loggingIn = currentRoute == AppRoutes.auth;
  final splashing = currentRoute == AppRoutes.splash;

  // If not logged in and not going to auth, redirect to auth
  if (authRepo.currentSession == null && !loggingIn) {
    return AppRoutes.auth;
  }

  // If logged in and on auth or splash, redirect to home
  if (authRepo.currentSession != null && (loggingIn || splashing)) {
    return AppRoutes.home;
  }

  // No redirect needed
  return null;
}

// --- GoRouter Configuration ---
// Make router accessible via a provider for easier access to Ref
final routerProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final logger = ref.watch(loggerProvider); // Get the logger
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: GoRouterRefreshStream(authRepository.authStateChanges),
    debugLogDiagnostics: kDebugMode, // Only log in debug mode
    routes: [
      // Splash screen while checking auth state initially
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(), // Add const
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) => const AuthScreen(), // Add const
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(title: 'TravelMouse'),
        routes: const [
          // Example nested route if needed
        ],
      ),
      GoRoute(
        path: AppRoutes.createJourney,
        builder: (context, state) => const CreateJourneyScreen(),
      ),
      // Add the journey detail route
      GoRoute(
        path: '${AppRoutes.journeyDetail}/:journeyId',
        builder: (context, state) {
          final journeyId = state.pathParameters['journeyId'];
          final journey = state.extra as Journey?;
          if (journeyId == null || journey == null) {
            // Replace print with logger
            logger.w('Journey ID or Journey object missing for detail route');
            // Maybe return a Scaffold with an error message
            return const Scaffold(body: Center(child: Text('Error: Journey data missing')));
          }
          return JourneyDetailOverviewScreen(journey: journey);
        },
        routes: [
          GoRoute(
            path: 'info',
            builder: (context, state) {
               final journey = state.extra as Journey?;
               if (journey == null) return const Scaffold(body: Center(child: Text('Error: Journey data missing')));
               return JourneyDetailScreen(journey: journey);
            },
          ),
          GoRoute(
            path: 'gallery',
            builder: (context, state) {
              final journey = state.extra as Journey?;
               if (journey == null) {
                 // Replace print with logger
                 logger.w('Error: Journey object missing for gallery route');
                 return const Scaffold(body: Center(child: Text('Error: Journey data missing')));
               }
              return GalleryOverviewScreen(journey: journey);
            },
          ),
          // --- Add Expense List Route --- 
          GoRoute(
            name: 'journeyExpenses', // Define a name
            path: 'expenses', // Define the sub-path
            builder: (context, state) {
               final journeyId = state.pathParameters['journeyId'];
               if (journeyId == null || journeyId.isEmpty) {
                  // Replace print with logger
                  logger.w('Journey ID missing for expenses route');
                  return const Scaffold(body: Center(child: Text('Error: Journey ID missing')));
               }
              return ExpenseListScreen(journeyId: journeyId);
            },
          ),
          // --- End Add Expense List Route --- 
        ],
      ),
      // Update Settings Route Path
      GoRoute(
        path: AppRoutes.appSettings,
        builder: (context, state) => const AppSettingsScreen(),
      ),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      return determineRedirect(authRepository, state.matchedLocation);
    },
    errorBuilder: (context, state) => _buildErrorScreen(context, state, logger), // Pass logger to error builder
  );
});

// Helper class to bridge Stream and Listenable for GoRouter
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
// --- End GoRouter Configuration ---

// Update MyApp to consume the router provider
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Change to MaterialApp.router
    return MaterialApp.router(
      routerConfig: router,
      // Apply the custom Material theme directly
      theme: antonettiTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- Simple Error Screen Widget ---
Widget _buildErrorScreen(BuildContext context, GoRouterState state, Logger logger) {
  // final l10n = AppLocalizations.of(context)!;
  logger.e('GoRouter navigation error: ${state.error}'); // Use logger instead of print

  return Scaffold(
    appBar: AppBar(
      // Use localization
      // title: Text(l10n.navigationErrorTitle),
      title: const Text('Navigation Error'), // Placeholder
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        // Use localization
        // child: Text(l10n.navigationErrorText(state.error?.toString() ?? 'Unknown error')),
        child: Text('Error: ${state.error?.toString() ?? 'Unknown error'}'), // Placeholder
      ),
    ),
  );
}
// --- End Simple Error Screen Widget ---
