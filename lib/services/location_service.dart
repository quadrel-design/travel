import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../repositories/repository_exceptions.dart';

/**
 * Location Service
 *
 * Provides a service for interacting with the Google Places API to search
 * for locations, find place IDs, and retrieve place details.
 */
class LocationService {
  final Logger _logger;
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';
  final String _apiKey;

  /// Creates an instance of [LocationService].
  ///
  /// Requires a [Logger] instance.
  /// Loads the Google Places API key from the `.env` file via `flutter_dotenv`.
  ///
  /// Throws [LocationServiceException] if the API key (`GOOGLE_PLACES_API_KEY`) is not found or empty.
  LocationService(this._logger)
      : _apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '' {
    // Debug log to verify API key is loaded
    if (_apiKey.isEmpty) {
      _logger.w('Google Places API key is not configured in .env file');
      // Throw immediately if key is missing, as the service is unusable.
      throw LocationServiceException(
          'Google Places API key (GOOGLE_PLACES_API_KEY) not found in .env');
    } else {
      _logger.i('Google Places API key loaded successfully');
    }
  }

  /// Searches for location suggestions based on a query string using the Places Autocomplete API.
  ///
  /// Parameters:
  ///  - [query]: The search string.
  ///
  /// Returns: A [List<String>] of location descriptions (e.g., "Paris, France").
  /// Returns an empty list if the query is empty.
  ///
  /// Throws [LocationServiceException] if the API call fails (network error, API error, parsing error).
  Future<List<String>> searchLocations(String query) async {
    if (query.isEmpty) {
      return [];
    }

    if (_apiKey.isEmpty) {
      _logger.e('[LOCATION] Google Places API key is not configured');
      return [];
    }

    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/autocomplete/json?input=$query&types=(cities)&key=$_apiKey'),
      );

      if (response.statusCode != 200) {
        _logger.e(
            '[LOCATION] Places Autocomplete request failed with status: ${response.statusCode}');
        throw LocationServiceException(
            'Autocomplete request failed (HTTP ${response.statusCode})',
            originalException: response.body);
      }

      final data = json.decode(response.body);
      final status = data['status'];
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        _logger.e(
            '[LOCATION] Places Autocomplete API error: $status - ${data["error_message"] ?? "Unknown reason"}');
        throw LocationServiceException('Autocomplete API error: $status',
            apiStatus: status, originalException: data["error_message"]);
      }
      // Return empty list for ZERO_RESULTS, don't throw
      if (status == 'ZERO_RESULTS') {
        return [];
      }

      final predictions = data['predictions'] as List;
      return predictions
          .map((prediction) => prediction['description'] as String)
          .toList();
    } on LocationServiceException {
      // Re-throw specific exceptions
      rethrow;
    } catch (e, stackTrace) {
      // Catch network/parsing errors
      _logger.e('[LOCATION] Error fetching location suggestions',
          error: e, stackTrace: stackTrace);
      throw LocationServiceException('Failed to fetch location suggestions',
          originalException: e, stackTrace: stackTrace);
    }
  }

  /// Retrieves details for a specific place using its Place ID.
  ///
  /// Parameters:
  ///  - [placeId]: The Google Places Place ID.
  ///
  /// Returns: A [Map<String, dynamic>] containing the place details (name, address, geometry, types).
  ///
  /// Throws [LocationServiceException] if the Place ID is invalid, the API call fails,
  /// or the place is not found.
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    if (_apiKey.isEmpty) {
      _logger.e('[LOCATION] Google Places API key is not configured');
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/details/json?place_id=$placeId&fields=name,formatted_address,geometry,types&key=$_apiKey'),
      );

      if (response.statusCode != 200) {
        _logger.e(
            '[LOCATION] Place Details request failed with status: ${response.statusCode}');
        throw LocationServiceException(
            'Place Details request failed (HTTP ${response.statusCode})',
            originalException: response.body);
      }

      final data = json.decode(response.body);
      final status = data['status'];
      if (status != 'OK') {
        _logger.e(
            '[LOCATION] Place Details API error: $status - ${data["error_message"] ?? "Place not found or invalid"}');
        throw LocationServiceException('Place Details API error: $status',
            apiStatus: status,
            originalException:
                data["error_message"] ?? "Place not found or invalid");
      }

      return data['result'] as Map<String, dynamic>;
    } on LocationServiceException {
      // Re-throw specific exceptions
      rethrow;
    } catch (e, stackTrace) {
      // Catch network/parsing errors
      _logger.e('[LOCATION] Error fetching place details',
          error: e, stackTrace: stackTrace);
      throw LocationServiceException('Failed to fetch place details',
          originalException: e, stackTrace: stackTrace);
    }
  }

  /// Finds the Place ID for a given location name or address using the Find Place API.
  ///
  /// Parameters:
  ///  - [location]: The location string to search for.
  ///
  /// Returns: The Place ID ([String]) if found, or `null` if no match is found.
  ///
  /// Throws [LocationServiceException] if the API call fails.
  Future<String?> findPlaceId(String location) async {
    if (_apiKey.isEmpty) {
      _logger.e('[LOCATION] Google Places API key is not configured');
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/findplacefromtext/json?input=$location&inputtype=textquery&fields=place_id&key=$_apiKey'),
      );

      if (response.statusCode != 200) {
        _logger.e(
            '[LOCATION] Find Place request failed with status: ${response.statusCode}');
        throw LocationServiceException(
            'Find Place request failed (HTTP ${response.statusCode})',
            originalException: response.body);
      }

      final data = json.decode(response.body);
      final status = data['status'];
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        _logger.e(
            '[LOCATION] Find Place API error: $status - ${data["error_message"] ?? "Unknown reason"}');
        throw LocationServiceException('Find Place API error: $status',
            apiStatus: status, originalException: data["error_message"]);
      }
      // Return null for ZERO_RESULTS (no place found), don't throw
      if (status == 'ZERO_RESULTS') {
        return null;
      }

      final candidates = data['candidates'] as List;
      if (candidates.isEmpty) {
        return null;
      }

      // Return the place_id of the first candidate
      return candidates.first['place_id'] as String?;
    } on LocationServiceException {
      // Re-throw specific exceptions
      rethrow;
    } catch (e, stackTrace) {
      // Catch network/parsing errors
      _logger.e('[LOCATION] Error finding place',
          error: e, stackTrace: stackTrace);
      throw LocationServiceException('Failed to find place ID',
          originalException: e, stackTrace: stackTrace);
    }
  }
}
