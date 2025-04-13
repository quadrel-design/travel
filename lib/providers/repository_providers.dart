import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel/repositories/auth_repository.dart';
import 'package:travel/repositories/journey_repository.dart';

// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// Provider for JourneyRepository
final journeyRepositoryProvider = Provider<JourneyRepository>((ref) {
  return JourneyRepository();
}); 