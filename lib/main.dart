import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Travel App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => StreamBuilder<AuthState>(
              stream: Supabase.instance.client.auth.onAuthStateChange,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                      body: Center(child: CircularProgressIndicator()));
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final session = snapshot.data?.session;
                  final currentRoute = ModalRoute.of(context)?.settings.name;
                  if (session != null) {
                    if (currentRoute != '/home') {
                      Navigator.pushReplacementNamed(context, '/home');
                    }
                  } else {
                    if (currentRoute != '/auth') {
                      Navigator.pushReplacementNamed(context, '/auth');
                    }
                  }
                });
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              },
            ),
        '/auth': (context) => const AuthScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
