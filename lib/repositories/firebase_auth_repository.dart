import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import './auth_repository.dart'; // Import the abstract class
import '../providers/logging_provider.dart'; // Import logger provider if used
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Ref for logger

/**
 * Firebase Authentication Repository Implementation
 *
 * Provides a concrete implementation of the AuthRepository interface using
 * Firebase Authentication and Google Sign-In services.
 */

// Concrete implementation using Firebase Authentication
/// Implements the [AuthRepository] interface using Firebase services.
class FirebaseAuthRepository implements AuthRepository {
  final firebase_auth.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final Logger _logger;

  // Constructor takes FirebaseAuth instance and Logger
  /// Creates an instance of [FirebaseAuthRepository].
  /// Requires instances of [FirebaseAuth] and [Logger].
  FirebaseAuthRepository(this._firebaseAuth, this._logger)
      : _googleSignIn = GoogleSignIn();

  // --- Implement abstract methods ---

  @override
  Stream<firebase_auth.User?> get authStateChanges =>
      _firebaseAuth.authStateChanges();

  @override
  firebase_auth.User? get currentUser => _firebaseAuth.currentUser;

  @override
  Future<firebase_auth.UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('Attempting to create user account: $email');
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await sendVerificationEmail();
      _logger.i('Account creation successful for: $email');
      return credential;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _logger.e('FirebaseAuthException during account creation for $email',
          error: e, stackTrace: StackTrace.current);
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during account creation for $email',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<firebase_auth.UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _logger.i('Attempting to sign in user: $email');
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _logger.i('Sign in successful for: $email');
      return credential;
    } on firebase_auth.FirebaseAuthException catch (e) {
      _logger.e('FirebaseAuthException during sign in for $email',
          error: e, stackTrace: StackTrace.current);
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during sign in for $email',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<firebase_auth.UserCredential> signInWithGoogle() async {
    try {
      _logger.i('Attempting Google Sign-In');
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw firebase_auth.FirebaseAuthException(
          code: 'ERROR_ABORTED_BY_USER',
          message: 'Sign in aborted by user',
        );
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      _logger.i('Google Sign-In successful for: ${googleUser.email}');
      return userCredential;
    } catch (e, stackTrace) {
      _logger.e('Error during Google Sign-In',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      final userEmail = _firebaseAuth.currentUser?.email ?? 'unknown user';
      _logger.i('Signing out user: $userEmail');
      await Future.wait([
        _firebaseAuth.signOut(),
        _googleSignIn.signOut(),
      ]);
      _logger.i('Sign out successful for: $userEmail');
    } catch (e, stackTrace) {
      _logger.e('Error during sign out', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> resetPasswordForEmail(String email) async {
    try {
      _logger.i('Sending password reset email to: $email');
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      _logger.i('Password reset email sent successfully to: $email');
    } on firebase_auth.FirebaseAuthException catch (e) {
      _logger.e('FirebaseAuthException sending password reset to $email',
          error: e, stackTrace: StackTrace.current);
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error sending password reset to $email',
          error: e, stackTrace: stackTrace);
      // Consider wrapping in a custom exception if needed by UI
      rethrow;
    }
  }

  @override
  Future<void> sendVerificationEmail() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
        _logger.i('Verification email sent to ${user.email}');
      } catch (e, stackTrace) {
        _logger.e('Error sending verification email to ${user.email}',
            error: e, stackTrace: stackTrace);
        rethrow;
      }
    } else if (user == null) {
      _logger.w('Attempted to send verification email, but user is null.');
      throw firebase_auth.FirebaseAuthException(
        code: 'no-user',
        message: 'No user is currently signed in.',
      );
    } else if (user.emailVerified) {
      _logger.i(
          'Attempted to send verification email, but user ${user.email} is already verified.');
    }
  }
}

// Provider definition (adjust if logger is injected differently)
/// Riverpod provider for the [FirebaseAuthRepository].
/// Creates a singleton instance using the default Firebase Auth instance
/// and the shared logger provider.
final firebaseAuthRepositoryProvider = Provider<FirebaseAuthRepository>((ref) {
  // If using a shared logger provider:
  final logger = ref.watch(loggerProvider);
  return FirebaseAuthRepository(firebase_auth.FirebaseAuth.instance, logger);
  // Or create a new logger instance here if not using a provider:
  // return FirebaseAuthRepository(firebase_auth.FirebaseAuth.instance, Logger());
});
