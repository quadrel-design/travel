import 'package:firebase_auth/firebase_auth.dart'; // Keep this for type definitions
// import 'package:firebase_auth/firebase_auth.dart' as firebase_auth; // Remove prefixed import
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';

// Abstract base class or concrete class for Auth Repository
abstract class AuthRepository {
  // Replace Supabase client with FirebaseAuth instance
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final Logger _logger;

  AuthRepository({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    Logger? logger,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _logger = logger ?? Logger();

  // Stream emits User? (Firebase User) instead of AuthState
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Returns Firebase User?
  User? get currentUser => _auth.currentUser;

  // Remove Supabase Session - rely on currentUser != null
  // Session? get currentSession => _client.auth.currentSession;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } catch (e) {
      _logger.e('[AUTH] Error signing in:', error: e);
      rethrow;
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'ERROR_ABORTED_BY_USER',
          message: 'Sign in aborted by user',
        );
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      _logger.e('[AUTH] Error signing in with Google:', error: e);
      rethrow;
    }
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential;
    } catch (e) {
      _logger.e('[AUTH] Error creating user with email and password:',
          error: e);
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      _logger.e('[AUTH] Error signing out:', error: e);
      rethrow;
    }
  }

  Future<void> resetPasswordForEmail(String email) async {
    // Removed redirectTo for simplicity
    // Use Firebase password reset
    await _auth.sendPasswordResetEmail(email: email);
    // Add ActionCodeSettings later if custom redirect/handling is needed
  }

  // Method to send verification email
  Future<void> sendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  // Add other auth methods as needed (e.g., signInWithOtp, updatePassword)
}
