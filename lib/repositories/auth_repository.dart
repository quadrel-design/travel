import 'package:supabase_flutter/supabase_flutter.dart';

// Abstract base class or concrete class for Auth Repository
class AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;

  Future<void> signInWithPassword(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
    // Error handling will be done in the calling code (e.g., ViewModel/Bloc)
  }

  Future<void> signUp(String email, String password) async {
    await _client.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPasswordForEmail(String email, {String? redirectTo}) async {
     await _client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }

  // Add other auth methods as needed (e.g., signInWithOtp, updatePassword)
} 