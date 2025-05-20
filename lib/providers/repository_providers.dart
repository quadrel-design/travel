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
import '../repositories/project_repository.dart';
import '../repositories/postgres_project_repository.dart';
import 'service_providers.dart' as service;

import '../providers/logging_provider.dart';
import 'package:travel/repositories/firebase_auth_repository.dart';
import 'package:travel/models/project.dart';
import 'package:travel/models/expense.dart';
import 'package:travel/models/invoice_image_process.dart';
import 'package:flutter/foundation.dart'; // ADDED for listEquals
import 'package:travel/config/service_config.dart'; // ADDED import

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
  final actualBaseUrl = ServiceConfig.gcsApiBaseUrl; // Get the value

  logger.i(
      '[PROVIDER_INIT] PostgresInvoiceImageRepository WILL BE CREATED WITH baseUrl: $actualBaseUrl'); // ADDED log

  return PostgresInvoiceImageRepository(
    auth,
    logger,
    gcsFileService,
    baseUrl: actualBaseUrl, // Use the fetched value
  );
});

/// Provider for the project repository.
///
/// This provider creates and delivers an implementation of the ProjectRepository interface.
/// It handles operations related to projects.
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final logger = ref.watch(loggerProvider);
  final actualBaseUrl = ServiceConfig.gcsApiBaseUrl;

  logger.i(
      '[PROVIDER_INIT] PostgresProjectRepository WILL BE CREATED WITH baseUrl: $actualBaseUrl');

  return PostgresProjectRepository(
    auth,
    logger,
    baseUrl: actualBaseUrl,
  );
});

/// Provider for accessing the current user's projects (renamed from invoices for clarity).
///
/// This provider delivers data of the authenticated user's projects.
/// The data is fetched from the PostgreSQL database via REST API.
final currentUserProjectsStreamProvider =
    StreamProvider.autoDispose<List<Project>>((ref) {
  // Get the repository
  final repository = ref.watch(projectRepositoryProvider);
  // Return the stream from the repository method
  // Error handling should be done within the stream or by the UI watching this provider
  return repository.fetchUserProjects();
});

/// Provider for a single project by ID (renamed from invoiceStreamProvider).
///
/// This provider delivers data of a specific project.
/// The data is fetched from the PostgreSQL database via REST API.
///
/// Parameters:
///   - projectId: The ID of the project to fetch
final projectStreamProvider =
    StreamProvider.family<Project?, String>((ref, projectId) {
  final repository = ref.watch(projectRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  logger.d(
      '[PROVIDER] projectStreamProvider executing for projectId: $projectId');
  return repository.getProjectStream(projectId);
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
    .family<List<InvoiceImageProcess>, String>((ref, identifiers) {
  final parts = identifiers.split('|');
  final projectId = parts[0];
  final repository = ref.watch(invoiceRepositoryProvider);
  final logger = ref.watch(loggerProvider);

  logger.d(
      '[PROVIDER] projectImagesStreamProvider for $projectId initialized. Returning raw stream.');

  // Return the raw stream directly. Riverpod will handle de-duplication.
  return repository.getProjectImagesStream(projectId);
});

/// Provider for all projects of the current user.
///
/// This provider delivers data of all projects for the current user.
/// The data will be fetched from the PostgreSQL database via REST API.
/// Data is refreshed when reloadKey changes or when the provider is invalidated.
final userProjectsStreamProvider =
    StreamProvider.family<List<Project>, int>((ref, reloadKey) {
  final repository = ref.watch(projectRepositoryProvider);
  return repository.fetchUserProjects();
});
