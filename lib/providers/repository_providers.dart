/*
 * Repository Providers
 * 
 * This file defines providers for accessing repositories and data services.
 * These providers serve as the central access point for data operations throughout
 * the application, ensuring consistent access to Firebase services and repositories.
 * 
 * The file includes providers for:
 * - Firebase service instances (Firestore, Auth, Storage)
 * - Repository instances for different data domains
 * - Stream providers for reactive data access
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel/repositories/auth_repository.dart';

// Import Firebase services
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/firestore_invoice_repository.dart';
import '../repositories/invoice_repository.dart';
import 'service_providers.dart' as service;

import '../providers/logging_provider.dart';
import 'package:travel/repositories/firebase_auth_repository.dart';
import 'package:travel/models/project.dart';
import 'package:travel/models/expense.dart';
import 'package:travel/repositories/expense_repository.dart';
import 'package:travel/models/invoice_image_process.dart';

/// Provider for accessing the Firestore database instance.
///
/// This provider delivers a singleton instance of FirebaseFirestore throughout the app.
/// It serves as the foundation for all Firestore database operations.
final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

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

/// Provider for the invoice repository.
///
/// This provider creates and delivers an implementation of the InvoiceRepository interface.
/// It handles operations related to invoices, including invoice CRUD operations and image management.
final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  final logger = ref.watch(loggerProvider);
  final gcsFileService = ref.watch(service.gcsFileServiceProvider);

  return FirestoreInvoiceRepository(firestore, auth, logger, gcsFileService);
});

/// Stream provider for accessing the current user's invoices.
///
/// This provider delivers a real-time stream of the authenticated user's invoices.
/// The stream automatically updates when invoices are added, modified, or removed.
final userInvoicesStreamProvider =
    StreamProvider.autoDispose<List<Project>>((ref) {
  // Get the repository
  final repository = ref.watch(invoiceRepositoryProvider);
  // Return the stream from the repository method
  // Error handling should be done within the stream or by the UI watching this provider
  return repository.fetchUserProjects();
});

/// Stream provider for all images associated with an invoice.
///
/// This provider delivers a real-time stream of all images for a specific invoice.
/// The stream automatically updates when images are added, modified, or removed.
///
/// Parameters:
///   - params: A map containing 'projectId' and 'invoiceId'
final invoiceImagesStreamProvider = StreamProvider.autoDispose
    .family<List<InvoiceImageProcess>, Map<String, String>>((ref, params) {
  final repository = ref.watch(invoiceRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  final projectId = params['projectId']!;
  final invoiceId = params['invoiceId']!;
  logger.d(
      '[PROVIDER] invoiceImagesStreamProvider executing for projectId: $projectId, invoiceId: $invoiceId');
  return repository.getInvoiceImagesStream(projectId, invoiceId);
});

/// Stream provider for a single invoice by ID.
///
/// This provider delivers a real-time stream of a specific invoice's data.
/// The stream automatically updates when the invoice is modified.
///
/// Parameters:
///   - invoiceId: The ID of the invoice to stream
final invoiceStreamProvider =
    StreamProvider.family<Project?, String>((ref, invoiceId) {
  final repository = ref.watch(invoiceRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  logger.d(
      '[PROVIDER] invoiceStreamProvider executing for invoiceId: $invoiceId');
  return repository.getProjectStream(invoiceId);
});

/// Stream provider for all expenses associated with an invoice.
///
/// This provider delivers a real-time stream of all expenses for a specific invoice.
/// The stream automatically updates when expenses are added, modified, or removed.
///
/// Parameters:
///   - params: A map containing 'projectId' and 'invoiceId'
final expensesStreamProvider = StreamProvider.autoDispose
    .family<List<Expense>, Map<String, String>>((ref, params) {
  final repository = ref.watch(expenseRepositoryProvider);
  final logger = ref.watch(loggerProvider);
  final projectId = params['projectId']!;
  final invoiceId = params['invoiceId']!;
  logger.d(
      '[PROVIDER] expensesStreamProvider executing for projectId: $projectId, invoiceId: $invoiceId');
  return repository.getExpensesStream(projectId, invoiceId);
});

/// Provider for tracking the gallery upload state.
///
/// This provider maintains a boolean state indicating whether a gallery upload
/// operation is currently in progress. UI components can observe this state
/// to show appropriate loading indicators.
final galleryUploadStateProvider = StateProvider<bool>((ref) => false);

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  final logger = ref.watch(loggerProvider);
  return ExpenseRepository(firestore: firestore, auth: auth, logger: logger);
});

/// Stream provider for all images associated with a project (not a specific invoice).
///
/// This provider delivers a real-time stream of all images for a specific project.
/// The stream automatically updates when images are added, modified, or removed.
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
