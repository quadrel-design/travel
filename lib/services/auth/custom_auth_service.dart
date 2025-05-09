import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

class CustomAuthService implements AuthService {
  final String _apiBaseUrl;
  final Logger _logger;
  final _authStateController = StreamController<User?>.broadcast();
  User? _currentUser;
  String? _authToken;

  CustomAuthService({
    required String apiBaseUrl,
    required Logger logger,
  })  : _apiBaseUrl = apiBaseUrl,
        _logger = logger {
    _initAuthState();
  }

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> get authStateChanges => _authStateController.stream;

  Future<void> _initAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null) {
        await _validateAndSetToken(token);
      }
    } catch (e, stackTrace) {
      _logger.e('Error initializing auth state',
          error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _validateAndSetToken(String token) async {
    try {
      if (JwtDecoder.isExpired(token)) {
        await _refreshToken(token);
        return;
      }

      final decodedToken = JwtDecoder.decode(token);
      _authToken = token;
      _currentUser = User.fromJson(decodedToken['user']);
      _authStateController.add(_currentUser);
    } catch (e, stackTrace) {
      _logger.e('Error validating token', error: e, stackTrace: stackTrace);
      await _clearAuthState();
    }
  }

  Future<void> _refreshToken(String oldToken) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/auth/refresh'),
        headers: {'Authorization': 'Bearer $oldToken'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _saveToken(data['token']);
      } else {
        await _clearAuthState();
      }
    } catch (e, stackTrace) {
      _logger.e('Error refreshing token', error: e, stackTrace: stackTrace);
      await _clearAuthState();
    }
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await _validateAndSetToken(token);
  }

  Future<void> _clearAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _authToken = null;
    _currentUser = null;
    _authStateController.add(null);
  }

  @override
  Future<User> signInWithEmailAndPassword(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': _hashPassword(password),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _saveToken(data['token']);
        return _currentUser!;
      } else {
        throw AuthException('Invalid email or password');
      }
    } catch (e, stackTrace) {
      _logger.e('Error signing in', error: e, stackTrace: stackTrace);
      throw AuthException('Failed to sign in: $e');
    }
  }

  @override
  Future<User> createUserWithEmailAndPassword(
      String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': _hashPassword(password),
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        await _saveToken(data['token']);
        return _currentUser!;
      } else {
        throw AuthException('Failed to create account');
      }
    } catch (e, stackTrace) {
      _logger.e('Error creating account', error: e, stackTrace: stackTrace);
      throw AuthException('Failed to create account: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (_authToken != null) {
        await http.post(
          Uri.parse('$_apiBaseUrl/auth/logout'),
          headers: {'Authorization': 'Bearer $_authToken'},
        );
      }
      await _clearAuthState();
    } catch (e, stackTrace) {
      _logger.e('Error signing out', error: e, stackTrace: stackTrace);
      throw AuthException('Failed to sign out: $e');
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      if (response.statusCode != 200) {
        throw AuthException('Failed to send password reset email');
      }
    } catch (e, stackTrace) {
      _logger.e('Error sending password reset email',
          error: e, stackTrace: stackTrace);
      throw AuthException('Failed to send password reset email: $e');
    }
  }

  @override
  Future<void> updateProfile({String? displayName, String? photoUrl}) async {
    try {
      final response = await http.patch(
        Uri.parse('$_apiBaseUrl/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: json.encode({
          if (displayName != null) 'displayName': displayName,
          if (photoUrl != null) 'photoUrl': photoUrl,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _saveToken(data['token']);
      } else {
        throw AuthException('Failed to update profile');
      }
    } catch (e, stackTrace) {
      _logger.e('Error updating profile', error: e, stackTrace: stackTrace);
      throw AuthException('Failed to update profile: $e');
    }
  }

  @override
  Future<void> updateEmail(String newEmail) async {
    try {
      final response = await http.patch(
        Uri.parse('$_apiBaseUrl/auth/email'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: json.encode({'email': newEmail}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _saveToken(data['token']);
      } else {
        throw AuthException('Failed to update email');
      }
    } catch (e, stackTrace) {
      _logger.e('Error updating email', error: e, stackTrace: stackTrace);
      throw AuthException('Failed to update email: $e');
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      final response = await http.patch(
        Uri.parse('$_apiBaseUrl/auth/password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: json.encode({'password': _hashPassword(newPassword)}),
      );

      if (response.statusCode != 200) {
        throw AuthException('Failed to update password');
      }
    } catch (e, stackTrace) {
      _logger.e('Error updating password', error: e, stackTrace: stackTrace);
      throw AuthException('Failed to update password: $e');
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final response = await http.delete(
        Uri.parse('$_apiBaseUrl/auth/account'),
        headers: {'Authorization': 'Bearer $_authToken'},
      );

      if (response.statusCode == 200) {
        await _clearAuthState();
      } else {
        throw AuthException('Failed to delete account');
      }
    } catch (e, stackTrace) {
      _logger.e('Error deleting account', error: e, stackTrace: stackTrace);
      throw AuthException('Failed to delete account: $e');
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/auth/verify-email'),
        headers: {'Authorization': 'Bearer $_authToken'},
      );

      if (response.statusCode != 200) {
        throw AuthException('Failed to send verification email');
      }
    } catch (e, stackTrace) {
      _logger.e('Error sending verification email',
          error: e, stackTrace: stackTrace);
      throw AuthException('Failed to send verification email: $e');
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  void dispose() {
    _authStateController.close();
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}
