import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'providers/journey_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/user_provider.dart';
import 'screens/journey_list_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => JourneyProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Travel Expense Tracker',
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.activeBlue,
      ),
      home: JourneyListScreen(),
    );
  }
} 