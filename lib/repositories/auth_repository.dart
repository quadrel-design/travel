import 'package:firebase_auth/firebase_auth.dart'; // Keep this for type definitions
// import 'package:firebase_auth/firebase_auth.dart' as firebase_auth; // Remove prefixed import

// Abstract base class or concrete class for Auth Repository
abstract class AuthRepository {
  // Replace Supabase client with FirebaseAuth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream emits User? (Firebase User) instead of AuthState
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Returns Firebase User?
  User? get currentUser => _auth.currentUser;

  // Remove Supabase Session - rely on currentUser != null
  // Session? get currentSession => _client.auth.currentSession;

  Future<void> signInWithPassword(String email, String password) async {
    // Use Firebase sign in
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password) async {
    // Use Firebase sign up
    await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    // Consider sending email verification here if needed
    // await _auth.currentUser?.sendEmailVerification();
  }

  Future<void> signOut() async {
    // Use Firebase sign out
    await _auth.signOut();
  }

  Future<void> resetPasswordForEmail(String email) async {
    // Removed redirectTo for simplicity
    // Use Firebase password reset
    await _auth.sendPasswordResetEmail(email: email);
    // Add ActionCodeSettings later if custom redirect/handling is needed
  }

  // Method to send verification email
  Future<void> sendVerificationEmail();

  // Add other auth methods as needed (e.g., signInWithOtp, updatePassword)
}
