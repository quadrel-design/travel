import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel/widgets/gallery_detail_view.dart';
import 'package:travel/models/journey_image_info.dart';
import 'package:travel/providers/gallery_detail_provider.dart';
import 'package:travel/providers/logging_provider.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/repositories/journey_repository.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

// Mock classes
class MockLogger extends Mock implements Logger {}

class MockJourneyRepository extends Mock implements JourneyRepository {}

void main() {
  late MockLogger mockLogger;
  late MockJourneyRepository mockRepository;
  late ProviderContainer container;

  setUp(() {
    mockLogger = MockLogger();
    mockRepository = MockJourneyRepository();

    // Setup container with mocked providers
    container = ProviderContainer(
      overrides: [
        loggerProvider.overrideWithValue(mockLogger),
        journeyRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  testWidgets('GalleryDetailView shows correct number of images',
      (WidgetTester tester) async {
    // Create test images
    final testImages = [
      JourneyImageInfo(
        id: '1',
        url: 'https://example.com/image1.jpg',
        imagePath: 'path/to/image1.jpg',
      ),
      JourneyImageInfo(
        id: '2',
        url: 'https://example.com/image2.jpg',
        imagePath: 'path/to/image2.jpg',
      ),
    ];

    // Build the widget
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GalleryDetailView(
            journeyId: 'test-journey',
            images: testImages,
            initialIndex: 0,
          ),
        ),
      ),
    );

    // Verify the title shows correct image count
    expect(find.text('Image 1 of 2'), findsOneWidget);

    // Verify the delete button is present
    expect(find.byIcon(Icons.delete), findsOneWidget);
  });

  testWidgets('GalleryDetailView handles empty image list',
      (WidgetTester tester) async {
    // Build the widget with empty image list
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GalleryDetailView(
            journeyId: 'test-journey',
            images: [],
            initialIndex: 0,
          ),
        ),
      ),
    );

    // Verify the "No images available" message is shown
    expect(find.text('No images available'), findsOneWidget);
  });

  testWidgets('GalleryDetailView handles image loading error',
      (WidgetTester tester) async {
    // Create test image with invalid URL
    final testImages = [
      JourneyImageInfo(
        id: '1',
        url: 'invalid-url',
        imagePath: 'path/to/image1.jpg',
      ),
    ];

    // Build the widget
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GalleryDetailView(
            journeyId: 'test-journey',
            images: testImages,
            initialIndex: 0,
          ),
        ),
      ),
    );

    // Wait for image loading to fail
    await tester.pumpAndSettle();

    // Verify error icon is shown
    expect(find.byIcon(Icons.error), findsOneWidget);
  });
}
