import 'package:flutter_test/flutter_test.dart';
import 'package:travel/models/journey.dart';

void main() {
  group('Journey Model Tests', () {
    final testJson = {
      'id': 'journey-123',
      'user_id': 'user-abc',
      'title': 'Test Trip',
      'description': 'A test description.',
      'location': 'Test Location',
      'start_date': DateTime(2024, 7, 20).toIso8601String(),
      'end_date': DateTime(2024, 7, 27).toIso8601String(),
      'budget': 1500.50,
      'image_urls': ['url1', 'url2'],
      'is_completed': false,
      'created_at': DateTime.now().toIso8601String(),
    };

    test('fromJson creates Journey object correctly', () {
      final journey = Journey.fromJson(testJson);

      expect(journey.id, 'journey-123');
      expect(journey.user_id, 'user-abc');
      expect(journey.title, 'Test Trip');
      expect(journey.description, 'A test description.');
      expect(journey.location, 'Test Location');
      expect(journey.start_date, DateTime(2024, 7, 20));
      expect(journey.end_date, DateTime(2024, 7, 27));
      expect(journey.budget, 1500.50);
      expect(journey.image_urls, equals(['url1', 'url2']));
      expect(journey.is_completed, isFalse);
    });

    test('toJson converts Journey object correctly', () {
       final journey = Journey(
          id: 'journey-456',
          user_id: 'user-def',
          title: 'Another Trip',
          description: 'Desc',
          location: 'Loc',
          start_date: DateTime(2024, 8, 1),
          end_date: DateTime(2024, 8, 10),
          budget: 100.0,
          image_urls: [],
          is_completed: true,
       );

      final json = journey.toJson();

      expect(json['user_id'], 'user-def');
      expect(json['title'], 'Another Trip');
      expect(json['description'], 'Desc');
      expect(json['location'], 'Loc');
      expect(json['start_date'], DateTime(2024, 8, 1).toIso8601String());
      expect(json['end_date'], DateTime(2024, 8, 10).toIso8601String());
      expect(json['budget'], 100.0);
      expect(json['image_urls'], isEmpty);
      expect(json['is_completed'], isTrue);
      expect(json.containsKey('id'), isFalse);
    });

    // Add tests for copyWith, equality (handled by Equatable now)
  });
} 