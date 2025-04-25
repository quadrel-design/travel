import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class LocationService {
  final Logger _logger;
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json';
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
        Uri.parse('$_baseUrl?input=$query&types=(cities)&key=$_apiKey'),
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
}
