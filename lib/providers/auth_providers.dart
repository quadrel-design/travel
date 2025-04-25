import 'package:flutter_riverpod/flutter_riverpod.dart';

// Defines the possible states for the authentication flow UI
enum AuthNavigationState {
  login,
  signUp,
  waitForVerification,
}

// Provider to manage the current navigation state within the auth flow
final authNavigationProvider =
    StateProvider<AuthNavigationState>((ref) => AuthNavigationState.login);

// Provider to track loading state during auth operations
final authLoadingProvider = StateProvider<bool>((ref) => false);

// Provider to hold the latest authentication error message
final authErrorProvider = StateProvider<String?>((ref) => null);
