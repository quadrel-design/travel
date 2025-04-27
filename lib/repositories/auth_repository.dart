/**
 * Abstract Interface for Authentication Repository
 *
 * Defines the contract for authentication operations (sign-in, sign-up, sign-out,
 * state changes, password reset, email verification) used within the application.
 * Concrete implementations (e.g., FirebaseAuthRepository) will provide the
 * specific logic for interacting with an authentication backend.
 */
import 'package:firebase_auth/firebase_auth.dart'
    show User, UserCredential; // Only import needed types
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';

/// Abstract base class defining the required authentication methods.
abstract class AuthRepository {
  /// Stream providing real-time changes to the user's authentication state.
  /// Emits the current [User] if authenticated, or null otherwise.
  Stream<User?> get authStateChanges;

  /// Gets the currently authenticated Firebase [User], or null if none.
  User? get currentUser;

  /// Signs in a user with the provided email and password.
  ///
  /// Returns a [UserCredential] upon successful authentication.
  /// Throws exceptions (e.g., implementation-specific like FirebaseAuthException)
  /// on failure (invalid credentials, user not found, etc.).
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Initiates the Google Sign-In flow.
  ///
  /// Returns a [UserCredential] upon successful authentication with Firebase.
  /// Throws exceptions if the flow is cancelled or fails.
  Future<UserCredential> signInWithGoogle();

  /// Creates a new user account with the provided email and password.
  ///
  /// Returns a [UserCredential] upon successful account creation.
  /// Throws exceptions on failure (email already in use, weak password, etc.).
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Signs out the current user from all providers (Firebase, Google Sign-In).
  ///
  /// Throws exceptions if sign-out fails.
  Future<void> signOut();

  /// Sends a password reset email to the specified email address.
  ///
  /// Throws exceptions if the email is not found or another error occurs.
  Future<void> resetPasswordForEmail(String email);

  /// Sends an email verification link to the currently signed-in user.
  /// Should typically be called after registration or if `currentUser.emailVerified` is false.
  ///
  /// Throws exceptions if no user is signed in or the email sending fails.
  Future<void> sendVerificationEmail();

  // Add other abstract auth methods as needed
}
