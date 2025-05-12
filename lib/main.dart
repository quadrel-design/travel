/// Main entry point for the Flutter application.
/// Handles initialization (Firebase, Env Vars), sets up Riverpod providers,
/// configures GoRouter for navigation, and defines the root `MyApp` widget.
library;

// Essential Flutter, Riverpod, and Firebase imports
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode; // Removed defaultTargetPlatform, kIsWeb, TargetPlatform
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async'; // For StreamSubscription
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Generated files

// Project-specific imports (Ensure these paths are correct)
import 'screens/auth/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/project/project_create.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/invoices/invoice_capture_overview_screen.dart';
import 'screens/settings/app_settings_screen.dart';
import 'repositories/auth_repository.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/constants/app_routes.dart';
import 'package:travel/screens/project/project_overview_screen.dart';
import 'providers/logging_provider.dart';
import 'package:travel/screens/auth/auth_wait_screen.dart';
import 'package:travel/screens/user/user_management_screen.dart';
import 'models/project.dart';

/// Main application entry point.
/// Initializes essential services and runs the Flutter app.
Future<void> main() async {
  // Ensure Flutter bindings are initialized.
  WidgetsFlutterBinding.ensureInitialized();
  // It's tricky to use the Riverpod logger here before ProviderScope is initialized.
  // These print statements are for initial debug and can be removed for cleaner startup.
  // print('DEBUG: Firebase initialized.');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Load environment variables from .env file.
  // print('DEBUG: dotenv loaded.');
  await dotenv.load();

  // Run the app within a ProviderScope for Riverpod state management.
  // print('DEBUG: Calling runApp()...');
  runApp(const ProviderScope(child: MyApp()));
  // print('DEBUG: runApp() finished.');
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
                  final project = state.extra is Map
                      ? (state.extra as Map)['project'] as Project?
                      : state.extra as Project?;
                  if (project != null) {
                    return InvoiceCaptureOverviewScreen(project: project);
                  } else {
                    return Scaffold(
                      appBar: AppBar(title: const Text('Error')),
                      body: const Center(
                        child:
                            Text('Project not selected for invoice capture.'),
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
    final logger = ref.read(loggerProvider);
    logger.d('MyApp build() called');
    return MaterialApp.router(
      routerConfig: ref.watch(routerProvider),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

// Add a debug version of your home screen for tracing
class DebugHomeScreen extends ConsumerWidget {
  const DebugHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logger = ref.read(loggerProvider);
    logger.d('DebugHomeScreen build() called');
    // Example: If you use a provider for data
    // final data = ref.watch(yourProvider);
    // logger.d('DebugHomeScreen provider data: $data');

    return Scaffold(
      appBar: AppBar(title: const Text('Debug Home')),
      body: Center(
        child: Text('Debug: HomeScreen loaded'),
      ),
    );
  }
}
