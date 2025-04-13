import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  // Ensure instantiation is REMOVED from here
  runApp(MyApp());
}

// --- Instantiate Repositories BEFORE Router --- 
final AuthRepository _authRepository = AuthRepository();

// --- Testable Redirect Logic --- 
String? determineRedirect(bool loggedIn, String? currentRoute) {
  final loggingIn = currentRoute == '/auth';
  final splashing = currentRoute == '/splash';

  print('[Redirect Check] Route: $currentRoute, LoggedIn: $loggedIn');

  // If not logged in and not going to auth, redirect to auth
  if (!loggedIn && !loggingIn) {
     print('[Redirect Check] Decision: Go to /auth');
    return '/auth';
  }

  // If logged in and on auth or splash, redirect to home
  if (loggedIn && (loggingIn || splashing)) {
     print('[Redirect Check] Decision: Go to /home');
    return '/home';
  }

  // No redirect needed
  print('[Redirect Check] Decision: No redirect needed.');
  return null;
}

// --- GoRouter Configuration --- 
final _router = GoRouter(
  initialLocation: '/splash',
  refreshListenable: GoRouterRefreshStream(_authRepository.authStateChanges),
  debugLogDiagnostics: true,
  routes: [
    // Splash screen while checking auth state initially
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(), // Create this simple widget
    ),
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(title: 'TravelMouse'),
      routes: [
         // Example nested route if needed
      ]
    ),
     GoRoute(
      path: '/create-journey',
      builder: (context, state) => const CreateJourneyScreen(),
    ),
    // Add the journey detail route
    GoRoute(
      path: '/journey-detail', // Define the path
      builder: (context, state) {
        // Journey type should now be recognized
        final journey = state.extra as Journey?;
        return journey != null 
            ? JourneyDetailScreen(journey: journey) 
            : const Scaffold(body: Center(child: Text('Error: Journey data missing')));
      },
    ),
    // Update Settings Route Path
    GoRoute(
      path: '/app-settings', // Change path 
      builder: (context, state) => const AppSettingsScreen(),
    ),
  ],
  redirect: (BuildContext context, GoRouterState state) {
    final loggedIn = _authRepository.currentSession != null;
    return determineRedirect(loggedIn, state.matchedLocation);
  },
);

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use ShadApp.materialRouter and pass the router configuration
    return ShadApp.materialRouter(
      routerConfig: _router, // Pass the router configuration
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
