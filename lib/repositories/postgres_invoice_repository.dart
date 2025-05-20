import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart'; // For listEquals
import 'package:logger/logger.dart';
import 'package:travel/models/invoice_image_process.dart';
import 'package:travel/models/project.dart';
import 'package:travel/repositories/invoice_images_repository.dart';
import 'package:travel/repositories/repository_exceptions.dart';
import 'package:travel/services/gcs_file_service.dart';
import 'package:travel/repositories/base_repository_contracts.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:travel/repositories/repository_impl_essentials.dart';
import 'package:eventflux/eventflux.dart';

class PostgresInvoiceImageRepository extends RepositoryImplEssentials
    implements InvoiceImagesRepository {
  final firebase_auth.FirebaseAuth _auth;
  final Logger _logger;
  final GcsFileService _gcsFileService;
  final String _baseUrl;

  PostgresInvoiceImageRepository(this._auth, this._logger, this._gcsFileService,
      {String baseUrl = 'https://gcs-backend-213342165039.us-central1.run.app'})
      : _baseUrl = baseUrl;

  // --- Implementation of BaseRepository & BaseRepositoryForImages contract requirements ---
  @override
  Logger get logger => _logger;

  @override
  String get baseUrl => _baseUrl;

  @override
  GcsFileService get gcsFileService => _gcsFileService;

  @override
  String getCurrentUserId() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _logger.w(
          '[PostgresInvoiceRepoCore] Attempted to get user ID when no user was authenticated.');
      throw NotAuthenticatedException(
          'User not authenticated. Cannot get user ID.');
    }
    return currentUser.uid;
  }

  @override
  Future<String> getAuthToken() async {
    try {
      final token = await _auth.currentUser?.getIdToken(true); // Force refresh
      if (token == null) {
        _logger.e(
            '[PostgresInvoiceRepoCore] Failed to get auth token: currentUser or token is null.');
        throw NotAuthenticatedException(
            'Failed to get authentication token: Token is null.');
      }
      return token;
    } catch (e, stackTrace) {
      _logger.e('[PostgresInvoiceRepoCore] Error getting auth token',
          error: e, stackTrace: stackTrace);
      throw NotAuthenticatedException('Failed to get authentication token: $e');
    }
  }

  @override
  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getAuthToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // --- Methods from ProjectRepositoryOperationsMixin ---

  @override
  Stream<List<Project>> fetchUserProjects() {
    logger.d('[PostgresInvoiceRepo] fetchUserProjects called.');
    return Stream.fromFuture(_fetchUserProjectsOnce());
  }

  Future<List<Project>> _fetchUserProjectsOnce() async {
    final userId = getCurrentUserId();
    logger.d('[PostgresInvoiceRepo] Fetching projects for user: $userId');

    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/projects'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        logger.e(
            '[PostgresInvoiceRepo] Error fetching user projects: ${response.statusCode}',
            error: response.body);
        throw DatabaseFetchException(
          'Failed to fetch projects: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }

      final data = json.decode(response.body) as List<dynamic>;
      final projects = data.map((json) => Project.fromJson(json)).toList();

      logger.d(
          '[PostgresInvoiceRepo] Fetched ${projects.length} projects for user $userId');
      return projects;
    } catch (e, stackTrace) {
      logger.e('[PostgresInvoiceRepo] Error in _fetchUserProjectsOnce',
          error: e, stackTrace: stackTrace);
      if (e is DatabaseFetchException) rethrow;
      throw DatabaseFetchException(
        'Failed to fetch projects: $e',
        e,
        stackTrace,
      );
    }
  }

  @override
  Stream<Project?> getProjectStream(String projectId) {
    logger.d(
        '[PostgresInvoiceRepo] getProjectStream called for project ID: $projectId.');
    return Stream.fromFuture(_getProjectOnce(projectId));
  }

  Future<Project?> _getProjectOnce(String projectId) async {
    final userId = getCurrentUserId();
    logger.d(
        '[PostgresInvoiceRepo] Fetching single project: $projectId for user $userId');

    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/projects/$projectId'),
        headers: headers,
      );

      if (response.statusCode == 404) {
        logger.w('[PostgresInvoiceRepo] Project not found: $projectId');
        return null;
      }

      if (response.statusCode != 200) {
        logger.e(
            '[PostgresInvoiceRepo] Error fetching project $projectId: ${response.statusCode}',
            error: response.body);
        throw DatabaseFetchException(
          'Failed to fetch project $projectId: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }

      final data = json.decode(response.body);
      final project = Project.fromJson(data);

      logger.d(
          '[PostgresInvoiceRepo] Fetched project $projectId for user $userId');
      return project;
    } catch (e, stackTrace) {
      logger.e('[PostgresInvoiceRepo] Error in _getProjectOnce for $projectId',
          error: e, stackTrace: stackTrace);
      if (e is DatabaseFetchException) rethrow;
      throw DatabaseFetchException(
        'Failed to fetch project $projectId: $e',
        e,
        stackTrace,
      );
    }
  }

  // Adding createProject to match the interface if it was expected from the mixin.
  // The mixin had `createProject(String title, String description)`
  // The interface InvoiceImagesRepository doesn't explicitly list it, but ProjectRepositoryOperationsMixin did.
  // For now, I'm adding a basic version. This might need adjustment based on exact backend expectations.
  Future<Project> createProject(String title,
      {String? description,
      String? location,
      DateTime? startDate,
      DateTime? endDate,
      double? budget,
      bool? isCompleted}) async {
    final userId = getCurrentUserId();
    logger.d(
        '[PostgresInvoiceRepo] Creating project for user: $userId with title: $title');

    final Map<String, dynamic> projectData = {
      'title': title,
      'description': description ?? '',
      'location': location ?? '',
      'start_date':
          startDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'end_date': endDate?.toIso8601String() ??
          DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      'budget': budget ?? 0.0,
      'is_completed': isCompleted ?? false,
    };

    try {
      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/projects'),
        headers: headers,
        body: json.encode(projectData),
      );

      if (response.statusCode != 201) {
        logger.e(
            '[PostgresInvoiceRepo] Error creating project: ${response.statusCode}',
            error: response.body);
        throw DatabaseOperationException(
          'Failed to create project: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }

      final data = json.decode(response.body);
      final project = Project.fromJson(data);

      logger.d(
          '[PostgresInvoiceRepo] Created project ${project.id} for user $userId');
      return project;
    } catch (e, stackTrace) {
      logger.e('[PostgresInvoiceRepo] Error creating project',
          error: e, stackTrace: stackTrace);
      if (e is DatabaseOperationException) rethrow;
      throw DatabaseOperationException(
        'Failed to create project: $e',
        e,
        stackTrace,
      );
    }
  }

  @override
  Future<Project> addProject(Project project) async {
    final userId = getCurrentUserId();
    logger.d(
        '[PostgresInvoiceRepo] Adding project "${project.title}" for user: $userId');

    try {
      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/projects'),
        headers: headers,
        body:
            json.encode(project.toJson()), // Assumes Project model has toJson()
      );

      if (response.statusCode != 201) {
        logger.e(
            '[PostgresInvoiceRepo] Error adding project: ${response.statusCode}',
            error: response.body);
        throw DatabaseOperationException(
          'Failed to add project: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }

      final data = json.decode(response.body);
      final createdProject = Project.fromJson(data);

      logger.d(
          '[PostgresInvoiceRepo] Added project ${createdProject.id} for user $userId');
      return createdProject;
    } catch (e, stackTrace) {
      logger.e('[PostgresInvoiceRepo] Error adding project',
          error: e, stackTrace: stackTrace);
      if (e is DatabaseOperationException) rethrow;
      throw DatabaseOperationException(
        'Failed to add project: $e',
        e,
        stackTrace,
      );
    }
  }

  @override
  Future<void> updateProject(Project project) async {
    final userId = getCurrentUserId();
    final projectId = project.id;
    logger.d(
        '[PostgresInvoiceRepo] Updating project: $projectId for user $userId');

    try {
      final headers = await getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/api/projects/$projectId'),
        headers: headers,
        body:
            json.encode(project.toJson()), // Assumes Project model has toJson()
      );

      if (response.statusCode != 200) {
        logger.e(
            '[PostgresInvoiceRepo] Error updating project $projectId: ${response.statusCode}',
            error: response.body);
        throw DatabaseOperationException(
          'Failed to update project $projectId: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }

      logger.d(
          '[PostgresInvoiceRepo] Updated project $projectId for user $userId');
    } catch (e, stackTrace) {
      logger.e('[PostgresInvoiceRepo] Error updating project $projectId',
          error: e, stackTrace: stackTrace);
      if (e is DatabaseOperationException) rethrow;
      throw DatabaseOperationException(
        'Failed to update project $projectId: $e',
        e,
        stackTrace,
      );
    }
  }

  @override
  Future<void> deleteProject(String projectId) async {
    final userId = getCurrentUserId();
    logger.d(
        '[PostgresInvoiceRepo] Deleting project: $projectId for user $userId');

    try {
      final headers = await getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/projects/$projectId'),
        headers: headers,
      );

      if (response.statusCode != 204) {
        logger.e(
            '[PostgresInvoiceRepo] Error deleting project $projectId: ${response.statusCode}',
            error: response.body);
        // For DELETE, 404 might mean already deleted or not found, which could be acceptable.
        // However, if it's not 204 (No Content) and not 404, it's likely an issue.
        if (response.statusCode == 404) {
          logger.w(
              '[PostgresInvoiceRepo] Project $projectId not found for deletion, or already deleted.');
          // Depending on desired behavior, you might return or throw a specific exception.
          // For now, just log and consider it "handled" if it's a 404.
          return;
        }
        throw DatabaseOperationException(
          'Failed to delete project $projectId: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }

      logger.d(
          '[PostgresInvoiceRepo] Deleted project $projectId successfully for user $userId');
    } catch (e, stackTrace) {
      logger.e('[PostgresInvoiceRepo] Error deleting project $projectId',
          error: e, stackTrace: stackTrace);
      if (e is DatabaseOperationException) rethrow;
      throw DatabaseOperationException(
        'Failed to delete project $projectId: $e',
        e,
        stackTrace,
      );
    }
  }

  // --- Methods from ImageRepositoryOperationsMixin ---

  @override
  Stream<List<InvoiceImageProcess>> getProjectImagesStream(String projectId) {
    final userId = getCurrentUserId();
    logger.d(
        '[PostgresInvoiceRepo][getProjectImagesStream] START for project ID: $projectId, User ID: $userId');

    final controller = StreamController<List<InvoiceImageProcess>>.broadcast();
    EventFlux? eventFluxInstance;
    StreamSubscription? _currentEventFluxStreamSubscription;
    List<InvoiceImageProcess>? _lastEmittedImagesList;

    // Helper function to process image data
    List<InvoiceImageProcess>? _processImageDataEventHelper(String jsonData,
        List<InvoiceImageProcess>? currentLastEmittedImagesList) {
      _logger.wtf(
          "[[[[[ PROCESS IMAGE DATA EVENT HELPER ENTERED ]]]]] for $projectId. Data: $jsonData"); // VERY PROMINENT LOG

      final trimmedJsonData = jsonData.trim(); // TRIM WHITESPACE
      logger.d(
          "[PostgresInvoiceRepo][_processImageDataEventHelper] Processing data for $projectId: $trimmedJsonData");
      List<InvoiceImageProcess>? newEmittedList;
      try {
        final Map<String, dynamic> eventPayload = json.decode(trimmedJsonData)
            as Map<String, dynamic>; // Use trimmed data
        final List<dynamic> decodedImagesData =
            eventPayload['images'] as List<dynamic>;

        final images = decodedImagesData
            .map((jsonItem) => InvoiceImageProcess.fromJson({
                  ...jsonItem as Map<String, dynamic>,
                  'projectId': projectId,
                }))
            .toList();

        if (!controller.isClosed) {
          logger.d(
              "[PostgresInvoiceRepo][_processImageDataEventHelper] PRE-ADD CHECK for $projectId. New image count: ${images.length}. Last emitted count: ${currentLastEmittedImagesList?.length ?? 'N/A'}");

          bool areListsEqual = false;
          if (currentLastEmittedImagesList != null) {
            logger.d(
                '[EQUATABLE_DEBUG] Comparing new list (count: ${images.length}) with stored list (count: ${currentLastEmittedImagesList.length})');
            if (images.length != currentLastEmittedImagesList.length) {
              logger.d(
                  '[EQUATABLE_DEBUG] Lists have different lengths. They are not equal.');
              areListsEqual = false;
            } else {
              areListsEqual = listEquals(currentLastEmittedImagesList, images);
              if (!areListsEqual) {
                logger.d(
                    '[EQUATABLE_DEBUG] listEquals returned false. Logging element differences:');
                for (int i = 0; i < images.length; i++) {
                  final img1 = currentLastEmittedImagesList[i];
                  final img2 = images[i];
                  if (img1 != img2) {
                    logger.d('[EQUATABLE_DEBUG] Difference at index $i:');
                    logger.d(
                        '[EQUATABLE_DEBUG]   Stored: ${img1.props.join(" | ")}');
                    logger.d(
                        '[EQUATABLE_DEBUG]   New   : ${img2.props.join(" | ")}');
                  }
                }
              }
            }
          } else {
            logger.d(
                '[EQUATABLE_DEBUG] _lastEmittedImagesList is null. Lists are considered different.');
            areListsEqual = false; // First list is always new
          }
          logger.d(
              '[EQUATABLE_DEBUG] Final result of listEquals check (areListsEqual variable): $areListsEqual');

          if (!areListsEqual) {
            logger.i(
                "[PostgresInvoiceRepo][_processImageDataEventHelper] Image list is NEW or DIFFERENT for $projectId. Emitting ${images.length} images.");
            newEmittedList = List.from(images);
            _logger.wtf("[[[[[ BEFORE CONTROLLER.ADD for $projectId ]]]]]");
            controller.add(newEmittedList);
            _logger.wtf("[[[[[ AFTER CONTROLLER.ADD for $projectId ]]]]]");
          } else {
            logger.i(
                "[PostgresInvoiceRepo][_processImageDataEventHelper] Image list is IDENTICAL to last emitted for $projectId. Suppressing emission. Count: ${images.length}");
          }
        }
        // This is where _lastEmittedImagesList was updated in the stream listener logic
        // Let's ensure it happens correctly if a new list was emitted.
        // The calling code in the stream listener will now assign the result of this function to _lastEmittedImagesList
        // if newEmittedList is not null.
        if (newEmittedList != null) {
          _logger.wtf(
              "[[[[[ RETURNING NEWLY PROCESSED LIST from _processImageDataEventHelper for $projectId ]]]]]");
        } else {
          _logger.wtf(
              "[[[[[ RETURNING NULL (no new list processed/emitted) from _processImageDataEventHelper for $projectId ]]]]]");
        }
        return newEmittedList; // Return the list that was added, or null if no new list was added
      } catch (e, stackTrace) {
        logger.e(
            "[PostgresInvoiceRepo][_processImageDataEventHelper] Error decoding/processing image data for $projectId (data: '$trimmedJsonData'):",
            error: e,
            stackTrace: stackTrace);
        if (!controller.isClosed) {
          controller.addError(RepositoryException(
              'Error processing SSE data: $e', e, stackTrace));
        }
        return null;
      }
    }

    Future<void> connectAndListen() async {
      if (_logger == null) {
        print(
            "CRITICAL_ERROR: _logger IS NULL IN connectAndListen for $projectId");
        return;
      }
      _logger.d('[PostgresInvoiceRepo][connectAndListen] START for $projectId');

      try {
        final authToken = await getAuthToken();
        final Map<String, String> sseHeaders = {
          'Authorization': 'Bearer $authToken',
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
        };
        final sseUrlString =
            '$_baseUrl/api/projects/$projectId/image-stream'; // Use _baseUrl
        final sseUrl = Uri.parse(sseUrlString);

        _logger.d(
            '[PostgresInvoiceRepo][connectAndListen] Target SSE URL: $sseUrlString');

        // BASIC HTTP GET TEST (before EventFlux)
        try {
          _logger.i(
              '[PostgresInvoiceRepo][connectAndListen] Attempting BASIC HTTP GET to: $sseUrlString');
          final http.Response httpGetResponse =
              await http.get(sseUrl, headers: {
            'Authorization': 'Bearer $authToken',
            'Accept':
                'text/event-stream', // Still request event-stream to mimic SSE negotiation
            'Cache-Control': 'no-cache',
          }).timeout(const Duration(seconds: 10));
          _logger.i(
              '[PostgresInvoiceRepo][connectAndListen] BASIC HTTP GET completed. Status: ${httpGetResponse.statusCode}');
          if (httpGetResponse.statusCode == 200) {
            _logger.i(
                '[PostgresInvoiceRepo][connectAndListen] BASIC HTTP GET Headers: ${httpGetResponse.headers}');
            _logger.i(
                '[PostgresInvoiceRepo][connectAndListen] BASIC HTTP GET Body (first 100 chars): ${httpGetResponse.body.substring(0, (httpGetResponse.body.length < 100 ? httpGetResponse.body.length : 100))}');
          } else {
            _logger.w(
                '[PostgresInvoiceRepo][connectAndListen] BASIC HTTP GET failed or non-200. Body: ${httpGetResponse.body}');
          }
        } catch (e, stackTrace) {
          _logger.e(
              '[PostgresInvoiceRepo][connectAndListen] BASIC HTTP GET FAILED:',
              error: e,
              stackTrace: stackTrace);
        }
        // END OF BASIC HTTP GET TEST

        await eventFluxInstance?.disconnect();
        await _currentEventFluxStreamSubscription?.cancel();
        _currentEventFluxStreamSubscription = null;

        eventFluxInstance = EventFlux.spawn();

        eventFluxInstance!.connect(
          EventFluxConnectionType.get,
          sseUrlString, // Use original sseUrlString
          header: sseHeaders, // Use original sseHeaders
          autoReconnect: true,
          reconnectConfig: ReconnectConfig(
            mode: ReconnectMode.linear,
            interval: const Duration(seconds: 5),
            maxAttempts: -1,
            onReconnect: () async {
              logger.i(
                  '[PostgresInvoiceRepo] SSE attempting to reconnect for project $projectId...');
              await _currentEventFluxStreamSubscription?.cancel();
              _currentEventFluxStreamSubscription = null;
            },
          ),
          onSuccessCallback: (EventFluxResponse? response) {
            logger.i(
                '[PostgresInvoiceRepo][onSuccessCallback] STEP 1: Entered onSuccessCallback for project $projectId.');

            _currentEventFluxStreamSubscription?.cancel();
            _currentEventFluxStreamSubscription = null;

            logger.d(
                '[PostgresInvoiceRepo][onSuccessCallback] STEP 2: Checking response object for $projectId.');
            if (response == null || response.stream == null) {
              logger.w(
                  '[PostgresInvoiceRepo][onSuccessCallback] STEP 2.1 (FAILURE): EventFluxResponse or its stream is NULL for $projectId.');
              if (!controller.isClosed) {
                controller.addError(RepositoryException(
                    'SSE connection failed: response or stream was null',
                    null,
                    StackTrace.current));
              }
              return;
            }

            logger.d(
                '[PostgresInvoiceRepo][onSuccessCallback] STEP 3: Response and stream are valid for $projectId. Setting up NEW listener.');
            _currentEventFluxStreamSubscription = response.stream!.listen(
              (eventData) {
                // Robust RAW Event Logging
                final String rawEvent = eventData.event ?? 'NULL_EVENT_TYPE';
                final String rawData = eventData.data ?? 'NULL_DATA_PAYLOAD';
                _logger.i(
                    "[PostgresInvoiceRepo][RawSSE] Event: '$rawEvent', Data: '$rawData'"); // Simplified WTF to INFO

                final eventType = eventData.event?.trim() ?? '';
                final dataPayload = eventData.data?.trim() ?? '';

                logger.d(
                    '[PostgresInvoiceRepo][stream.listen ON_DATA] Received eventData for $projectId. Event: "$eventType", Data: "$dataPayload"');

                if (eventType == 'imagesUpdated' ||
                    eventType == 'initialImages' ||
                    eventType == 'message') {
                  logger.d(
                      "[PostgresInvoiceRepo][stream.listen ON_DATA] Explicit data event ('$eventType') identified for $projectId.");
                  final processedList = _processImageDataEventHelper(
                      dataPayload, _lastEmittedImagesList);
                  if (processedList != null) {
                    _lastEmittedImagesList = processedList;
                  }
                } else if (eventType.isEmpty && dataPayload.isNotEmpty) {
                  logger.i(
                      "[PostgresInvoiceRepo][stream.listen ON_DATA] Event with empty type BUT NON-EMPTY DATA for $projectId. Processing as image data. EventType: '$eventType', Data: \"$dataPayload\"");
                  final processedList = _processImageDataEventHelper(
                      dataPayload, _lastEmittedImagesList);
                  if (processedList != null) {
                    _lastEmittedImagesList = processedList;
                  }
                } else if (eventType == 'error') {
                  logger.e(
                      "[PostgresInvoiceRepo][stream.listen ON_DATA] Server-sent 'error' event for $projectId: $dataPayload");
                  if (!controller.isClosed) {
                    controller.addError(DatabaseOperationException(
                        'SSE Server Error for $projectId: $dataPayload'));
                  }
                } else if (eventType == 'connection_established') {
                  logger.i(
                      "[PostgresInvoiceRepo][stream.listen ON_DATA] 'connection_established' event received for $projectId.");
                } else if (eventType.isEmpty && dataPayload.isEmpty) {
                  logger.i(
                      '[PostgresInvoiceRepo][stream.listen ON_DATA] Received event with empty type and empty data for $projectId (likely keep-alive or comment). Data: "$dataPayload". Ignoring.');
                } else {
                  logger.w(
                      '[PostgresInvoiceRepo][stream.listen ON_DATA] Unhandled event type: "$eventType" for $projectId. Data: "$dataPayload"');
                }
              },
              onError: (error, stackTrace) {
                logger.e(
                    '[PostgresInvoiceRepo][stream.listen ON_ERROR] STEP 5 (ERROR): Stream error for $projectId:',
                    error: error,
                    stackTrace: stackTrace);
                if (!controller.isClosed) {
                  controller.addError(DatabaseOperationException(
                      'SSE Stream Error: $error',
                      error is Exception ? error : null,
                      stackTrace));
                }
              },
              onDone: () {
                logger.i(
                    '[PostgresInvoiceRepo][stream.listen ON_DONE] STEP 6 (DONE): Stream done for $projectId. Auto-reconnect may follow if not intentional.');
              },
              cancelOnError: false,
            );
            logger.d(
                '[PostgresInvoiceRepo][onSuccessCallback] STEP 7: Listener setup complete for $projectId.');
          },
          onError: (EventFluxException fluxException) {
            final currentStackTrace = StackTrace.current;
            logger.e(
                '[PostgresInvoiceRepo][eventFlux.onError] Connection error for project $projectId: ${fluxException.message}',
                error: fluxException,
                stackTrace: currentStackTrace);
            if (!controller.isClosed) {
              controller.addError(DatabaseOperationException(
                  'SSE Connection Error (eventFlux.onError): ${fluxException.message}',
                  fluxException,
                  currentStackTrace));
            }
          },
        );
      } catch (e, stackTrace) {
        logger.e(
            '[PostgresInvoiceRepo][connectAndListen] Outer catch: Failed to initialize SSE setup for project $projectId:',
            error: e,
            stackTrace: stackTrace);
        if (!controller.isClosed) {
          controller.addError(DatabaseOperationException(
              'Failed to set up SSE (outer catch in connectAndListen): $e',
              e is Exception ? e : Exception(e.toString()),
              stackTrace));
        }
      }
    }

    // Call connectAndListen and handle its potential immediate error
    connectAndListen().catchError((e, stackTrace) {
      _logger.wtf(
          "[[[[[ connectAndListen() Future FAILED for $projectId: $e ]]]]]",
          error: e,
          stackTrace: stackTrace);
    });

    controller.onCancel = () {
      logger.i(
          '[PostgresInvoiceRepo][controller.onCancel] Cancelling SSE stream for $projectId. Disposing EventFlux instance and stream subscription.');
      _currentEventFluxStreamSubscription?.cancel();
      _currentEventFluxStreamSubscription = null;
      eventFluxInstance?.disconnect();
      if (!controller.isClosed) {
        controller.close();
      }
    };
    return controller.stream;
  }

  @override
  Future<InvoiceImageProcess> uploadInvoiceImage(
      String projectId, Uint8List fileBytes, String fileName) async {
    final userId = getCurrentUserId();

    String baseNameForId = p.basenameWithoutExtension(fileName);
    if (baseNameForId.isEmpty)
      baseNameForId = 'image_${DateTime.now().millisecondsSinceEpoch}';

    final String imageFileId =
        '${DateTime.now().millisecondsSinceEpoch}_$baseNameForId';
    final String extension = p.extension(fileName).toLowerCase();

    logger.d(
        '[PostgresInvoiceRepo] Uploading image. Original: $fileName, ID for GCS: $imageFileId, Extension: $extension');

    final gcsPath =
        'users/$userId/projects/$projectId/invoice_images/$imageFileId$extension';

    try {
      logger.d(
          '[PostgresInvoiceRepo] Attempting to upload to GCS at path: $gcsPath');

      await _gcsFileService.uploadFile(
        fileBytes: fileBytes,
        fileName: gcsPath,
        contentType: lookupMimeType(fileName) ?? 'application/octet-stream',
      );

      logger.d('[PostgresInvoiceRepo] GCS upload successful for $gcsPath');

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
          '[PostgresInvoiceRepo] Creating image record in DB with body: ${json.encode(requestBody)}');

      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/projects/$projectId/images'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      logger.d(
          '[PostgresInvoiceRepo] Create image record response: ${response.statusCode}');

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        logger.i(
            '[PostgresInvoiceRepo] Successfully uploaded and created record for image $imageFileId');
        return InvoiceImageProcess.fromJson({
          ...data,
          'projectId': projectId,
        });
      } else {
        logger.e(
            '[PostgresInvoiceRepo] Failed to create image record: ${response.statusCode} ${response.body}');
        try {
          logger.w(
              '[PostgresInvoiceRepo] Attempting to delete orphaned GCS file: $gcsPath');
          await _gcsFileService.deleteFile(fileName: gcsPath);
        } catch (gcsDeleteError) {
          logger.e(
              '[PostgresInvoiceRepo] Failed to delete orphaned GCS file $gcsPath',
              error: gcsDeleteError);
        }
        throw DatabaseOperationException(
          'Failed to create image record: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }
    } catch (e, stackTrace) {
      logger.e(
          '[PostgresInvoiceRepo] Error uploading image $fileName for project $projectId',
          error: e,
          stackTrace: stackTrace);
      if (e is ImageUploadException ||
          e is DatabaseOperationException ||
          e is ArgumentError) {
        rethrow;
      }
      throw RepositoryException(
        'Failed to upload image $fileName: $e',
        e,
        stackTrace,
      );
    }
  }

  @override
  Future<void> deleteInvoiceImage(String projectId, String imageId) async {
    final userId = getCurrentUserId();
    logger.d(
        '[PostgresInvoiceRepo] Deleting image $imageId from project $projectId by user $userId');

    try {
      final headers = await getAuthHeaders();
      final deleteResponse = await http.delete(
        Uri.parse('$baseUrl/api/projects/$projectId/images/$imageId'),
        headers: headers,
      );

      if (deleteResponse.statusCode != 204) {
        logger.e(
            '[PostgresInvoiceRepo] Error deleting image $imageId from DB: ${deleteResponse.statusCode} ${deleteResponse.body}');
        if (deleteResponse.statusCode == 404) {
          logger.w(
              '[PostgresInvoiceRepo] Image $imageId not found for deletion, or already deleted.');
          return; // Or throw a specific "NotFound" exception if the caller needs to know
        }
        throw DatabaseOperationException(
          'Failed to delete image record $imageId from DB: HTTP ${deleteResponse.statusCode}',
          deleteResponse.body,
          StackTrace.current,
        );
      }
      logger.d(
          '[PostgresInvoiceRepo] Deleted image $imageId from DB for project $projectId');
    } catch (e, stackTrace) {
      logger.e('[PostgresInvoiceRepo] Error deleting image $imageId',
          error: e, stackTrace: stackTrace);
      if (e is DatabaseOperationException) rethrow;
      throw DatabaseOperationException(
        'Failed to delete image $imageId: $e',
        e,
        stackTrace,
      );
    }
  }

  @override
  Future<void> updateImageWithOcrResults(
    String projectId,
    String imageId, {
    bool? isInvoice,
    Map<String, dynamic>? invoiceAnalysis,
  }) async {
    logger.i(
        '[PostgresInvoiceRepo] Updating OCR related fields for image $imageId in project $projectId');

    try {
      final Map<String, dynamic> updateData = {
        if (isInvoice != null) 'is_invoice': isInvoice,
        if (invoiceAnalysis != null) 'gemini_analysis_json': invoiceAnalysis,
      };

      if (updateData.isEmpty) {
        logger.w(
            '[PostgresInvoiceRepo] No data provided to update OCR results for image $imageId. Skipping call.');
        return;
      }

      logger.d(
          '[PostgresInvoiceRepo] Updating OCR for $imageId with data: ${json.encode(updateData)}');

      final headers = await getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/api/projects/$projectId/images/$imageId/ocr'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: json.encode(updateData),
      );

      if (response.statusCode != 200) {
        logger.e(
            '[PostgresInvoiceRepo] Error updating OCR results for $imageId: ${response.statusCode}',
            error: response.body);
        throw DatabaseOperationException(
          'Failed to update OCR results for $imageId: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }
      logger.i(
          '[PostgresInvoiceRepo] Successfully updated OCR results for image $imageId');
    } catch (e, stackTrace) {
      logger.e('[PostgresInvoiceRepo] Error updating OCR results for $imageId',
          error: e, stackTrace: stackTrace);
      if (e is DatabaseOperationException) rethrow;
      throw DatabaseOperationException(
        'Failed to update OCR results for $imageId: $e',
        e,
        stackTrace,
      );
    }
  }

  @override
  Future<void> updateImageWithAnalysisDetails(
    String projectId,
    String imageId, {
    required Map<String, dynamic> analysisData,
    required bool isInvoiceConfirmed,
    String? status,
  }) async {
    logger.i(
        '[PostgresInvoiceRepo] Updating analysis details for image $imageId in project $projectId');

    try {
      final Map<String, dynamic> updatePayload = {
        'invoiceAnalysis': analysisData,
        'isInvoiceGuess': isInvoiceConfirmed,
        'status': status ??
            (isInvoiceConfirmed ? 'analysis_complete' : 'manual_review'),
      };

      logger.d(
          '[PostgresInvoiceRepo] Updating analysis for $imageId with payload: ${json.encode(updatePayload)}');

      final headers = await getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/api/projects/$projectId/images/$imageId/analysis'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: json.encode(updatePayload),
      );

      if (response.statusCode != 200) {
        logger.e(
            '[PostgresInvoiceRepo] Error updating analysis details for $imageId: ${response.statusCode}',
            error: response.body);
        throw DatabaseOperationException(
          'Failed to update analysis details for $imageId: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }
      logger.i(
          '[PostgresInvoiceRepo] Successfully updated analysis details for image $imageId');
    } catch (e, stackTrace) {
      logger.e(
          '[PostgresInvoiceRepo] Error updating analysis details for $imageId',
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
