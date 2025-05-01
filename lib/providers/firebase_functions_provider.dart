/*
 * Firebase Functions Provider
 * 
 * This file defines a provider for accessing Firebase Cloud Functions.
 * It provides a single point of access to cloud functions throughout the app,
 * ensuring consistent logging and error handling for all function calls.
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_functions_service.dart';
import 'logging_provider.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Provides a Firebase Functions service throughout the application.
///
/// This provider creates a singleton FirebaseFunctionsService that handles
/// all interactions with Firebase Cloud Functions, including:
/// - OCR processing of images
/// - Invoice analysis and data extraction
/// - Text extraction from images
///
/// The service includes comprehensive logging and error handling to make
/// debugging cloud function calls easier.
///
/// Usage: `final functionsService = ref.read(firebaseFunctionsProvider);`
final firebaseFunctionsProvider = Provider<FirebaseFunctionsService>((ref) {
  return FirebaseFunctionsService(
    logger: ref.watch(loggerProvider),
    functions: FirebaseFunctions.instanceFor(region: 'us-central1'),
  );
});
