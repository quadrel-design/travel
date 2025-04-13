import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart'; // Import Shadcn for ShadApp
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import generated class

void main() {
  group('Localization Tests', () {
    // Test Case 1: Verify a simple string can be loaded
    testWidgets('Loads English strings correctly', (WidgetTester tester) async {
      // Arrange: Build a simple app using ShadApp.materialRouter 
      // (similar to main.dart but without router/state)
      await tester.pumpWidget(
        ShadApp.material(
          // Provide localization delegates and locale
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'), // Force English locale for test
          
          // Define a simple Shadcn theme
          theme: ShadThemeData(
            brightness: Brightness.light,
            colorScheme: const ShadSlateColorScheme.light(),
          ),
          // The actual widget to test
          home: const TestWidget(localizationKey: 'errorTitle'),
        ),
      );
      // Add pumpAndSettle to wait for timers/animations
      await tester.pumpAndSettle();

      // Act: Find the Text widget displaying the localized string
      final textFinder = find.text('Error'); // Expected English string for errorTitle

      // Assert: Verify the text is found
      expect(textFinder, findsOneWidget);
    });

    // Test Case 2: Verify a parameterized string
    testWidgets('Loads parameterized English strings correctly', (WidgetTester tester) async {
      // Arrange
      const String testErrorMessage = 'Database connection failed';
      await tester.pumpWidget(
        ShadApp.material(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: ShadThemeData(
             brightness: Brightness.light,
             colorScheme: const ShadSlateColorScheme.light(),
           ),
          home: const TestWidget(
            localizationKey: 'journeyDeleteErrorDesc',
            parameter: testErrorMessage, // Pass the parameter
          ),
        ),
      );
      // Add pumpAndSettle here too
      await tester.pumpAndSettle();

      // Act: Find the Text widget with the formatted string
      final expectedString = 'Failed to delete journey: $testErrorMessage';
      final textFinder = find.text(expectedString);

      // Assert: Verify the text is found
      expect(textFinder, findsOneWidget);
    });
  });
}

// Simple helper widget to display a localized string based on a key
class TestWidget extends StatelessWidget {
  final String localizationKey;
  final Object? parameter; // Optional parameter for parameterized strings

  const TestWidget({super.key, required this.localizationKey, this.parameter});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String displayText = '';

    // Use a switch or map to get the correct localized string based on the key
    // This is a simplified example; a real app might use a more robust lookup
    switch (localizationKey) {
      case 'errorTitle':
        displayText = l10n.errorTitle;
        break;
      case 'journeyDeleteErrorDesc':
        displayText = l10n.journeyDeleteErrorDesc(parameter ?? 'Unknown error');
        break;
      // Add other keys here if needed for more tests
      default:
        displayText = 'Unknown Key';
    }

    return Scaffold(
      body: Center(
        child: Text(displayText),
      ),
    );
  }
} 