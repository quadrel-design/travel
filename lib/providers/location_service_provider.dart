import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/location_service.dart';
import 'logging_provider.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  final logger = ref.watch(loggerProvider);
  return LocationService(logger);
}); 