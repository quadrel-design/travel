import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel/models/invoice_capture_process.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/repositories/invoice_repository.dart';
import 'package:travel/widgets/invoice_capture_detail_view.dart';
import 'package:travel/providers/logging_provider.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

class MockLogger extends Mock implements Logger {}

class MockInvoiceRepository extends Mock implements InvoiceRepository {}

void main() {
  late MockLogger mockLogger;
  late MockInvoiceRepository mockRepository;
  late ProviderContainer container;

  setUp(() {
    mockLogger = MockLogger();
    mockRepository = MockInvoiceRepository();

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

  testWidgets('InvoiceCaptureDetailView shows correct number of images',
      (WidgetTester tester) async {
    final testImages = [
      const InvoiceCaptureProcess(
        id: '1',
        url: 'https://example.com/image1.jpg',
        imagePath: 'path/to/image1.jpg',
      ),
      const InvoiceCaptureProcess(
        id: '2',
        url: 'https://example.com/image2.jpg',
        imagePath: 'path/to/image2.jpg',
      ),
    ];

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: InvoiceCaptureDetailView(
            journeyId: 'test-journey',
            images: testImages,
            initialIndex: 0,
          ),
        ),
      ),
    );

    expect(find.text('Image 1 of 2'), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);
  });

  testWidgets('InvoiceCaptureDetailView handles empty image list',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: InvoiceCaptureDetailView(
            journeyId: 'test-journey',
            images: [],
            initialIndex: 0,
          ),
        ),
      ),
    );

    expect(find.text('No images available'), findsOneWidget);
  });

  testWidgets('InvoiceCaptureDetailView handles image loading error',
      (WidgetTester tester) async {
    final testImages = [
      const InvoiceCaptureProcess(
        id: '1',
        url: 'invalid-url',
        imagePath: 'path/to/image1.jpg',
      ),
    ];

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: InvoiceCaptureDetailView(
            journeyId: 'test-journey',
            images: testImages,
            initialIndex: 0,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });
}
