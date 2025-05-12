import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing user subscription status.
///
/// This service provides methods to retrieve the current subscription status
/// from Firebase Auth custom claims and to toggle between 'pro' and 'free'
/// subscription tiers by calling the backend API.
class UserSubscriptionService {
  /// Base URL for the backend API endpoints related to user management.
  ///
  /// This should be updated to the actual deployed backend URL in production.
  final String _baseUrl = 'https://your-backend-url.com/api/user';

  /// Retrieves the current subscription status from Firebase Auth custom claims.
  ///
  /// Returns 'pro' if the user has a pro subscription, otherwise returns 'free'.
  /// If the user is not authenticated, it defaults to 'free'.
  Future<String> getCurrentSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'free';

    // First try to get from ID token
    try {
      final idTokenResult = await user.getIdTokenResult(true);
      final subscription = idTokenResult.claims?['subscription'] as String?;
      if (subscription != null) {
        return subscription;
      }
    } catch (e) {
      // Fallback to API call if getIdTokenResult fails
    }

    // If not found in token or error, try API
    try {
      final idToken = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/subscription-status'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['subscription'] as String? ?? 'free';
      }
    } catch (e) {
      // Ignore API errors and return default
    }

    return 'free';
  }

  /// Toggles the subscription status between 'pro' and 'free'.
  ///
  /// Calls the backend API to update the subscription status in Firebase Auth.
  /// Returns the new subscription status.
  /// Throws an exception if the user is not authenticated or if the API call fails.
  Future<String> toggleSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final idToken = await user.getIdToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/toggle-subscription'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['subscription'] as String? ?? 'free';
    } else {
      throw Exception('Failed to toggle subscription: ${response.body}');
    }
  }
}
