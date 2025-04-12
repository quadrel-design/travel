import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'screens/create_journey_screen.dart';
import 'package:go_router/go_router.dart';
import 'screens/splash_screen.dart';
import 'dart:async'; // Import dart:async for StreamSubscription

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

  runApp(MyApp());
}

// --- GoRouter Configuration --- 
final _router = GoRouter(
  initialLocation: '/splash',
  refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
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
  ],
  redirect: (BuildContext context, GoRouterState state) {
    final loggedIn = Supabase.instance.client.auth.currentSession != null;
    final currentRoute = state.matchedLocation;
    
    print('[GoRouter Redirect Attempt] Current: $currentRoute, LoggedIn: $loggedIn');

    // If not logged in and not already on the auth route, redirect to auth
    if (!loggedIn && currentRoute != '/auth') {
      print('[GoRouter Redirect] Redirecting to /auth');
      return '/auth';
    }

    // If logged in and currently on auth or splash route, redirect to home
    if (loggedIn && (currentRoute == '/auth' || currentRoute == '/splash')) {
      print('[GoRouter Redirect] Redirecting to /home');
      return '/home';
    }

    // Otherwise, no redirect needed (already on correct screen or non-auth related screen)
    print('[GoRouter Redirect] No redirect needed for $currentRoute');
    return null;
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
        // shadTheme already contains a TextTheme derived from ShadTextTheme
        return shadTheme.copyWith(
          scaffoldBackgroundColor: Colors.white,
          // Apply the TextTheme from shadTheme to Material theme
          // This assumes Shadcn's generated TextTheme is suitable for Material
          textTheme: shadTheme.textTheme, // Apply generated textTheme
          // Remove fontFamily, as it's handled by textTheme
          // fontFamily: GoogleFonts.inter().fontFamily, 
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            // AppBar titleTextStyle will now inherit from the overall textTheme
            // We might need to customize it specifically if the default isn't right
            // titleTextStyle: GoogleFonts.inter(...), // Removed explicit AppBar font style
            titleSpacing: NavigationToolbar.kMiddleSpacing,
            shape: Border(
              bottom: BorderSide(
                color: Colors.grey.shade400,
                width: 1.0,
              ),
            ),
          ),
        );
      },
      // Title is now part of router config usually, or specific screens
      // title: 'Travel App',
      debugShowCheckedModeBanner: false,
      // Remove initialRoute/routes, handled by GoRouter
      // initialRoute: '/',
      // routes: { ... },
    );
  }
}
