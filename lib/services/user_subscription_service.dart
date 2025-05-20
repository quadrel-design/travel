import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:travel/config/service_config.dart';
import 'package:logger/logger.dart';

/// Service for managing user subscription status.
///
/// This service provides methods to retrieve the current subscription status
/// from Firebase Auth custom claims and to toggle between 'pro' and 'free'
/// subscription tiers by calling the backend API.
class UserSubscriptionService {
  final Logger _logger = Logger();

  /// Base URL for the backend API endpoints related to user management.
  ///
  /// This should be updated to the actual deployed backend URL in production.
  final String _baseUrl = '${ServiceConfig.gcsApiBaseUrl}/api/user';

  /// Retrieves the current subscription status from Firebase Auth custom claims.
  ///
  /// Returns 'pro' if the user has a pro subscription, otherwise returns 'free'.
  /// If the user is not authenticated, it defaults to 'free'.
  Future<String> getCurrentSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _logger
          .d('[UserSubSvc] No user, returning default \'free\' subscription.');
      return 'free';
    }

    try {
      final idTokenResult = await user.getIdTokenResult(true);
      final subscription = idTokenResult.claims?['subscription'] as String?;
      if (subscription != null) {
        _logger.d('[UserSubSvc] Got subscription from ID token: $subscription');
        return subscription;
      }
    } catch (e, s) {
      _logger.w(
          '[UserSubSvc] Failed to get subscription from ID token, will try API.',
          error: e,
          stackTrace: s);
    }

    try {
      final idToken = await user.getIdToken();
      final getUrlToCall = Uri.parse('$_baseUrl/subscription-status');
      _logger.i('[UserSubSvc] Attempting to GET from: $getUrlToCall');
      final response = await http.get(
        getUrlToCall,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final sub = data['subscription'] as String? ?? 'free';
        _logger.d('[UserSubSvc] Got subscription from API: $sub');
        return sub;
      } else {
        String logMessage =
            '[UserSubSvc] Failed to get subscription status from API. Status: ${response.statusCode}.';
        if (response.body.isNotEmpty) {
          logMessage += ' Body: ${response.body}';
        }
        _logger.w(logMessage);
      }
    } catch (e, s) {
      _logger.e('[UserSubSvc] Error calling subscription-status API.',
          error: e, stackTrace: s);
    }

    _logger.w(
        '[UserSubSvc] Falling back to default \'free\' subscription status after API attempt.');
    return 'free';
  }

  /// Toggles the subscription status between 'pro' and 'free'.
  ///
  /// Calls the backend API to update the subscription status in Firebase Auth.
  /// Returns the new subscription status.
  /// Throws an exception if the user is not authenticated or if the API call fails.
  Future<String> toggleSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _logger.w('[UserSubSvc] toggleSubscription: User not logged in.');
      throw Exception('User not logged in');
    }

    final idToken = await user.getIdToken();
    final urlToCall = Uri.parse('$_baseUrl/toggle-subscription');
    _logger.i('[UserSubSvc] Attempting to POST to: $urlToCall');
    final response = await http.post(
      urlToCall,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final sub = data['subscription'] as String? ?? 'free';
      _logger.d('[UserSubSvc] Toggled subscription via API to: $sub');
      return sub;
    } else {
      String errorMessage = 'Failed to toggle subscription';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map && errorBody.containsKey('error')) {
          errorMessage += ': ${errorBody['error']}';
        } else {
          errorMessage += ': ${response.body}';
        }
      } catch (e) {
        if (response.body.isNotEmpty) {
          errorMessage += ': ${response.body}';
        } else {
          errorMessage += ' (Status: ${response.statusCode})';
        }
      }
      _logger.e(
          '[UserSubSvc] Error from toggleSubscription. Final Error: "$errorMessage". Raw Status: ${response.statusCode}. Raw Body: "${response.body}"');
      throw Exception(errorMessage);
    }
  }
}
