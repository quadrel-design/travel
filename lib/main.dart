/// Main entry point for the Flutter application.
/// Handles initialization (Firebase, Env Vars), sets up Riverpod providers,
/// configures GoRouter for navigation, and defines the root `MyApp` widget.
library;

// Essential Flutter, Riverpod, and Firebase imports
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kDebugMode, kIsWeb, TargetPlatform;
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async'; // For StreamSubscription

// Generated files
import 'firebase_options.dart'; // Import generated options
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Project-specific imports (Ensure these paths are correct)
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/project_create.dart';
import 'screens/splash_screen.dart';
import 'screens/invoice_capture_overview_screen.dart';
import 'screens/settings/app_settings_screen.dart';
import 'repositories/auth_repository.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/constants/app_routes.dart';
import 'package:travel/theme/antonetti_theme.dart';
import 'package:travel/screens/project_detail_overview_screen.dart';
import 'providers/logging_provider.dart';
import 'package:travel/screens/auth_wait_screen.dart';
import 'package:travel/screens/project_expenses_screen.dart';
import 'package:travel/screens/user_management_screen.dart';
import 'models/project.dart';

// --- Provider for Firebase Initialization ---
final firebaseInitializationProvider = FutureProvider<FirebaseApp>((ref) async {
  print('DEBUG: firebaseInitializationProvider executing...');
  final app = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Log that the Dart await completed
  print(
    'DEBUG: firebaseInitializationProvider COMPLETED (Dart await returned).',
  );

  // TEMPORARY TEST REMOVED

  print('DEBUG: firebaseInitializationProvider returning app.');
  return app;
});
// --- End Provider ---

/// Main application entry point.
/// Initializes essential services and runs the Flutter app.
Future<void> main() async {
  // Ensure Flutter bindings are initialized.
  WidgetsFlutterBinding.ensureInitialized();
  print('DEBUG: main() started.'); // Log start

  // Load environment variables from .env file.
  await dotenv.load();
  print('DEBUG: dotenv loaded.'); // Log dotenv

  // NOTE: Explicit Firebase.initializeApp() call is moved to the provider above

  // Connect to Firebase Emulators in debug mode (Keep this section if you use emulators)
  if (kDebugMode) {
    try {
      // Use Firebase Functions Emulator.
      // FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
      // print('🔥 Using Firebase Functions Emulator at localhost:5001');
    } catch (e) {
      print('⚠️ Error connecting to Firebase Functions Emulator: $e');
    }
    // Connect to Firestore Emulator
    try {
      // FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      // print('🔥 Using Firebase Firestore Emulator at localhost:8080');
    } catch (e) {
      print('⚠️ Error connecting to Firebase Firestore Emulator: $e');
    }
    // Connect to Auth Emulator
    try {
      // FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      // print('🔥 Using Firebase Auth Emulator at localhost:9099');
    } catch (e) {
      print('⚠️ Error connecting to Firebase Auth Emulator: $e');
    }
    // Connect to Storage Emulator
    try {
      // FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
      // print('🔥 Using Firebase Storage Emulator at localhost:9199');
    } catch (e) {
      print('⚠️ Error connecting to Firebase Storage Emulator: $e');
    }
  }

  // Run the app within a ProviderScope for Riverpod state management.
  print('DEBUG: Calling runApp()...'); // Log before runApp
  runApp(const ProviderScope(child: MyApp()));
  print('DEBUG: runApp() finished.'); // Log after runApp
}

// Update redirect function to accept repository
// NOTE: This function seems unused now that redirect logic is inside routerProvider.
// Consider removing if it's definitely not called elsewhere.
String? determineRedirect(AuthRepository authRepo, String? currentRoute) {
  final loggingIn = currentRoute == AppRoutes.auth;
  final splashing = currentRoute == AppRoutes.splash;

  if (authRepo.currentUser == null && !loggingIn) {
    return AppRoutes.auth;
  }

  if (authRepo.currentUser != null && (loggingIn || splashing)) {
    return AppRoutes.home;
  }
  return null;
}

// --- GoRouter Configuration ---
final routerProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final logger = ref.watch(loggerProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: GoRouterRefreshStream(authRepository.authStateChanges),
    debugLogDiagnostics: kDebugMode,
    redirect: (BuildContext context, GoRouterState state) {
      final loggedIn = authRepository.currentUser != null;
      final emailVerified =
          loggedIn && (authRepository.currentUser?.emailVerified ?? false);
      final location = state.matchedLocation;

      logger.d(
        'Redirect check: location=$location, loggedIn=$loggedIn, emailVerified=$emailVerified',
      );

      if (!loggedIn) {
        return location == AppRoutes.auth ? null : AppRoutes.auth;
      }

      if (loggedIn) {
        if (!emailVerified) {
          return location == AppRoutes.authWait ? null : AppRoutes.authWait;
        } else {
          if (location == AppRoutes.splash ||
              location == AppRoutes.auth ||
              location == AppRoutes.authWait) {
            return AppRoutes.home;
          }
          return null;
        }
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) =>
            Theme(data: ThemeData.light(), child: const AuthScreen()),
      ),
      GoRoute(
        path: AppRoutes.authWait,
        builder: (context, state) => const AuthWaitScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: '${AppRoutes.projectDetail.split('/').last}/:projectId',
            builder: (context, state) {
              final projectId = state.pathParameters['projectId'];
              final project = state.extra as Project?;
              if (projectId != null && project != null) {
                return ProjectDetailOverviewScreen(project: project);
              } else {
                return Scaffold(
                  appBar: AppBar(title: const Text('Error')),
                  body: const Center(child: Text('Project data missing.')),
                );
              }
            },
            routes: [
              GoRoute(
                path: AppRoutes.invoiceCaptureOverview.split('/').last,
                builder: (context, state) {
                  final project = state.extra as Project?;
                  if (project != null) {
                    return InvoiceCaptureOverviewScreen(project: project);
                  } else {
                    return Scaffold(
                      appBar: AppBar(title: const Text('Error')),
                      body: const Center(
                        child: Text(
                          'Project data missing for invoice capture.',
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.createProject.split('/').last,
            builder: (context, state) => const ProjectCreateScreen(),
          ),
          GoRoute(
            path: AppRoutes.appSettings.split('/').last,
            builder: (context, state) => const AppSettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.userManagement.split('/').last,
            builder: (context, state) => const UserManagementScreen(),
          ),
          GoRoute(
            path:
                '${AppRoutes.projectDetail.split('/').last}/:projectId/expenses',
            builder: (context, state) {
              final projectId = state.pathParameters['projectId'];
              if (projectId != null) {
                return ProjectExpensesScreen(projectId: projectId);
              } else {
                return const Scaffold(
                  body: Center(child: Text('Missing project ID')),
                );
              }
            },
          ),
        ],
      ),
    ],
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

/// The root widget of the application.
/// Waits for Firebase initialization before building the main app.
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the initialization provider
    final firebaseInitialization = ref.watch(firebaseInitializationProvider);

    // Show loading while Firebase initializes, or error if it fails
    return firebaseInitialization.when(
      loading: () {
        print('DEBUG: MyApp waiting for Firebase init...'); // Log loading
        // Show a simple loading screen
        return const MaterialApp(
          home: Scaffold(body: Center(child: CircularProgressIndicator())),
          debugShowCheckedModeBanner: false,
        );
      },
      error: (err, stack) {
        print('DEBUG: MyApp Firebase init FAILED: $err'); // Log error
        // Show an error screen
        return MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Firebase Init Failed: $err')),
          ),
          debugShowCheckedModeBanner: false,
        );
      },
      data: (firebaseApp) {
        print(
          'DEBUG: MyApp Firebase init complete, building main app...',
        ); // Log success
        // Firebase is ready, build the main app with the router
        final router = ref.watch(
          routerProvider,
        ); // Now it's safe to watch router
        return MaterialApp.router(
          routerConfig: router,
          theme: antonettiTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
