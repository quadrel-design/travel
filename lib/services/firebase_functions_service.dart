import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:logger/logger.dart';
import '../providers/logging_provider.dart';

class FirebaseFunctionsService {
  final Logger _logger;
  final FirebaseFunctions _functions;

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
      String imageUrl, String journeyId, String imageId) async {
    try {
      _logger.d('[FUNCTIONS] Preparing to scan image: $imageUrl');
      _logger.d('[FUNCTIONS] Journey ID: $journeyId, Image ID: $imageId');

      final callable = _functions.httpsCallable('scanImage');
      _logger.d('[FUNCTIONS] Calling scanImage function...');

      final result = await callable.call<Map<String, dynamic>>({
        'imageUrl': imageUrl,
        'journeyId': journeyId,
        'imageId': imageId,
      });

      _logger.d('[FUNCTIONS] Raw result: ${result.data}');
      final data = result.data;
      _logger.i('[FUNCTIONS] Scan completed successfully');
      return data;
    } catch (e, stackTrace) {
      _logger.e('[FUNCTIONS] Error scanning image:',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
