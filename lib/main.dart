/**
 * Main entry point for the Flutter application.
 * Handles initialization (Firebase, Env Vars), sets up Riverpod providers,
 * configures GoRouter for navigation, and defines the root `MyApp` widget.
 */
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/journey_create.dart';
import 'package:go_router/go_router.dart';
import 'screens/splash_screen.dart';
import 'dart:async'; // Import dart:async for StreamSubscription
import 'screens/invoice_capture_overview_screen.dart'; // Import renamed gallery screen
import 'models/journey.dart'; // Import Journey model
import 'screens/settings/app_settings_screen.dart'; // Update import for settings screen (using current filename)
import 'repositories/auth_repository.dart'; // Import AuthRepository
// Import generated localizations delegate
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:travel/providers/repository_providers.dart'; // Import providers
// Import service providers
import 'package:travel/constants/app_routes.dart'; // Import routes
import 'package:travel/theme/antonetti_theme.dart'; // Import the custom theme
import 'package:travel/screens/journey_detail_overview_screen.dart'; // Import new overview screen
import 'providers/logging_provider.dart'; // Add import for logger
import 'package:travel/screens/auth_wait_screen.dart'; // Add import for wait screen
import 'package:travel/screens/journey_expenses_screen.dart';
import 'package:travel/screens/user_management_screen.dart';

// Firebase imports
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Import generated options
import 'package:cloud_functions/cloud_functions.dart';

/// Main application entry point.
/// Initializes essential services and runs the Flutter app.
void main() async {
  // Ensure Flutter bindings are initialized.
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file.
  await dotenv.load();

  // Initialize Firebase using platform-specific options.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Connect to Firebase Emulators in debug mode
  if (kDebugMode) {
    try {
      // Use Firebase Functions Emulator.
      FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
      print('🔥 Using Firebase Functions Emulator at localhost:5001');
    } catch (e) {
      print('⚠️ Error connecting to Firebase Functions Emulator: $e');
    }
    // TODO: Add connections for Firestore, Auth, Storage emulators if used.
  }

  // Initialize Supabase (if used)
  // await Supabase.initialize(...);

  // Initialize Logger (assuming setup is within providers or elsewhere)

  // Run the app within a ProviderScope for Riverpod state management.
  runApp(ProviderScope(
    child: const MyApp(),
  ));
}

// Update redirect function to accept repository
String? determineRedirect(AuthRepository authRepo, String? currentRoute) {
  final loggingIn = currentRoute == AppRoutes.auth;
  final splashing = currentRoute == AppRoutes.splash;

  // Check currentUser instead of currentSession
  if (authRepo.currentUser == null && !loggingIn) {
    return AppRoutes.auth;
  }

  // Check currentUser instead of currentSession
  if (authRepo.currentUser != null && (loggingIn || splashing)) {
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

    // Updated Redirect Logic
    redirect: (BuildContext context, GoRouterState state) {
      final loggedIn = authRepository.currentUser != null;
      final emailVerified =
          loggedIn && (authRepository.currentUser?.emailVerified ?? false);
      final location = state.matchedLocation; // Use matchedLocation

      logger.d(
          'Redirect check: location=$location, loggedIn=$loggedIn, emailVerified=$emailVerified');

      // If user is not logged in:
      if (!loggedIn) {
        // Allow access only to /auth, otherwise redirect to /auth
        return location == AppRoutes.auth ? null : AppRoutes.auth;
      }

      // If user IS logged in:
      if (loggedIn) {
        // If email is NOT verified:
        if (!emailVerified) {
          // Allow access only to /auth-wait, otherwise redirect there
          return location == AppRoutes.authWait ? null : AppRoutes.authWait;
        }
        // If email IS verified:
        else {
          // If they are on /auth or /auth-wait, redirect to /home
          if (location == AppRoutes.auth || location == AppRoutes.authWait) {
            return AppRoutes.home;
          }
          // Otherwise, let them stay where they are (e.g., /home, /settings, etc.)
          return null;
        }
      }

      return null; // Default: no redirect
    },

    routes: [
      // Splash screen while checking auth state initially
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) =>
            // Wrap AuthScreen with a standard light theme, overriding the main app theme.
            // This might be desired for a standard authentication look & feel.
            Theme(
          data: ThemeData.light(), // Apply standard light theme
          child: const AuthScreen(),
        ),
      ),
      // Add route for the verification wait screen
      GoRoute(
        path: AppRoutes.authWait,
        builder: (context, state) => const AuthWaitScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
        routes: [
          // Nested routes require a unique path segment
          GoRoute(
              // Path needs to be relative to parent ('/home')
              path: '${AppRoutes.journeyDetail.split('/').last}/:journeyId',
              builder: (context, state) {
                // Extract journeyId safely
                final journeyId = state.pathParameters['journeyId'];
                // Pass journey object if available (e.g., from state.extra)
                final journey = state.extra as Journey?;
                if (journeyId != null && journey != null) {
                  // Correct the screen name
                  return JourneyDetailOverviewScreen(journey: journey);
                } else {
                  // Handle error: missing journeyId or journey object
                  // Maybe navigate back or show an error screen
                  // For now, returning a placeholder
                  return Scaffold(
                      appBar: AppBar(title: const Text('Error')),
                      body: const Center(child: Text('Journey data missing.')));
                }
              },
              // Add gallery route nested under journey detail
              routes: [
                GoRoute(
                  path: AppRoutes.invoiceCaptureOverview.split('/').last,
                  builder: (context, state) {
                    final journey = state.extra as Journey?;
                    if (journey != null) {
                      return InvoiceCaptureOverviewScreen(journey: journey);
                    } else {
                      return Scaffold(
                          appBar: AppBar(title: const Text('Error')),
                          body: const Center(
                              child: Text(
                                  'Journey data missing for invoice capture.')));
                    }
                  },
                ),
              ]),
          GoRoute(
            path: AppRoutes.createJourney.split('/').last, // Relative path
            builder: (context, state) => const CreateJourneyScreen(),
          ),
          GoRoute(
            path: AppRoutes.appSettings.split('/').last, // Relative path
            builder: (context, state) => const AppSettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.userManagement.split('/').last, // Relative path
            builder: (context, state) => const UserManagementScreen(),
          ),
          GoRoute(
            path:
                '${AppRoutes.journeyDetail.split('/').last}/:journeyId/expenses',
            builder: (context, state) {
              final journeyId = state.pathParameters['journeyId'];
              if (journeyId != null) {
                return ExpenseListScreen(journeyId: journeyId);
              } else {
                return const Scaffold(
                  body: Center(child: Text('Missing journey ID')),
                );
              }
            },
          ),
        ],
      ),
      // Add other top-level routes if needed
    ],
  );
});

// Helper class to bridge Stream and Listenable for GoRouter
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners(); // Notify initially
    _subscription = stream
        .asBroadcastStream()
        .listen((_) => notifyListeners() // Notify on stream events
            );
  }
  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
// --- End GoRouter Configuration ---

/// The root widget of the application.
/// Consumes the [routerProvider] and sets up [MaterialApp.router]
/// with the application theme and localization delegates.
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
