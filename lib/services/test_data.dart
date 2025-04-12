import 'dart:math';
import '../models/expense.dart';
import '../models/journey.dart';
import '../models/user.dart';
import 'package:uuid/uuid.dart';

// Use flutter/foundation.dart for kDebugMode checks if needed for logging
import 'package:flutter/foundation.dart';

final random = Random();
const uuid = Uuid();

// Sample Users
final User user1 = User(
  id: uuid.v4(),
  email: 'user1@example.com',
  name: 'Alice',
  profileImageUrl: 'https://example.com/alice.jpg',
);

final User user2 = User(
  id: uuid.v4(),
  email: 'user2@example.com',
  name: 'Bob',
);

// Sample Journeys
final Journey journey1 = Journey(
  id: uuid.v4(),
  userId: user1.id, // Link to user1
  title: 'European Adventure',
  description: 'Backpacking through Europe for 3 weeks.',
  location: 'Europe',
  startDate: DateTime.now().subtract(const Duration(days: 30)),
  endDate: DateTime.now().subtract(const Duration(days: 9)),
  budget: 2500.00,
  imageUrls: [
    'https://example.com/europe1.jpg',
    'https://example.com/europe2.jpg'
  ],
  isCompleted: true,
);

final Journey journey2 = Journey(
  id: uuid.v4(),
  userId: user2.id, // Link to user2
  title: 'Asian Expedition',
  description: 'Exploring Southeast Asia.',
  location: 'Southeast Asia',
  startDate: DateTime.now().add(const Duration(days: 10)),
  endDate: DateTime.now().add(const Duration(days: 30)),
  budget: 3000.00,
  imageUrls: [],
);

// Sample Expenses
final List<Expense> sampleExpenses = [
  Expense(
    journeyId: journey1.id, // Link to journey1
    title: 'Train Ticket Paris-Berlin',
    amount: 120.50,
    date: journey1.startDate.add(const Duration(days: 2)),
    category: 'Transportation',
    paidBy: user1.id,
    sharedWith: [user1.id], // Assuming Alice paid for herself only initially
    description: 'High-speed train journey.',
  ),
  Expense(
    journeyId: journey1.id, // Link to journey1
    title: 'Hostel in Berlin',
    amount: 250.00,
    date: journey1.startDate.add(const Duration(days: 3)),
    category: 'Accommodation',
    paidBy: user1.id,
    sharedWith: [user1.id],
  ),
  Expense(
    journeyId: journey2.id, // Link to journey2
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
final User updatedUser1 = user1.copyWith(journeyIds: [journey1.id]);
final User updatedUser2 = user2.copyWith(journeyIds: [journey2.id]);

final List<User> sampleUsers = [updatedUser1, updatedUser2];
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
