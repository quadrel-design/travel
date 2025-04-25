import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:logger/logger.dart';
import './auth_repository.dart'; // Import the abstract class
import '../providers/logging_provider.dart'; // Import logger provider if used
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Ref for logger

// Concrete implementation using Firebase Authentication
class FirebaseAuthRepository implements AuthRepository {
  final firebase_auth.FirebaseAuth _firebaseAuth;
  final Logger _logger;

  // Constructor takes FirebaseAuth instance and Logger
  FirebaseAuthRepository(this._firebaseAuth, this._logger);

  // --- Implement abstract methods ---

  @override
  Stream<firebase_auth.User?> get authStateChanges =>
      _firebaseAuth.authStateChanges();

  @override
  firebase_auth.User? get currentUser => _firebaseAuth.currentUser;

  @override
  Future<void> signUp(String email, String password) async {
    try {
      _logger.i('Attempting to sign up user: $email');
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Send verification email immediately after successful creation
      await sendVerificationEmail();
      _logger.i('Sign up successful for: $email');
    } on firebase_auth.FirebaseAuthException catch (e) {
      _logger.e('FirebaseAuthException during sign up for $email',
          error: e, stackTrace: StackTrace.current);
      // Rethrow to be handled by the UI layer
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during sign up for $email',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> signInWithPassword(String email, String password) async {
    try {
      _logger.i('Attempting to sign in user: $email');
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _logger.i('Sign in successful for: $email');
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
  Future<void> signOut() async {
    try {
      final userEmail = _firebaseAuth.currentUser?.email ?? 'unknown user';
      _logger.i('Signing out user: $userEmail');
      await _firebaseAuth.signOut();
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
        // Decide if we should rethrow or just log
        rethrow;
      }
    } else if (user == null) {
      _logger.w('Attempted to send verification email, but user is null.');
      // Optionally throw an error or handle appropriately
    } else {
      _logger.i(
          'Attempted to send verification email, but email (${user.email}) is already verified.');
    }
  }
}

// Provider definition (adjust if logger is injected differently)
final firebaseAuthRepositoryProvider = Provider<FirebaseAuthRepository>((ref) {
  // If using a shared logger provider:
  final logger = ref.watch(loggerProvider);
  return FirebaseAuthRepository(firebase_auth.FirebaseAuth.instance, logger);
  // Or create a new logger instance here if not using a provider:
  // return FirebaseAuthRepository(firebase_auth.FirebaseAuth.instance, Logger());
});
