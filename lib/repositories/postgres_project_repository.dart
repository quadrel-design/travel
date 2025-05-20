import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:logger/logger.dart';
import 'package:travel/models/project.dart';
import 'package:travel/repositories/project_repository.dart';
import 'package:travel/repositories/repository_exceptions.dart';
import 'package:http/http.dart' as http;

class PostgresProjectRepository implements ProjectRepository {
  final firebase_auth.FirebaseAuth _auth;
  final Logger _logger;
  // Assuming GcsFileService is not directly needed for project metadata operations.
  // If it were, it would be passed here.
  final String _baseUrl;

  PostgresProjectRepository(
    this._auth,
    this._logger, {
    String baseUrl = 'https://gcs-backend-213342165039.us-central1.run.app',
  }) : _baseUrl = baseUrl;

  // --- Helper methods copied from PostgresInvoiceImageRepository ---
  // These are needed by the project methods being moved.
  // Consider refactoring these into a shared base class or utility if used by more repositories.

  Logger get logger =>
      _logger; // Added for direct use if any method expects it like this

  String getCurrentUserId() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _logger.w(
        '[PostgresProjectRepo] Attempted to get user ID when no user was authenticated.',
      );
      throw NotAuthenticatedException(
        'User not authenticated. Cannot get user ID.',
      );
    }
    return currentUser.uid;
  }

  Future<String> getAuthToken() async {
    try {
      final token = await _auth.currentUser?.getIdToken(true); // Force refresh
      if (token == null) {
        _logger.e(
          '[PostgresProjectRepo] Failed to get auth token: currentUser or token is null.',
        );
        throw NotAuthenticatedException(
          'Failed to get authentication token: Token is null.',
        );
      }
      return token;
    } catch (e, stackTrace) {
      _logger.e(
        '[PostgresProjectRepo] Error getting auth token',
        error: e,
        stackTrace: stackTrace,
      );
      throw NotAuthenticatedException('Failed to get authentication token: $e');
    }
  }

  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getAuthToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // --- Project-specific methods moved from PostgresInvoiceImageRepository ---

  @override
  Stream<List<Project>> fetchUserProjects() {
    _logger.d('[PostgresProjectRepo] fetchUserProjects called.');
    return Stream.fromFuture(_fetchUserProjectsOnce());
  }

  // Renamed to avoid conflict if it were in the same class with an override
  Future<List<Project>> _fetchUserProjectsOnce() async {
    final userId = getCurrentUserId();
    _logger.d('[PostgresProjectRepo] Fetching projects for user: $userId');

    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/projects'), // Used _baseUrl
        headers: headers,
      );

      if (response.statusCode != 200) {
        _logger.e(
          '[PostgresProjectRepo] Error fetching user projects: ${response.statusCode}',
          error: response.body,
        );
        throw DatabaseFetchException(
          'Failed to fetch projects: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }

      final data = json.decode(response.body) as List<dynamic>;
      final projects = data.map((json) => Project.fromJson(json)).toList();

      _logger.d(
        '[PostgresProjectRepo] Fetched ${projects.length} projects for user $userId',
      );
      return projects;
    } catch (e, stackTrace) {
      _logger.e(
        '[PostgresProjectRepo] Error in _fetchUserProjectsOnce',
        error: e,
        stackTrace: stackTrace,
      );
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
    _logger.d(
      '[PostgresProjectRepo] getProjectStream called for project ID: $projectId.',
    );
    return Stream.fromFuture(_getProjectOnce(projectId));
  }

  // Renamed to avoid conflict
  Future<Project?> _getProjectOnce(String projectId) async {
    final userId = getCurrentUserId();
    _logger.d(
      '[PostgresProjectRepo] Fetching single project: $projectId for user $userId',
    );

    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/projects/$projectId'), // Used _baseUrl
        headers: headers,
      );

      if (response.statusCode == 404) {
        _logger.w('[PostgresProjectRepo] Project not found: $projectId');
        return null;
      }

      if (response.statusCode != 200) {
        _logger.e(
          '[PostgresProjectRepo] Error fetching project $projectId: ${response.statusCode}',
          error: response.body,
        );
        throw DatabaseFetchException(
          'Failed to fetch project $projectId: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }

      final data = json.decode(response.body);
      final project = Project.fromJson(data);

      _logger.d(
        '[PostgresProjectRepo] Fetched project $projectId for user $userId',
      );
      return project;
    } catch (e, stackTrace) {
      _logger.e(
        '[PostgresProjectRepo] Error in _getProjectOnce for $projectId',
        error: e,
        stackTrace: stackTrace,
      );
      if (e is DatabaseFetchException) rethrow;
      throw DatabaseFetchException(
        'Failed to fetch project $projectId: $e',
        e,
        stackTrace,
      );
    }
  }

  @override
  Future<Project> createProject(
    String title, {
    String? description,
    String? location,
    DateTime? startDate,
    DateTime? endDate,
    double? budget,
    bool? isCompleted,
  }) async {
    final userId = getCurrentUserId();
    _logger.d(
      '[PostgresProjectRepo] Creating project for user: $userId with title: $title',
    );

    final Map<String, dynamic> projectData = {
      'title': title,
      'description': description ?? '',
      'location': location ?? '',
      'start_date':
          startDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'end_date':
          endDate?.toIso8601String() ??
          DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      'budget': budget ?? 0.0,
      'is_completed': isCompleted ?? false,
    };

    try {
      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/projects'), // Used _baseUrl
        headers: headers,
        body: json.encode(projectData),
      );

      if (response.statusCode != 201) {
        _logger.e(
          '[PostgresProjectRepo] Error creating project: ${response.statusCode}',
          error: response.body,
        );
        throw DatabaseOperationException(
          'Failed to create project: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }

      final data = json.decode(response.body);
      final project = Project.fromJson(data);

      _logger.d(
        '[PostgresProjectRepo] Created project ${project.id} for user $userId',
      );
      return project;
    } catch (e, stackTrace) {
      _logger.e(
        '[PostgresProjectRepo] Error creating project',
        error: e,
        stackTrace: stackTrace,
      );
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
    _logger.d(
      '[PostgresProjectRepo] Adding project "${project.title}" for user: $userId',
    );

    try {
      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/projects'), // Used _baseUrl
        headers: headers,
        body: json.encode(
          project.toJson(),
        ), // Assumes Project model has toJson()
      );

      if (response.statusCode != 201) {
        _logger.e(
          '[PostgresProjectRepo] Error adding project: ${response.statusCode}',
          error: response.body,
        );
        throw DatabaseOperationException(
          'Failed to add project: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }

      final data = json.decode(response.body);
      final createdProject = Project.fromJson(data);

      _logger.d(
        '[PostgresProjectRepo] Added project ${createdProject.id} for user $userId',
      );
      return createdProject;
    } catch (e, stackTrace) {
      _logger.e(
        '[PostgresProjectRepo] Error adding project',
        error: e,
        stackTrace: stackTrace,
      );
      if (e is DatabaseOperationException) rethrow;
      throw DatabaseOperationException(
        'Failed to add project: $e',
        e,
        stackTrace,
      );
    }
  }

  @override
  Future<Project> updateProject(Project project) async {
    final userId = getCurrentUserId();
    final projectId = project.id;
    _logger.d(
      '[PostgresProjectRepo] Updating project: $projectId for user $userId',
    );

    try {
      final headers = await getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$_baseUrl/api/projects/$projectId'),
        headers: headers,
        body: json.encode(project.toJson()),
      );

      if (response.statusCode != 200) {
        _logger.e(
          '[PostgresProjectRepo] Error updating project $projectId: ${response.statusCode}',
          error: response.body,
        );
        throw DatabaseOperationException(
          'Failed to update project $projectId: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }
      final updatedProjectData = json.decode(response.body);
      final updatedProject = Project.fromJson(updatedProjectData);

      _logger.d(
        '[PostgresProjectRepo] Updated project $projectId for user $userId',
      );
      return updatedProject;
    } catch (e, stackTrace) {
      _logger.e(
        '[PostgresProjectRepo] Error updating project $projectId',
        error: e,
        stackTrace: stackTrace,
      );
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
    _logger.d(
      '[PostgresProjectRepo] Deleting project: $projectId for user $userId',
    );

    try {
      final headers = await getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/projects/$projectId'),
        headers: headers,
      );

      if (response.statusCode != 204) {
        _logger.e(
          '[PostgresProjectRepo] Error deleting project $projectId: ${response.statusCode}',
          error: response.body,
        );
        if (response.statusCode == 404) {
          _logger.w(
            '[PostgresProjectRepo] Project $projectId not found for deletion, or already deleted.',
          );
          return;
        }
        throw DatabaseOperationException(
          'Failed to delete project $projectId: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }

      _logger.d(
        '[PostgresProjectRepo] Deleted project $projectId successfully for user $userId',
      );
    } catch (e, stackTrace) {
      _logger.e(
        '[PostgresProjectRepo] Error deleting project $projectId',
        error: e,
        stackTrace: stackTrace,
      );
      if (e is DatabaseOperationException) rethrow;
      throw DatabaseOperationException(
        'Failed to delete project $projectId: $e',
        e,
        stackTrace,
      );
    }
  }
}
