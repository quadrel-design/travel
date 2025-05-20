class User {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final bool emailVerified;
  final DateTime createdAt;
  final DateTime lastLoginAt;

  User({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.emailVerified,
    required this.createdAt,
    required this.lastLoginAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      emailVerified: json['emailVerified'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: DateTime.parse(json['lastLoginAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'emailVerified': emailVerified,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt.toIso8601String(),
    };
  }
}

abstract class AuthService {
  /// Get the current user
  User? get currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges;

  /// Sign in with email and password
  Future<User> signInWithEmailAndPassword(String email, String password);

  /// Create a new user with email and password
  Future<User> createUserWithEmailAndPassword(String email, String password);

  /// Sign out the current user
  Future<void> signOut();

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email);

  /// Update user profile
  Future<void> updateProfile({
    String? displayName,
    String? photoUrl,
  });

  /// Update user email
  Future<void> updateEmail(String newEmail);

  /// Update user password
  Future<void> updatePassword(String newPassword);

  /// Delete the current user account
  Future<void> deleteAccount();

  /// Verify email address
  Future<void> sendEmailVerification();
}
