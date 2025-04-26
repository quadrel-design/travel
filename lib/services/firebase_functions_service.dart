import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:logger/logger.dart';

class FirebaseFunctionsService {
  final Logger _logger;
  final FirebaseFunctions _functions;
  static const int _defaultTimeoutSeconds = 60;

  FirebaseFunctionsService({
    required Logger logger,
    FirebaseFunctions? functions,
  })  : _logger = logger,
        _functions = functions ?? FirebaseFunctions.instance;

  Future<Map<String, String>> _getAuthHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    final token = await user.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> scanImage(
      String imageUrl, String journeyId, String imageId,
      {int timeoutSeconds = _defaultTimeoutSeconds}) async {
    try {
      _logger.d('[FUNCTIONS] Preparing to scan image: $imageUrl');
      _logger.d('[FUNCTIONS] Journey ID: $journeyId, Image ID: $imageId');

      final callable = _functions.httpsCallable('scanImage');
      _logger.d(
          '[FUNCTIONS] Calling scanImage function with timeout: ${timeoutSeconds}s');

      final resultFuture = callable.call<Map<String, dynamic>>({
        'imageUrl': imageUrl,
        'journeyId': journeyId,
        'imageId': imageId,
      });

      // Add timeout to prevent indefinite waiting
      final result = await resultFuture.timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          throw TimeoutException(
              'Function call timed out after $timeoutSeconds seconds');
        },
      );

      if (result.data == null) {
        throw Exception('Received null response from cloud function');
      }

      _logger.d('[FUNCTIONS] Raw result type: ${result.data.runtimeType}');
      _logger.d('[FUNCTIONS] Raw result data: ${result.data}');

      final data = result.data;

      // Ensure we have a valid status
      if (!data.containsKey('status')) {
        _logger.w(
            '[FUNCTIONS] Response is missing status field, defaulting to "Text"');
        data['status'] = 'Text';
      }

      // Ensure we have success flag
      if (!data.containsKey('success')) {
        _logger.w(
            '[FUNCTIONS] Response is missing success field, defaulting to true');
        data['success'] = true;
      }

      _logger.i(
          '[FUNCTIONS] Scan completed successfully with status: ${data['status']}');
      return data;
    } on FirebaseFunctionsException catch (e, stackTrace) {
      _logger.e('[FUNCTIONS] Firebase function error:',
          error: e, stackTrace: stackTrace);

      // Return a structured error response instead of throwing
      return {
        'success': false,
        'status': 'Error',
        'error': e.message ?? 'Firebase function error',
        'code': e.code,
      };
    } catch (e, stackTrace) {
      _logger.e('[FUNCTIONS] Error scanning image:',
          error: e, stackTrace: stackTrace);

      // Return a structured error response instead of throwing
      return {
        'success': false,
        'status': 'Error',
        'error': e.toString(),
      };
    }
  }
}
