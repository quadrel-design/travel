import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/user.dart'; // Import the User model (adjust path if needed)

void main() {
  group('User Model Tests', () {
    // Test data representing a typical JSON response for a user
    final Map<String, dynamic> testUserJson = {
      'id': 'user-123',
      'email': 'test@example.com',
      'name': 'Test User',
      'profileImageUrl': 'http://example.com/profile.jpg',
      'journeyIds': ['journey-abc', 'journey-def'],
    };

    // Test 1: fromJson factory constructor
    test('fromJson creates User object correctly', () {
      // Arrange: Use the test JSON data
      final user = User.fromJson(testUserJson);

      // Assert: Check if the fields match the input JSON
      expect(user.id, 'user-123');
      expect(user.email, 'test@example.com');
      expect(user.name, 'Test User');
      expect(user.profileImageUrl, 'http://example.com/profile.jpg');
      expect(user.journeyIds, containsAll(['journey-abc', 'journey-def']));
      expect(user.journeyIds.length, 2);
    });

    // Test 2: toJson method
    test('toJson converts User object correctly', () {
      // Arrange: Create a User object first
      final user = User(
        id: 'user-456',
        email: 'another@example.com',
        name: 'Another User',
        // Test with null profile image
        profileImageUrl: null, 
        // Test with empty journey list
        journeyIds: [], 
      );

      // Act: Convert the user object to JSON
      final json = user.toJson();

      // Assert: Check if the resulting JSON matches the User object's data
      expect(json['id'], 'user-456');
      expect(json['email'], 'another@example.com');
      expect(json['name'], 'Another User');
      expect(json['profileImageUrl'], isNull);
      expect(json['journeyIds'], isEmpty);
    });

    // Test 3: Handling missing optional fields in fromJson
    test('fromJson handles missing optional fields', () {
       final Map<String, dynamic> minimalUserJson = {
         'id': 'user-789',
         'email': 'minimal@example.com',
         'name': 'Minimal User',
         // profileImageUrl and journeyIds are missing
       };

       final user = User.fromJson(minimalUserJson);

       expect(user.id, 'user-789');
       expect(user.email, 'minimal@example.com');
       expect(user.name, 'Minimal User');
       expect(user.profileImageUrl, isNull);
       expect(user.journeyIds, isEmpty);
    });

    // Add more tests for edge cases, copyWith, equality operator, etc.

  });
} 