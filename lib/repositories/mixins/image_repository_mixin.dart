import 'dart:convert';
import 'dart:typed_data';
import 'package:travel/models/invoice_image_process.dart';
import 'package:travel/repositories/repository_exceptions.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:mime/mime.dart';
import 'dart:async';
import 'package:eventflux/eventflux.dart';
import 'package:travel/repositories/base_repository_contracts.dart'; // Added package import

// Reuse BaseRepository from project_repository_mixin.dart or define it here if preferred
// For simplicity, let's assume project_repository_mixin.dart is imported and BaseRepository is accessible.
// If not, uncomment and define BaseRepository here:
/*
abstract class BaseRepository {
  Logger get logger;
  String get baseUrl;
  Future<Map<String, String>> getAuthHeaders();
  String getCurrentUserId();
  GcsFileService get gcsFileService; // Added for image operations
  Future<String> getAuthToken(); // Added for getProjectImagesStream
}
*/

// Assuming BaseRepository is defined in or imported alongside project_repository_mixin.dart
// and includes: GcsFileService get gcsFileService; Future<String> getAuthToken();
// For this tool call, I will redefine it to ensure it's self-contained for the edit.

mixin ImageRepositoryOperationsMixin on BaseRepositoryForImages {
  Stream<List<InvoiceImageProcess>> getProjectImagesStream(String projectId) {
    final userId = getCurrentUserId();
    logger.d(
        '[ImageRepositoryOperationsMixin][getProjectImagesStream] START for project ID: $projectId, User ID: $userId');

    final controller = StreamController<List<InvoiceImageProcess>>.broadcast();
    EventFlux? eventFluxInstance;

    Future<void> connectAndListen() async {
      logger.d(
          '[ImageRepositoryOperationsMixin][connectAndListen] START for $projectId');
      try {
        final authToken = await getAuthToken(); // Now uses abstract method
        final Map<String, String> sseHeaders = {
          'Authorization': 'Bearer $authToken',
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
        };

        final sseUrl =
            Uri.parse('$baseUrl/api/projects/$projectId/image-stream');

        logger.d(
            '[ImageRepositoryOperationsMixin][connectAndListen] Connecting to SSE URL: $sseUrl for project $projectId');

        await eventFluxInstance?.disconnect();
        eventFluxInstance = EventFlux.spawn();
        logger.d(
            '[ImageRepositoryOperationsMixin][connectAndListen] EventFlux.spawn() completed for $projectId');

        eventFluxInstance!.connect(
          EventFluxConnectionType.get,
          sseUrl.toString(),
          header: sseHeaders,
          autoReconnect: true,
          reconnectConfig: ReconnectConfig(
            mode: ReconnectMode.linear,
            interval: const Duration(seconds: 5),
            maxAttempts: -1,
            onReconnect: () async {
              logger.i(
                  '[ImageRepositoryOperationsMixin] SSE attempting to reconnect for project $projectId...');
            },
          ),
          onSuccessCallback: (EventFluxResponse? response) {
            logger.i(
                '[ImageRepositoryOperationsMixin][onSuccessCallback] START for project $projectId. Listening for events...');

            if (response == null) {
              logger.w(
                  '[ImageRepositoryOperationsMixin][onSuccessCallback] EventFluxResponse is NULL for $projectId.');
              if (!controller.isClosed) {
                controller.addError(RepositoryException(
                    'SSE connection failed: response was null',
                    null,
                    StackTrace.current));
              }
              return;
            }
            logger.d(
                '[ImageRepositoryOperationsMixin][onSuccessCallback] EventFluxResponse is NOT NULL for $projectId.');

            if (response.stream == null) {
              logger.w(
                  '[ImageRepositoryOperationsMixin][onSuccessCallback] EventFluxResponse.stream is NULL for $projectId.');
              if (!controller.isClosed) {
                controller.addError(RepositoryException(
                    'SSE connection failed: response.stream was null',
                    null,
                    StackTrace.current));
              }
              return;
            }
            logger.d(
                '[ImageRepositoryOperationsMixin][onSuccessCallback] EventFluxResponse.stream is NOT NULL for $projectId. Attaching listener.');

            logger.d(
                '[ImageRepositoryOperationsMixin][onSuccessCallback] ABOUT TO ATTACH LISTENER to response.stream for $projectId');

            response.stream!.listen(
              (eventData) {
                logger.d(
                    '[ImageRepositoryOperationsMixin][stream.listen RAW_EVENT_DATA] Received for $projectId: ${eventData.toString()}');

                logger.d(
                    '[ImageRepositoryOperationsMixin][stream.listen ON_DATA] START for $projectId. Event: ${eventData.event}');
                String dataSnippet = eventData.data ?? "";
                if (dataSnippet.length > 150) {
                  dataSnippet = "${dataSnippet.substring(0, 150)}...";
                }
                logger.d(
                    '[ImageRepositoryOperationsMixin][stream.listen ON_DATA] Details for $projectId: ID=${eventData.id}, Data=$dataSnippet');

                if (eventData.event == 'imagesUpdated') {
                  logger.d(
                      '[ImageRepositoryOperationsMixin][stream.listen ON_DATA] \'imagesUpdated\' event identified for $projectId.');
                  try {
                    final List<dynamic> decodedData =
                        json.decode(eventData.data);
                    logger.d(
                        '[ImageRepositoryOperationsMixin][stream.listen ON_DATA] Decoded data for $projectId: ${decodedData.length} items.');
                    final images = decodedData
                        .map((jsonItem) => InvoiceImageProcess.fromJson({
                              ...jsonItem as Map<String, dynamic>,
                              'projectId': projectId,
                            }))
                        .toList();
                    if (!controller.isClosed) {
                      logger.d(
                          '[ImageRepositoryOperationsMixin][stream.listen ON_DATA] Adding ${images.length} images to controller for $projectId.');
                      controller.add(images);
                    } else {
                      logger.w(
                          '[ImageRepositoryOperationsMixin][stream.listen ON_DATA] Controller is closed, cannot add images for $projectId.');
                    }
                  } catch (e, stackTrace) {
                    logger.e(
                        '[ImageRepositoryOperationsMixin][stream.listen ON_DATA] Error decoding/processing \'imagesUpdated\' for $projectId:',
                        error: e,
                        stackTrace: stackTrace);
                    if (!controller.isClosed) {
                      controller.addError(RepositoryException(
                          'Error processing SSE data: $e', e, stackTrace));
                    }
                  }
                } else if (eventData.event == 'error') {
                  logger.e(
                      '[ImageRepositoryOperationsMixin][stream.listen ON_DATA] Server-sent \'error\' event for $projectId: ${eventData.data}');
                  if (!controller.isClosed) {
                    controller.addError(DatabaseOperationException(
                        'SSE Server Error for $projectId: ${eventData.data}'));
                  }
                } else if (eventData.event == 'connection_established') {
                  logger.i(
                      '[ImageRepositoryOperationsMixin][stream.listen ON_DATA] \'connection_established\' event received for $projectId.');
                } else {
                  logger.w(
                      '[ImageRepositoryOperationsMixin][stream.listen ON_DATA] Unhandled event type: ${eventData.event} for $projectId');
                }
                logger.d(
                    '[ImageRepositoryOperationsMixin][stream.listen ON_DATA] END for $projectId. Event: ${eventData.event}');
              },
              onError: (error, stackTrace) {
                logger.e(
                    '[ImageRepositoryOperationsMixin][stream.listen ON_ERROR] Error for $projectId:',
                    error: error,
                    stackTrace: stackTrace);
                if (!controller.isClosed) {
                  controller.addError(DatabaseOperationException(
                    'SSE Stream Error: $error',
                    error is Exception ? error : null,
                    stackTrace,
                  ));
                }
              },
              onDone: () {
                logger.i(
                    '[ImageRepositoryOperationsMixin][stream.listen ON_DONE] Stream done for $projectId. Auto-reconnect may follow if not intentional.');
              },
              cancelOnError: false,
            );
            logger.d(
                '[ImageRepositoryOperationsMixin][onSuccessCallback] POST-LISTEN to response.stream for $projectId (listener attached)');
          },
          onError: (EventFluxException fluxException) {
            // THIS IS THE BLOCK THAT NEEDS CAREFUL FIXING
            final currentStackTrace = StackTrace.current;
            logger.e(
                '[ImageRepositoryOperationsMixin][eventFlux.onError] Connection error for project $projectId: ${fluxException.message}',
                error: fluxException, // Log the whole exception
                stackTrace: currentStackTrace);
            if (!controller.isClosed) {
              controller.addError(DatabaseOperationException(
                  'SSE Connection Error (eventFlux.onError): ${fluxException.message}',
                  fluxException, // Pass the original exception as the cause
                  currentStackTrace));
            }
          },
        );
        logger.d(
            '[ImageRepositoryOperationsMixin][connectAndListen] eventFluxInstance.connect() called for $projectId');
      } catch (e, stackTrace) {
        logger.e(
            '[ImageRepositoryOperationsMixin][connectAndListen] Outer catch: Failed to initialize SSE setup for project $projectId:',
            error: e,
            stackTrace: stackTrace);
        if (!controller.isClosed) {
          controller.addError(DatabaseOperationException(
            'Failed to set up SSE (outer catch in connectAndListen): $e',
            e is Exception ? e : Exception(e.toString()),
            stackTrace,
          ));
        }
      }
    }

    connectAndListen();

    controller.onCancel = () {
      logger.i(
          '[ImageRepositoryOperationsMixin][controller.onCancel] Cancelling SSE stream for $projectId. Disposing EventFlux instance.');
      eventFluxInstance
          ?.disconnect(); // Ensure await if it becomes async in future eventflux versions
      if (!controller.isClosed) {
        controller.close();
      }
      logger.d(
          '[ImageRepositoryOperationsMixin][controller.onCancel] EventFlux instance disconnected and controller closed for $projectId.');
    };

    logger.d(
        '[ImageRepositoryOperationsMixin][getProjectImagesStream] END for project ID: $projectId. Returning controller.stream.');
    return controller.stream;
  }

  Future<InvoiceImageProcess> uploadInvoiceImage(
      String projectId, Uint8List fileBytes, String fileName) async {
    final userId = getCurrentUserId();

    final String imageFileId =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(fileName)}';

    logger.d(
        '[ImageRepositoryOperationsMixin] uploadInvoiceImage - Original fileName: $fileName');
    logger.d(
        '[ImageRepositoryOperationsMixin] uploadInvoiceImage - p.basename(fileName): ${p.basename(fileName)}');
    logger.d(
        '[ImageRepositoryOperationsMixin] uploadInvoiceImage - Constructed imageFileId: $imageFileId');

    logger.d(
        '[ImageRepositoryOperationsMixin] Uploading image $imageFileId for project $projectId');

    final gcsPath =
        'users/$userId/projects/$projectId/invoice_images/$imageFileId';
    logger.d(
        '[ImageRepositoryOperationsMixin] uploadInvoiceImage - Constructed gcsPath: $gcsPath');

    try {
      logger.d(
          '[ImageRepositoryOperationsMixin] Attempting to upload to GCS at path: $gcsPath');

      await gcsFileService.uploadFile(
        fileBytes: fileBytes,
        fileName: gcsPath,
        contentType: lookupMimeType(fileName) ?? 'application/octet-stream',
      );

      logger.d(
          '[ImageRepositoryOperationsMixin] GCS upload successful for $gcsPath');

      final String fileContentType =
          lookupMimeType(fileName) ?? 'application/octet-stream';
      final int fileSize = fileBytes.length;

      final Map<String, dynamic> requestBody = {
        'id': imageFileId,
        'imagePath': gcsPath,
        'uploaded_at': DateTime.now().toIso8601String(),
        'originalFilename': p.basename(fileName),
        'contentType': fileContentType,
        'size': fileSize
      };

      logger.d(
          '[ImageRepositoryOperationsMixin] Creating image record in DB for project $projectId, image $imageFileId with body: ${json.encode(requestBody)}');

      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/projects/$projectId/images'),
        headers: {...headers},
        body: json.encode(requestBody),
      );

      logger.d(
          '[ImageRepositoryOperationsMixin] Create image record response for $imageFileId: ${response.statusCode}');

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        logger.i(
            '[ImageRepositoryOperationsMixin] Successfully uploaded and created record for image $imageFileId');
        return InvoiceImageProcess.fromJson({
          ...data,
          'projectId': projectId,
        });
      } else {
        logger.e(
            '[ImageRepositoryOperationsMixin] Failed to create image record for $imageFileId: ${response.statusCode} ${response.body}');
        try {
          logger.w(
              '[ImageRepositoryOperationsMixin] Attempting to delete orphaned GCS file: $gcsPath');
          await gcsFileService.deleteFile(fileName: gcsPath);
        } catch (gcsDeleteError) {
          logger.e(
              '[ImageRepositoryOperationsMixin] Failed to delete orphaned GCS file $gcsPath',
              error: gcsDeleteError);
        }
        throw DatabaseOperationException(
          'Failed to create image record for $imageFileId: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }
    } catch (e, stackTrace) {
      logger.e(
          '[ImageRepositoryOperationsMixin] Error uploading image $fileName for project $projectId',
          error: e,
          stackTrace: stackTrace);
      if (e is ImageUploadException ||
          e is DatabaseOperationException ||
          e is ArgumentError ||
          e is NotAuthenticatedException) {
        rethrow;
      }
      throw RepositoryException(
        'Failed to upload image $fileName: $e',
        e,
        stackTrace,
      );
    }
  }

  Future<void> deleteInvoiceImage(String projectId, String imageId) async {
    final userId = getCurrentUserId();
    logger.d(
        '[ImageRepositoryOperationsMixin] Deleting image $imageId from project $projectId by user $userId');

    try {
      final headers = await getAuthHeaders();
      final deleteResponse = await http.delete(
        Uri.parse('$baseUrl/api/projects/$projectId/images/$imageId'),
        headers: headers,
      );

      if (deleteResponse.statusCode != 204) {
        logger.e(
            '[ImageRepositoryOperationsMixin] Error deleting image $imageId from DB: ${deleteResponse.statusCode} ${deleteResponse.body}');
        throw DatabaseOperationException(
          'Failed to delete image record $imageId from DB: HTTP ${deleteResponse.statusCode}',
          deleteResponse.body,
          StackTrace.current,
        );
      }

      logger.d(
          '[ImageRepositoryOperationsMixin] Deleted image $imageId from DB for project $projectId');
    } catch (e, stackTrace) {
      logger.e('[ImageRepositoryOperationsMixin] Error deleting image $imageId',
          error: e, stackTrace: stackTrace);
      if (e is DatabaseOperationException) rethrow;
      throw DatabaseOperationException(
        'Failed to delete image $imageId: $e',
        e,
        stackTrace,
      );
    }
  }

  Future<void> updateImageWithOcrResults(
    String projectId,
    String imageId, {
    bool? isInvoice,
    Map<String, dynamic>? invoiceAnalysis,
    String? status,
    String? ocrText,
  }) async {
    final userId = getCurrentUserId();
    logger.i(
        '[ImageRepositoryOperationsMixin] Updating OCR related fields for image $imageId in project $projectId by user $userId');

    try {
      final Map<String, dynamic> updateData = {
        if (isInvoice != null) 'is_invoice': isInvoice,
        if (invoiceAnalysis != null) 'gemini_analysis_json': invoiceAnalysis,
        if (status != null) 'status': status,
        if (ocrText != null) 'ocr_text': ocrText,
      };

      if (updateData.isEmpty) {
        logger.w(
            '[ImageRepositoryOperationsMixin] No data provided to update OCR results for image $imageId. Skipping call.');
        return;
      }

      logger.d(
          '[ImageRepositoryOperationsMixin] Updating OCR for $imageId with data: ${json.encode(updateData)}');

      final headers = await getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/api/projects/$projectId/images/$imageId/ocr'),
        headers: headers,
        body: json.encode(updateData),
      );

      if (response.statusCode != 200) {
        logger.e(
            '[ImageRepositoryOperationsMixin] Error updating OCR results for $imageId: ${response.statusCode}',
            error: response.body);
        throw DatabaseOperationException(
          'Failed to update OCR results for $imageId: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }

      logger.i(
          '[ImageRepositoryOperationsMixin] Successfully updated OCR results for image $imageId');
    } catch (e, stackTrace) {
      logger.e(
          '[ImageRepositoryOperationsMixin] Error updating OCR results for $imageId',
          error: e,
          stackTrace: stackTrace);
      if (e is DatabaseOperationException) rethrow;
      throw DatabaseOperationException(
        'Failed to update OCR results for $imageId: $e',
        e,
        stackTrace,
      );
    }
  }

  Future<void> updateImageWithAnalysisDetails(
    String projectId,
    String imageId, {
    required Map<String, dynamic> analysisData,
    required bool isInvoiceConfirmed,
    String? status,
    DateTime? invoiceDate,
  }) async {
    final userId = getCurrentUserId();
    logger.i(
        '[ImageRepositoryOperationsMixin] Updating analysis details for image $imageId in project $projectId by user $userId');

    try {
      final Map<String, dynamic> updatePayload = {
        'invoiceAnalysis': analysisData,
        'isInvoiceGuess': isInvoiceConfirmed,
        'status': status ??
            (isInvoiceConfirmed ? 'analysis_complete' : 'manual_review'),
      };

      if (invoiceDate != null) {
        updatePayload['invoiceDate'] = invoiceDate.toIso8601String();
      }

      logger.d(
          '[ImageRepositoryOperationsMixin] Updating analysis for $imageId with payload: ${json.encode(updatePayload)}');

      final headers = await getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/api/projects/$projectId/images/$imageId/analysis'),
        headers: headers,
        body: json.encode(updatePayload),
      );

      if (response.statusCode != 200) {
        logger.e(
            '[ImageRepositoryOperationsMixin] Error updating analysis details for $imageId: ${response.statusCode}',
            error: response.body);
        throw DatabaseOperationException(
          'Failed to update analysis details for $imageId: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }

      logger.i(
          '[ImageRepositoryOperationsMixin] Successfully updated analysis details for image $imageId');
    } catch (e, stackTrace) {
      logger.e(
          '[ImageRepositoryOperationsMixin] Error updating analysis details for $imageId',
          error: e,
          stackTrace: stackTrace);
      if (e is DatabaseOperationException) rethrow;
      throw DatabaseOperationException(
        'Failed to update analysis details for $imageId: $e',
        e,
        stackTrace,
      );
    }
  }
}
