import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel/services/location_service.dart';
import 'package:travel/providers/logging_provider.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  final logger = ref.watch(loggerProvider);
  return LocationService(logger);
});
