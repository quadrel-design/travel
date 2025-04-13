import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:travel/main.dart' as app; // Import main app entry point
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shadcn_ui/shadcn_ui.dart'; // For finding Shadcn widgets

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Load .env variables before tests run
    // Make sure .env exists at the root where the test command is run
    try {
      await dotenv.load(fileName: ".env"); 
      print('dotenv loaded successfully for integration test.');
    } catch (e) {
      print('Error loading .env for integration test: $e. Ensure .env is at project root.');
      // Optionally fail test if .env is critical
    }
  });

  group('App Integration Tests', () {
    testWidgets('Login and navigate to HomeScreen', (WidgetTester tester) async {
      // Start the app
      app.main(); // Calls the main function from lib/main.dart
      
      // Wait for the app to settle, should redirect to /auth
      await tester.pumpAndSettle(const Duration(seconds: 5)); // Allow time for redirects

      print('App loaded, finding AuthScreen elements...');
      
      // --- Find Auth Screen Elements ---
      // Find email field (using placeholder text)
      final emailFinder = find.widgetWithText(ShadInputFormField, 'Enter your email');
      expect(emailFinder, findsOneWidget, reason: 'Email field should be present');

      // Find password field
      final passwordFinder = find.widgetWithText(ShadInputFormField, 'Enter your password');
       expect(passwordFinder, findsOneWidget, reason: 'Password field should be present');
       
       // Find Sign In button (assuming it starts in Sign In mode)
      final signInButtonFinder = find.widgetWithText(ShadButton, 'Sign In');
      expect(signInButtonFinder, findsOneWidget, reason: 'Sign In button should be present');

      print('AuthScreen elements found. Entering credentials...');

      // --- Interact with Auth Screen --- 
      // Use environment variables for credentials
      final email = dotenv.env['DEV_EMAIL'];
      final password = dotenv.env['DEV_PASSWORD'];
      expect(email, isNotNull, reason: 'DEV_EMAIL not found in .env');
      expect(password, isNotNull, reason: 'DEV_PASSWORD not found in .env');
      
      // Enter text
      await tester.enterText(emailFinder, email!); 
      await tester.enterText(passwordFinder, password!); 
      await tester.pumpAndSettle(); // Allow fields to update

      print('Credentials entered. Tapping Sign In...');
      
      // Tap Sign In button
      await tester.tap(signInButtonFinder); 
      await tester.pumpAndSettle(const Duration(seconds: 10)); // Allow time for Supabase call & navigation

      print('Pumped after Sign In tap. Checking for HomeScreen...');

      // --- Verify Navigation to HomeScreen --- 
      // Check for an element unique to HomeScreen, e.g., the AppBar title/logo 
      // (We use AppTitle widget which contains the Text 'TravelMouse')
      final homeTitleFinder = find.widgetWithText(Row, 'TravelMouse'); // Find Row containing Text
      expect(homeTitleFinder, findsOneWidget, reason: 'HomeScreen title/logo should be visible after login');

      // Optionally, check for the FloatingActionButton
      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget, reason: 'FloatingActionButton should be on HomeScreen');
      
       print('HomeScreen found. Login test successful.');
    });

    // Add more tests here for other flows (Sign Up, Journey Creation, etc.)

  });
} 