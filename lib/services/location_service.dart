import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

/// Location Service
///
/// Provides a service for interacting with the Google Places API to search
/// for locations, find place IDs, and retrieve place details.
class LocationService {
  final Logger _logger;
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';
  final String _apiKey;
  final bool _isServiceEnabled;

  /// Creates an instance of [LocationService].
  ///
  /// Requires a [Logger] instance.
  /// Loads the Google Places API key from the `.env` file via `flutter_dotenv`.
  ///
  /// Does not throw exceptions for missing API keys anymore.
  LocationService(this._logger)
      : _apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '',
        _isServiceEnabled =
            dotenv.env['GOOGLE_PLACES_API_KEY']?.isNotEmpty ?? false {
    // Debug log to verify API key status
    if (_apiKey.isEmpty) {
      _logger.w(
          'Google Places API functionality disabled: API key is not configured in .env file');
    } else {
      _logger.i('Google Places API key loaded successfully');
    }
  }

  /// Searches for location suggestions based on a query string using the Places Autocomplete API.
  ///
  /// Returns an empty list if Places API is disabled.
  Future<List<String>> searchLocations(String query) async {
    if (query.isEmpty || !_isServiceEnabled) {
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
        return [];
      }

      final data = json.decode(response.body);
      final status = data['status'];
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        _logger.e(
            '[LOCATION] Places Autocomplete API error: $status - ${data["error_message"] ?? "Unknown reason"}');
        return [];
      }

      if (status == 'ZERO_RESULTS') {
        return [];
      }

      final predictions = data['predictions'] as List;
      return predictions
          .map((prediction) => prediction['description'] as String)
          .toList();
    } catch (e, stackTrace) {
      _logger.e('[LOCATION] Error fetching location suggestions',
          error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Retrieves details for a specific place using its Place ID.
  ///
  /// Returns null if Places API is disabled or on any error.
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    if (!_isServiceEnabled) {
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
        return null;
      }

      final data = json.decode(response.body);
      final status = data['status'];
      if (status != 'OK') {
        _logger.e(
            '[LOCATION] Place Details API error: $status - ${data["error_message"] ?? "Place not found or invalid"}');
        return null;
      }

      return data['result'] as Map<String, dynamic>;
    } catch (e, stackTrace) {
      _logger.e('[LOCATION] Error fetching place details',
          error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Finds the Place ID for a given location name or address using the Find Place API.
  ///
  /// Returns null if Places API is disabled or on any error.
  Future<String?> findPlaceId(String location) async {
    if (!_isServiceEnabled) {
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
        return null;
      }

      final data = json.decode(response.body);
      final status = data['status'];
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        _logger.e(
            '[LOCATION] Find Place API error: $status - ${data["error_message"] ?? "Unknown reason"}');
        return null;
      }

      if (status == 'ZERO_RESULTS') {
        return null;
      }

      final candidates = data['candidates'] as List;
      if (candidates.isEmpty) {
        return null;
      }

      // Return the place_id of the first candidate
      return candidates.first['place_id'] as String?;
    } catch (e, stackTrace) {
      _logger.e('[LOCATION] Error finding place',
          error: e, stackTrace: stackTrace);
      return null;
    }
  }
}
