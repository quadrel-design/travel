/**
 * Location Service Provider
 *
 * Provides access to the application's location service for geocoding
 * and place lookups, primarily used within the invoice capture workflow.
 */
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/location_service.dart';
import 'logging_provider.dart';

/// Provides a location service for geocoding and place validation throughout the app.
///
/// This provider creates a singleton LocationService that handles:
/// - Validating location strings
/// - Finding place IDs for location names
/// - Retrieving detailed place information
/// - Standardizing address formats
///
/// Used primarily in the invoice capture workflow to validate and standardize
/// location information extracted from invoices.
final locationServiceProvider = Provider<LocationService>((ref) {
  final logger = ref.watch(loggerProvider);
  return LocationService(logger);
});
