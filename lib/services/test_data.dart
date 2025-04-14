import 'dart:math';
import '../models/expense.dart';
import '../models/journey.dart';
import '../models/user.dart' as local_user;
import 'package:uuid/uuid.dart';

// Use flutter/foundation.dart for kDebugMode checks if needed for logging
import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/journey_repository.dart'; // Import JourneyRepository

final random = Random();
const uuid = Uuid();

// Sample Users
final local_user.User user1 = local_user.User(
  id: uuid.v4(),
  email: 'user1@example.com',
  name: 'Alice',
  profileImageUrl: 'https://example.com/alice.jpg',
);

final local_user.User user2 = local_user.User(
  id: uuid.v4(),
  email: 'user2@example.com',
  name: 'Bob',
);

// Sample Journeys
final Journey journey1 = Journey(
  id: 'journey-1',
  title: 'European Adventure',
  description: 'Exploring the capitals of Europe.',
  location: 'Europe',
  budget: 5000.0,
  userId: user1.id,
  startDate: DateTime.now().subtract(const Duration(days: 30)),
  endDate: DateTime.now().subtract(const Duration(days: 15)),
  isCompleted: false,
);

final Journey journey2 = Journey(
  id: 'journey-2',
  title: 'Asian Expedition',
  description: 'A journey through Southeast Asia.',
  location: 'Asia',
  budget: 3000.0,
  userId: user2.id,
  startDate: DateTime.now().subtract(const Duration(days: 60)),
  endDate: DateTime.now().subtract(const Duration(days: 40)),
  isCompleted: true,
);

// Sample Expenses
final List<Expense> sampleExpenses = [
  Expense(
    id: 'expense-1',
    journeyId: journey1.id,
    title: 'Train Ticket Paris-Berlin',
    amount: 120.50,
    date: journey1.startDate.add(const Duration(days: 2)),
    category: 'Transportation',
    paidBy: user1.id,
    sharedWith: [user1.id], // Assuming Alice paid for herself only initially
    description: 'High-speed train journey.',
  ),
  Expense(
    id: 'expense-2',
    journeyId: journey1.id,
    title: 'Hostel in Berlin',
    amount: 250.00,
    date: journey1.startDate.add(const Duration(days: 3)),
    category: 'Accommodation',
    paidBy: user1.id,
    sharedWith: [user1.id],
  ),
  Expense(
    id: 'expense-3',
    journeyId: journey2.id,
    title: 'Street Food in Bangkok',
    amount: 15.75,
    date: journey2.startDate.add(const Duration(days: 1)),
    category: 'Food',
    paidBy: user2.id,
    sharedWith: [user2.id],
    description: 'Delicious Pad Thai!',
  ),
];

// Assign journey IDs to users
final local_user.User updatedUser1 = user1.copyWith(journeyIds: [journey1.id]);
final local_user.User updatedUser2 = user2.copyWith(journeyIds: [journey2.id]);

final List<local_user.User> sampleUsers = [updatedUser1, updatedUser2];
final List<Journey> sampleJourneys = [journey1, journey2];

// Example function using sample data (replace print with logging or remove if unused)
void processTestData() {
  if (kDebugMode) {
    print('Processing sample data...');
    print('Users: $sampleUsers');
    print('Journeys: $sampleJourneys');
    print('Expenses: $sampleExpenses');
  }
  // Add actual logic here if needed
}

Future<void> insertTestJourneys(JourneyRepository journeyRepository, String userId) async {
  final journeys = [
    Journey(
      id: 'journey-1',
      title: 'European Adventure',
      description: 'Exploring the capitals of Europe.',
      location: 'Europe',
      budget: 5000.0,
      userId: userId,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
      endDate: DateTime.now().subtract(const Duration(days: 15)),
      isCompleted: false,
    ),
    Journey(
      id: 'journey-2',
      title: 'Asian Expedition',
      description: 'A journey through Southeast Asia.',
      location: 'Asia',
      budget: 3000.0,
      userId: userId,
      startDate: DateTime.now().subtract(const Duration(days: 60)),
      endDate: DateTime.now().subtract(const Duration(days: 40)),
      isCompleted: true,
    ),
    // Add more journeys as needed
  ];

  journeys.sort((a, b) => b.startDate.compareTo(a.startDate));

  for (final journey in journeys) {
    try {
      await journeyRepository.addJourney(journey);
    } on PostgrestException catch (error) {
      // Handle potential duplicate key errors if run multiple times
      if (error.code != '23505') { // 23505 is unique_violation
      }
    } catch (_) {
      // Error ignored for test data creation
    }
  }
}

Future<void> clearTestData(JourneyRepository journeyRepository, String userId) async {
  // print('Clearing test journeys for user $userId...');
  final journeys = await journeyRepository.fetchUserJourneys(userId);
  journeys.sort((a, b) => b.startDate.compareTo(a.startDate));

  for (final journey in journeys) {
    // Check if title indicates it's test data before deleting (optional safety)
    if (journey.title.contains('Adventure') || journey.title.contains('Expedition')) {
        try {
          await journeyRepository.deleteJourney(journey.id);
        } catch (_) {
           // Error ignored for test data deletion
        }
    }
  }
}

// Function to insert sample data
// This is a basic example; you might want more robust error handling
Future<void> insertSampleData() async {
  final supabase = Supabase.instance.client;

  // Insert Users (Example: assuming a 'users' table)
  // Adapt table and column names as needed
  try {
    // Note: Supabase auth handles user creation typically.
    // This is just for related data assuming users exist.
    // Consider fetching existing users or using auth IDs.
    // await supabase.from('users').upsert([user1.toJson(), user2.toJson()]); 
  } catch (_) {
    // print('Error inserting users: $e'); // Error ignored for test data
  }

  // Insert Journeys (Example: assuming a 'journeys' table)
  // ... insert journey logic using journeyRepository ...

  // Insert Expenses (Example: assuming an 'expenses' table)
  try {
    await supabase.from('expenses').upsert(sampleExpenses.map((e) => e.toJson()).toList());
     // print('Inserted ${sampleExpenses.length} expenses.');
  } catch (_) {
    // print('Error inserting expenses: $e'); // Error ignored for test data
  }
}

// Helper function to assign expenses randomly to journeys
// You might not need this if expenses are predefined per journey
List<Expense> assignExpensesToJourneys(List<Journey> journeys, List<local_user.User> users) {
  final List<Expense> assignedExpenses = [];
  for (final journey in journeys) {
    int numExpenses = random.nextInt(5) + 1; // 1 to 5 expenses per journey
    for (int i = 0; i < numExpenses; i++) {
      assignedExpenses.add(
        Expense(
          id: const Uuid().v4(),
          journeyId: journey.id,
          title: 'Sample Expense ${i + 1} for ${journey.title}',
          amount: (random.nextDouble() * 100).roundToDouble(), // Random amount up to 100
          date: journey.startDate.add(Duration(days: random.nextInt( (journey.endDate.difference(journey.startDate).inDays).abs() > 0 ? (journey.endDate.difference(journey.startDate).inDays).abs() : 1 ))), // Random date within journey duration
          category: ['Food', 'Transport', 'Activity', 'Accommodation', 'Other'][random.nextInt(5)],
          paidBy: users[random.nextInt(users.length)].id, // Random user pays
          sharedWith: const [], // Already const
        ),
      );
    }
  }
  return assignedExpenses;
}
