import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class LocationService {
  final Logger _logger;
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';
  final String _apiKey;

  LocationService(this._logger)
      : _apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '' {
    // Debug log to verify API key is loaded
    if (_apiKey.isEmpty) {
      _logger.w('Google Places API key is not configured in .env file');
    } else {
      _logger.i('Google Places API key loaded successfully');
    }
  }

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
        Uri.parse('$_baseUrl/autocomplete/json?input=$query&types=(cities)&key=$_apiKey'),
      );

      if (response.statusCode != 200) {
        _logger.e(
            '[LOCATION] Failed to fetch location suggestions: ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body);
      if (data['status'] != 'OK') {
        _logger.e('[LOCATION] Google Places API error: ${data['status']}');
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

  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    if (_apiKey.isEmpty) {
      _logger.e('[LOCATION] Google Places API key is not configured');
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/details/json?place_id=$placeId&fields=name,formatted_address,geometry,types&key=$_apiKey'),
      );

      if (response.statusCode != 200) {
        _logger.e(
            '[LOCATION] Failed to fetch place details: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);
      if (data['status'] != 'OK') {
        _logger.e('[LOCATION] Google Places API error: ${data['status']}');
        return null;
      }

      return data['result'] as Map<String, dynamic>;
    } catch (e, stackTrace) {
      _logger.e('[LOCATION] Error fetching place details',
          error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<String?> findPlaceId(String location) async {
    if (_apiKey.isEmpty) {
      _logger.e('[LOCATION] Google Places API key is not configured');
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/findplacefromtext/json?input=$location&inputtype=textquery&fields=place_id&key=$_apiKey'),
      );

      if (response.statusCode != 200) {
        _logger.e(
            '[LOCATION] Failed to find place: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);
      if (data['status'] != 'OK') {
        _logger.e('[LOCATION] Google Places API error: ${data['status']}');
        return null;
      }

      final candidates = data['candidates'] as List;
      if (candidates.isEmpty) {
        return null;
      }

      return candidates[0]['place_id'] as String;
    } catch (e, stackTrace) {
      _logger.e('[LOCATION] Error finding place',
          error: e, stackTrace: stackTrace);
      return null;
    }
  }
}
