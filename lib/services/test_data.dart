import 'dart:math';
import '../models/expense.dart';
import '../models/journey.dart';
import '../models/user.dart' as local_user;
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/invoice_repository.dart';
import '../repositories/repository_exceptions.dart';

// Use flutter/foundation.dart for kDebugMode checks if needed for logging
import 'package:flutter/foundation.dart';

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

Future<void> insertTestJourneys(
    InvoiceRepository repository, String userId) async {
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
      await repository.addJourney(journey);
    } on FirebaseException catch (_) {
      // Handle potential duplicate key errors (less direct in Firestore, maybe check specific codes?)
      // Firestore doesn't have a direct 'unique_violation' code like Postgres.
      // We might rely on the repository handling it or just log here.
      // if (error.code != 'already-exists') { // Example check (code might differ)
      // }
      // Error ignored for test data creation
    } on DatabaseOperationException catch (_) {
      // If the repo threw its custom exception
      // Error ignored for test data creation
    } catch (_) {
      // Error ignored for test data creation
    }
  }
}

Future<void> clearTestData(InvoiceRepository repository, String userId) async {
  // print('Clearing test journeys for user $userId...');

  // Fetch the first list emitted by the stream, then sort and iterate
  try {
    final List<Journey> journeysList =
        await repository.fetchUserJourneys().first;
    journeysList.sort((a, b) => b.startDate.compareTo(a.startDate));

    for (final journey in journeysList) {
      // Check if title indicates it's test data before deleting (optional safety)
      if (journey.title.contains('Adventure') ||
          journey.title.contains('Expedition')) {
        try {
          await repository.deleteJourney(journey.id);
        } catch (_) {
          // Error ignored for test data deletion
        }
      }
    }
  } catch (e) {
    // Handle potential errors fetching the stream (e.g., user not logged in)
    if (kDebugMode) {
      print('Error fetching journeys for clearing test data: $e');
    }
  }
}

// Function to insert sample data - Migrated to Firestore
Future<void> insertSampleData() async {
  // Get Firestore instance
  final firestore = FirebaseFirestore.instance;

  // Insert Users (Example: using set with merge for upsert-like behavior)
  try {
    // Assuming user1.id and user2.id are intended Firestore document IDs
    final userBatch = firestore.batch();
    userBatch.set(firestore.collection('users').doc(user1.id),
        updatedUser1.toJson(), SetOptions(merge: true));
    userBatch.set(firestore.collection('users').doc(user2.id),
        updatedUser2.toJson(), SetOptions(merge: true));
    await userBatch.commit();
    // print('Upserted sample users.');
  } catch (e) {
    // print('Error inserting/updating users: $e'); // Error ignored for test data
  }

  // Insert Journeys logic is handled by insertTestJourneys using the repository

  // Insert Expenses (Example: using a batch write)
  try {
    final expenseBatch = firestore.batch();
    for (final expense in sampleExpenses) {
      // Use expense.id as document ID or let Firestore generate one?
      // If using expense.id:
      final docRef = firestore.collection('expenses').doc(expense.id);
      expenseBatch.set(docRef, expense.toJson());
      // If letting Firestore generate IDs:
      // final docRef = firestore.collection('expenses').doc(); // Create ref with new ID
      // expenseBatch.set(docRef, expense.toJson());
    }
    await expenseBatch.commit();
    // print('Inserted ${sampleExpenses.length} expenses.');
  } catch (e) {
    // print('Error inserting expenses: $e'); // Error ignored for test data
  }
}

// Helper function to assign expenses randomly to journeys
// You might not need this if expenses are predefined per journey
List<Expense> assignExpensesToJourneys(
    List<Journey> journeys, List<local_user.User> users) {
  final List<Expense> assignedExpenses = [];
  for (final journey in journeys) {
    int numExpenses = random.nextInt(5) + 1; // 1 to 5 expenses per journey
    for (int i = 0; i < numExpenses; i++) {
      assignedExpenses.add(
        Expense(
          id: const Uuid().v4(),
          journeyId: journey.id,
          title: 'Sample Expense ${i + 1} for ${journey.title}',
          amount: (random.nextDouble() * 100)
              .roundToDouble(), // Random amount up to 100
          date: journey.startDate.add(Duration(
              days: random.nextInt(
                  (journey.endDate.difference(journey.startDate).inDays).abs() >
                          0
                      ? (journey.endDate.difference(journey.startDate).inDays)
                          .abs()
                      : 1))), // Random date within journey duration
          category: [
            'Food',
            'Transport',
            'Activity',
            'Accommodation',
            'Other'
          ][random.nextInt(5)],
          paidBy: users[random.nextInt(users.length)].id, // Random user pays
          sharedWith: const [], // Already const
        ),
      );
    }
  }
  return assignedExpenses;
}

Future<void> deleteAllUserData(String userId) async {
  // **DANGEROUS:** Be very careful with this function!
  // Consider adding extra confirmation steps.

  // Delete Firestore data (Journeys, Expenses, Images)
  try {
    final userJourneysRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('journeys');
    final journeysSnapshot = await userJourneysRef.get();
    final batch = FirebaseFirestore.instance.batch();

    for (final journeyDoc in journeysSnapshot.docs) {
      // Delete expenses subcollection
      final expensesRef = journeyDoc.reference.collection('expenses');
      final expensesSnapshot = await expensesRef.get();
      for (final expenseDoc in expensesSnapshot.docs) {
        batch.delete(expenseDoc.reference);
      }

      // Delete images subcollection
      final imagesRef = journeyDoc.reference.collection('images');
      final imagesSnapshot = await imagesRef.get();
      for (final imageDoc in imagesSnapshot.docs) {
        batch.delete(imageDoc.reference);
      }

      // Delete the journey itself
      batch.delete(journeyDoc.reference);
    }
    await batch.commit();
    // print('Deleted Firestore data for user: $userId'); // Remove print
  } catch (_) {
    // Ensure this one is already '_'
    // Replace 'error' with '_'
    // print('Error deleting Firestore data for user $userId: $_'); // Remove print
    // Rethrow or handle as needed
    rethrow; // Use rethrow to re-throw the caught exception
  }

  // Delete Storage data (Images)
  // ... (Storage deletion logic - needs implementation)

  // Delete Authentication user
  // ... (Auth deletion logic - likely handled elsewhere or needs careful coordination)
}
