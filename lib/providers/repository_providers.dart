/*
 * Repository Providers
 * 
 * This file defines providers for accessing repositories and data services.
 * These providers serve as the central access point for data operations throughout
 * the application, ensuring consistent access to PostgreSQL services and repositories.
 * 
 * The file includes providers for:
 * - Firebase Auth service instances
 * - Repository instances for different data domains
 * - Provider functions for data access (replacing Firestore streams)
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel/repositories/auth_repository.dart';

// Import Firebase Auth services only (not Firestore)
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/invoice_images_repository.dart';
import '../repositories/postgres_invoice_repository.dart';
import 'service_providers.dart' as service;

import '../providers/logging_provider.dart';
import 'package:travel/repositories/firebase_auth_repository.dart';
import 'package:travel/models/project.dart';
import 'package:travel/models/expense.dart';
import 'package:travel/models/invoice_image_process.dart';

/// Provider for accessing the Firebase Authentication instance.
///
/// This provider delivers a singleton instance of FirebaseAuth throughout the app.
/// It serves as the foundation for all authentication operations.
final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

/// Provider for the authentication repository.
///
/// This provider creates and delivers an implementation of the AuthRepository interface.
/// It handles user authentication, registration, and session management.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  final logger = ref.watch(loggerProvider);
  return FirebaseAuthRepository(firebaseAuth, logger);
});

/// Provider for the invoice image repository.
///
/// This provider creates and delivers an implementation of the InvoiceImagesRepository interface.
/// It handles operations related to invoice images, including CRUD operations and image management.
/// Now uses PostgreSQL-based implementation instead of Firestore.
final invoiceRepositoryProvider = Provider<InvoiceImagesRepository>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final logger = ref.watch(loggerProvider);
  final gcsFileService = ref.watch(service.gcsFileServiceProvider);

  return PostgresInvoiceImageRepository(auth, logger, gcsFileService);
});

/// Provider for accessing the current user's invoices.
///
/// This provider delivers data of the authenticated user's invoices.
/// The data is fetched from the PostgreSQL database via REST API.
final userInvoicesStreamProvider =
    StreamProvider.autoDispose<List<Project>>((ref) {
  // Get the repository
  final repository = ref.watch(invoiceRepositoryProvider);
  // Return the stream from the repository method
  // Error handling should be done within the stream or by the UI watching this provider
  return repository.fetchUserProjects();
});

/// Provider for all images associated with an invoice.
///
/// This provider delivers data of all images for a specific invoice.
/// The data is fetched from the PostgreSQL database via REST API.
///
/// Parameters:
///   - params: A map containing 'projectId' and 'invoiceId'
final invoiceImagesStreamProvider =
    StreamProvider.autoDispose.family<List<InvoiceImageProcess>, String>(
  (ref, identifiers) {
    final parts = identifiers.split('|');
    final projectId = parts[0];
    // final invoiceId = parts.length > 1 ? parts[1] : ''; // invoiceId is no longer used for the repo call
    // final reloadKey = parts.length > 2 ? parts[2] : ''; // Keep reloadKey if used

    final repository = ref.watch(invoiceRepositoryProvider);
    // Call getProjectImagesStream instead
    return repository.getProjectImagesStream(projectId);
    // If filtering by a specific client-side invoiceId (grouping UUID) is still needed here,
    // it would have to be done after fetching all project images.
    // For example: return repository.getProjectImagesStream(projectId).map((images) =>
    //    images.where((img) => img.invoiceId == invoiceId).toList());
    // However, InvoiceImageProcess model itself no longer has invoiceId directly.
    // The concept of invoiceId for grouping images was removed from the core data model.
  },
);

/// Provider for a single invoice by ID.
///
/// This provider delivers data of a specific invoice.
/// The data is fetched from the PostgreSQL database via REST API.
///
/// Parameters:
///   - invoiceId: The ID of the invoice to fetch
final invoiceStreamProvider =
    StreamProvider.family<Project?, String>((ref, invoiceId) {
  final repository = ref.watch(invoiceRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  logger.d(
      '[PROVIDER] invoiceStreamProvider executing for invoiceId: $invoiceId');
  return repository.getProjectStream(invoiceId);
});

/// Provider for all expenses associated with an invoice.
///
/// This provider delivers data of all expenses for a specific invoice.
/// The data will be fetched from the PostgreSQL database in future implementation.
///
/// Parameters:
///   - params: A map containing 'projectId' and 'invoiceId'
final expensesStreamProvider = StreamProvider.autoDispose
    .family<List<Expense>, Map<String, String>>((ref, params) {
  // TODO: Replace with PostgreSQL implementation
  final logger = ref.watch(loggerProvider);
  final projectId = params['projectId']!;
  final invoiceId = params['invoiceId']!;
  logger.d(
      '[PROVIDER] expensesStreamProvider executing for projectId: $projectId, invoiceId: $invoiceId');
  // Return empty list until PostgreSQL expense repository is implemented
  return Stream.value([]);
});

/// Provider for tracking the gallery upload state.
///
/// This provider maintains a boolean state indicating whether a gallery upload
/// operation is currently in progress. UI components can observe this state
/// to show appropriate loading indicators.
final galleryUploadStateProvider = StateProvider<bool>((ref) => false);

/// Provider for all images associated with a project (not a specific invoice).
///
/// This provider delivers data of all images for a specific project.
/// The data is fetched from the PostgreSQL database via REST API.
///
/// Parameters:
///   - projectId: The ID of the project
final projectImagesStreamProvider = StreamProvider.autoDispose
    .family<List<InvoiceImageProcess>, String>((ref, projectIdWithKey) {
  final parts = projectIdWithKey.split('|');
  final projectId = parts[0];
  final repository = ref.watch(invoiceRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  logger.d(
      '[PROVIDER] projectImagesStreamProvider executing for projectId: $projectId');
  return repository.getProjectImagesStream(projectId);
});

final firebaseAuthRepositoryProvider = Provider<FirebaseAuthRepository>((ref) {
  final logger = ref.watch(loggerProvider);
  return FirebaseAuthRepository(FirebaseAuth.instance, logger);
});

// Fetches a list of invoice images for a specific project and invoice (now just project)
// This provider is kept for compatibility but might need to be refactored or removed
// if the UI no longer thinks in terms of specific "invoiceId" for fetching.
final specificInvoiceImagesProvider =
    FutureProvider.autoDispose.family<List<InvoiceImageProcess>, String>(
  (ref, identifiers) async {
    final parts = identifiers.split('|');
    final projectId = parts[0];
    // final invoiceId = parts[1]; // invoiceId no longer used for fetching

    final repository = ref.watch(invoiceRepositoryProvider);
    // Use getProjectImagesStream and convert to Future for this provider type
    return await repository.getProjectImagesStream(projectId).first;
    // Again, if specific filtering was intended by a now-removed invoiceId, it needs re-evaluation.
  },
);
