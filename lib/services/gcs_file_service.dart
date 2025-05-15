import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GcsFileService {
  final String backendBaseUrl;
  final Logger _logger = Logger();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  GcsFileService({required this.backendBaseUrl});

  /// Helper method to get authorization headers with Firebase token
  Future<Map<String, String>> _getAuthHeaders() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final token = await user.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Uploads a file to GCS via your backend.
  /// Returns the GCS path of the uploaded file.
  Future<String> uploadFile({
    required Uint8List fileBytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    try {
      _logger.i('[GCS] Uploading $fileName with contentType: $contentType');

      // Get auth headers
      final headers = await _getAuthHeaders();

      // 1. Get signed upload URL from backend
      final uploadUrlResp = await http.post(
        Uri.parse('$backendBaseUrl/api/gcs/generate-upload-url'),
        headers: headers,
        body: jsonEncode({'filename': fileName, 'contentType': contentType}),
      );
      if (uploadUrlResp.statusCode != 200) {
        throw Exception(
            'Failed to get signed upload URL: ${uploadUrlResp.body}');
      }
      final signedUrl = jsonDecode(uploadUrlResp.body)['url'];

      // 2. Upload file to GCS using signed URL
      final uploadResp = await http.put(
        Uri.parse(signedUrl),
        headers: {'Content-Type': contentType},
        body: fileBytes,
      );
      if (uploadResp.statusCode != 200 && uploadResp.statusCode != 201) {
        throw Exception('Failed to upload file: ${uploadResp.body}');
      }

      // 3. Return the GCS path (not the signed URL)
      return fileName;
    } catch (e, stackTrace) {
      _logger.e('Error uploading file', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Gets a signed download URL from the backend for a file in GCS.
  Future<String> getSignedDownloadUrl({required String fileName}) async {
    try {
      // Get auth headers
      final headers = await _getAuthHeaders();

      // First try the new /get-signed-url endpoint used by Cloud Run service
      try {
        final url = Uri.parse('$backendBaseUrl/get-signed-url');
        final response = await http.post(url,
            headers: headers, body: jsonEncode({'path': fileName}));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data.containsKey('url')) {
            return data['url'];
          }
        }
        // If this fails, we'll fall back to the previous endpoint
      } catch (e) {
        _logger.w('Failed with new endpoint, trying fallback: $e');
      }

      // Fall back to previous endpoint format
      final url = Uri.parse(
          '$backendBaseUrl/api/gcs/generate-download-url?filename=${Uri.encodeComponent(fileName)}');
      final response = await http.get(url, headers: headers);
      if (response.statusCode != 200) {
        _logger.e('Failed to get signed download URL: ${response.body}');
        throw Exception('Failed to get signed download URL: ${response.body}');
      }
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        _logger.e('Expected JSON but got: ${response.body}');
        throw Exception('Expected JSON but got: ${response.body}');
      }
      return jsonDecode(response.body)['url'];
    } catch (e, stackTrace) {
      _logger.e('Error getting signed download URL',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> deleteFile({required String fileName}) async {
    try {
      // Get auth headers
      final headers = await _getAuthHeaders();

      final url = Uri.parse('$backendBaseUrl/api/gcs/delete');
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'fileName': fileName}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to delete file: ${response.body}');
      }
    } catch (e, stackTrace) {
      _logger.e('Error deleting file', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
