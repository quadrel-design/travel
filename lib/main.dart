import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'screens/journey_create.dart';
import 'package:go_router/go_router.dart';
import 'screens/splash_screen.dart';
import 'dart:async'; // Import dart:async for StreamSubscription
import 'screens/journey_detail_screen.dart'; // Import detail screen
import 'models/journey.dart'; // Import Journey model
import 'screens/app_settings_screen.dart'; // Update import for settings screen
import 'constants/app_colors.dart'; // Import color constants
import 'repositories/auth_repository.dart'; // Import AuthRepository
// Import generated localizations delegate
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:travel/providers/repository_providers.dart'; // Import providers
import 'package:travel/constants/app_routes.dart'; // Import routes

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load();
  if (kDebugMode) {
    print('Environment variables loaded');
  }

  // Initialize Supabase
  if (kDebugMode) {
    print('Initializing Supabase...');
  }
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  if (kDebugMode) {
    print('Supabase initialized');
  }

  // Wrap MyApp with ProviderScope
  runApp(const ProviderScope(child: MyApp())); 
}

// Update redirect function to accept repository
String? determineRedirect(AuthRepository authRepo, String? currentRoute) {
  final loggingIn = currentRoute == AppRoutes.auth;
  final splashing = currentRoute == AppRoutes.splash;

  print('[Redirect Check] Route: $currentRoute, LoggedIn: ${authRepo.currentSession != null}');

  // If not logged in and not going to auth, redirect to auth
  if (authRepo.currentSession == null && !loggingIn) {
     print('[Redirect Check] Decision: Go to ${AppRoutes.auth}');
    return AppRoutes.auth;
  }

  // If logged in and on auth or splash, redirect to home
  if (authRepo.currentSession != null && (loggingIn || splashing)) {
     print('[Redirect Check] Decision: Go to ${AppRoutes.home}');
    return AppRoutes.home;
  }

  // No redirect needed
  print('[Redirect Check] Decision: No redirect needed.');
  return null;
}

// --- GoRouter Configuration --- 
// Make router accessible via a provider for easier access to Ref
final routerProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: GoRouterRefreshStream(authRepository.authStateChanges),
    debugLogDiagnostics: true,
    routes: [
      // Splash screen while checking auth state initially
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(), // Create this simple widget
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(title: 'TravelMouse'),
        routes: [
           // Example nested route if needed
        ]
      ),
       GoRoute(
        path: AppRoutes.createJourney,
        builder: (context, state) => const CreateJourneyScreen(),
      ),
      // Add the journey detail route
      GoRoute(
        path: AppRoutes.journeyDetail,
        builder: (context, state) {
          final journey = state.extra as Journey?;
          final l10n = AppLocalizations.of(context)!;
          return journey != null 
              ? JourneyDetailScreen(journey: journey) 
              : Scaffold(body: Center(child: Text(l10n.detailScreenErrorMissingData)));
        },
      ),
      // Update Settings Route Path
      GoRoute(
        path: AppRoutes.appSettings,
        builder: (context, state) => const AppSettingsScreen(),
      ),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      // Read repository inside redirect via ref (obtained from provider)
      // Note: Accessing ref directly here isn't straightforward.
      // Alternative: Pass repository into determineRedirect.
      final loggedIn = authRepository.currentSession != null;
      return determineRedirect(authRepository, state.matchedLocation);
    },
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
class MyApp extends ConsumerWidget { // Change to ConsumerWidget
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) { // Add WidgetRef
    final router = ref.watch(routerProvider); // Watch the router provider

    return ShadApp.materialRouter(
      routerConfig: router, // Use the router from the provider
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadSlateColorScheme.light(),
        textTheme: ShadTextTheme.fromGoogleFont(GoogleFonts.inter),
      ),
      materialThemeBuilder: (context, shadTheme) {
        return shadTheme.copyWith(
          scaffoldBackgroundColor: Colors.white,
          textTheme: shadTheme.textTheme, 
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            titleSpacing: NavigationToolbar.kMiddleSpacing,
            shape: Border(
              bottom: BorderSide(
                color: AppColors.borderGrey,
                width: 1.0,
              ),
            ),
          ),
        );
      },
      // Add Localization settings
      localizationsDelegates: AppLocalizations.localizationsDelegates, 
      supportedLocales: AppLocalizations.supportedLocales,
      // title is set by MaterialApp generated internally or on pages
      debugShowCheckedModeBanner: false,
    );
  }
}
