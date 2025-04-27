import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:logger/logger.dart';
import '../repositories/repository_exceptions.dart';

/**
 * Firebase Functions Service
 *
 * Provides a service for interacting with backend Firebase Cloud Functions,
 * handling function calls, parameter passing, timeouts, and error handling.
 * It wraps Cloud Function calls and throws custom exceptions on failure.
 */
class FirebaseFunctionsService {
  final Logger _logger;
  final FirebaseFunctions _functions;
  static const int _defaultTimeoutSeconds = 60;

  /// Creates an instance of [FirebaseFunctionsService].
  ///
  /// Requires a [Logger] instance.
  /// Optionally takes a [FirebaseFunctions] instance (defaults to singleton).
  FirebaseFunctionsService({
    required Logger logger,
    FirebaseFunctions? functions,
  })  : _logger = logger,
        _functions = functions ?? FirebaseFunctions.instance;

  /// Calls the 'scanImage' Cloud Function.
  ///
  /// Parameters:
  ///  - [imageUrl]: The URL of the image to scan.
  ///  - [journeyId]: The ID of the associated journey/invoice.
  ///  - [imageId]: The ID of the specific image document.
  ///  - [timeoutSeconds]: Optional timeout duration (defaults to 60s).
  ///
  /// Returns: A [Map<String, dynamic>] containing the function's result data upon success.
  ///
  /// Throws:
  ///  - [FunctionCallException]: If the Cloud Function call fails, times out,
  ///    or returns an unexpected result.
  ///  - [TimeoutException]: If the call exceeds the specified timeout (wrapped by FunctionCallException).
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
      final HttpsCallableResult<Map<String, dynamic>> result =
          await resultFuture.timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          throw TimeoutException(
              'Function call timed out after $timeoutSeconds seconds');
        },
      );

      _logger.d('[FUNCTIONS] Raw result data: ${result.data}');

      final data = result.data;

      // Ensure we have a valid status
      if (!data.containsKey('success') ||
          data['success'] != true ||
          !data.containsKey('status')) {
        _logger.w(
            '[FUNCTIONS] Function call successful, but response format is unexpected. Data: $data');
        throw FunctionCallException(
          'Function response format unexpected',
          functionName: 'scanImage',
          originalException: 'Missing success or status fields in response',
        );
      }

      _logger.i(
          '[FUNCTIONS] Scan completed successfully with status: ${data['status']}');
      return data;
    } on FirebaseFunctionsException catch (e, stackTrace) {
      _logger.e('[FUNCTIONS] Firebase function error:',
          error: e, stackTrace: stackTrace);
      throw FunctionCallException(
        e.message ?? 'Firebase function error',
        functionName: 'scanImage',
        code: e.code,
        originalException: e,
        stackTrace: stackTrace,
      );
    } on TimeoutException catch (e, stackTrace) {
      _logger.e('[FUNCTIONS] Timeout calling scanImage:',
          error: e, stackTrace: stackTrace);
      throw FunctionCallException(
        'Function call timed out after $timeoutSeconds seconds',
        functionName: 'scanImage',
        code: 'timeout',
        originalException: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      _logger.e('[FUNCTIONS] Error scanning image:',
          error: e, stackTrace: stackTrace);
      throw FunctionCallException(
        e.toString(),
        functionName: 'scanImage',
        originalException: e,
        stackTrace: stackTrace,
      );
    }
  }
}
