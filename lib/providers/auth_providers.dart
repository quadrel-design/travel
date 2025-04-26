/*
 * Authentication Providers
 * 
 * This file defines providers for managing authentication UI state, including
 * navigation between authentication screens, loading states, and error handling.
 * These providers are primarily used in the authentication flow UI to coordinate
 * state across different authentication components.
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Defines the possible screens within the authentication flow.
///
/// Used to control navigation between login, signup, and verification screens
/// without requiring direct navigation or route changes.
enum AuthNavigationState {
  /// The login screen where existing users can sign in
  login,

  /// The signup screen where new users can create an account
  signUp,

  /// The verification waiting screen shown after email verification is requested
  waitForVerification,
}

/// Provider to manage the current screen within the authentication flow.
///
/// This provider allows components to know which authentication screen should be displayed
/// without requiring direct navigation or route changes. It defaults to the login screen.
///
/// Usage: `final currentAuthScreen = ref.watch(authNavigationProvider);`
final authNavigationProvider =
    StateProvider<AuthNavigationState>((ref) => AuthNavigationState.login);

/// Provider to track whether an authentication operation is in progress.
///
/// This provider helps UI components show loading indicators and disable interactive
/// elements during authentication operations such as login, signup, or password reset.
///
/// Usage: `final isLoading = ref.watch(authLoadingProvider);`
final authLoadingProvider = StateProvider<bool>((ref) => false);

/// Provider to store and display authentication error messages.
///
/// This provider holds error messages that should be displayed to the user when
/// authentication operations fail. Components can watch this provider to show
/// appropriate error messages and feedback.
///
/// Usage: `final errorMessage = ref.watch(authErrorProvider);`
final authErrorProvider = StateProvider<String?>((ref) => null);
