import 'dart:convert';
import 'package:travel/models/project.dart';
import 'package:travel/repositories/repository_exceptions.dart';
import 'package:http/http.dart' as http;
import 'package:travel/repositories/base_repository_contracts.dart';

mixin ProjectRepositoryOperationsMixin on BaseRepository {
  Stream<List<Project>> fetchUserProjects() {
    logger.d('[ProjectRepositoryOperationsMixin] fetchUserProjects called.');
    return Stream.fromFuture(_fetchUserProjectsOnce());
  }

  Future<List<Project>> _fetchUserProjectsOnce() async {
    // Original code starts below
    final userId = getCurrentUserId();
    logger.d(
        '[ProjectRepositoryOperationsMixin] Fetching projects for user: $userId');

    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/projects'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        logger.e(
            '[ProjectRepositoryOperationsMixin] Error fetching user projects: ${response.statusCode}',
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
          '[ProjectRepositoryOperationsMixin] Fetched ${projects.length} projects for user $userId');
      return projects;
    } catch (e, stackTrace) {
      logger.e(
          '[ProjectRepositoryOperationsMixin] Error in _fetchUserProjectsOnce',
          error: e,
          stackTrace: stackTrace);
      if (e is DatabaseFetchException) rethrow;
      throw DatabaseFetchException(
        'Failed to fetch projects: $e',
        e,
        stackTrace,
      );
    }
  }

  Stream<Project?> getProjectStream(String projectId) {
    logger.d(
        '[ProjectRepositoryOperationsMixin] getProjectStream called for project ID: $projectId.');
    return Stream.fromFuture(_getProjectOnce(projectId));
  }

  Future<Project?> _getProjectOnce(String projectId) async {
    final userId = getCurrentUserId();
    logger.d(
        '[ProjectRepositoryOperationsMixin] Fetching single project: $projectId for user $userId');

    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/projects/$projectId'),
        headers: headers,
      );

      if (response.statusCode == 404) {
        logger.w(
            '[ProjectRepositoryOperationsMixin] Project not found: $projectId');
        return null;
      }

      if (response.statusCode != 200) {
        logger.e(
            '[ProjectRepositoryOperationsMixin] Error fetching project $projectId: ${response.statusCode}',
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
          '[ProjectRepositoryOperationsMixin] Fetched project $projectId for user $userId');
      return project;
    } catch (e, stackTrace) {
      logger.e(
          '[ProjectRepositoryOperationsMixin] Error in _getProjectOnce for $projectId',
          error: e,
          stackTrace: stackTrace);
      if (e is DatabaseFetchException) rethrow;
      throw DatabaseFetchException(
        'Failed to fetch project $projectId: $e',
        e,
        stackTrace,
      );
    }
  }

  Future<Project> createProject(String title, String description) async {
    final userId = getCurrentUserId();
    logger.d(
        '[ProjectRepositoryOperationsMixin] Creating project for user: $userId with title: $title');

    try {
      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/projects'),
        headers: headers,
        body: json.encode({
          'title': title,
          'description': description,
        }),
      );

      if (response.statusCode != 201) {
        logger.e(
            '[ProjectRepositoryOperationsMixin] Error creating project: ${response.statusCode}',
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
          '[ProjectRepositoryOperationsMixin] Created project ${project.id} for user $userId');
      return project;
    } catch (e, stackTrace) {
      logger.e('[ProjectRepositoryOperationsMixin] Error creating project',
          error: e, stackTrace: stackTrace);
      if (e is DatabaseOperationException) rethrow;
      throw DatabaseOperationException(
        'Failed to create project: $e',
        e,
        stackTrace,
      );
    }
  }

  Future<Project> addProject(Project project) async {
    final userId = getCurrentUserId();
    logger.d(
        '[ProjectRepositoryOperationsMixin] Adding project "${project.title}" for user: $userId');

    try {
      final headers = await getAuthHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/projects'),
        headers: headers,
        body: json.encode(project.toJson()),
      );

      if (response.statusCode != 201) {
        logger.e(
            '[ProjectRepositoryOperationsMixin] Error adding project: ${response.statusCode}',
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
          '[ProjectRepositoryOperationsMixin] Added project ${createdProject.id} for user $userId');
      return createdProject;
    } catch (e, stackTrace) {
      logger.e('[ProjectRepositoryOperationsMixin] Error adding project',
          error: e, stackTrace: stackTrace);
      if (e is DatabaseOperationException) rethrow;
      throw DatabaseOperationException(
        'Failed to add project: $e',
        e,
        stackTrace,
      );
    }
  }

  Future<void> updateProject(Project project) async {
    final userId = getCurrentUserId();
    final projectId = project.id;
    logger.d(
        '[ProjectRepositoryOperationsMixin] Updating project: $projectId for user $userId');

    try {
      final headers = await getAuthHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/api/projects/$projectId'),
        headers: headers,
        body: json.encode(project.toJson()),
      );

      if (response.statusCode != 200) {
        logger.e(
            '[ProjectRepositoryOperationsMixin] Error updating project $projectId: ${response.statusCode}',
            error: response.body);
        throw DatabaseOperationException(
          'Failed to update project $projectId: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }

      logger.d(
          '[ProjectRepositoryOperationsMixin] Updated project $projectId for user $userId');
    } catch (e, stackTrace) {
      logger.e(
          '[ProjectRepositoryOperationsMixin] Error updating project $projectId',
          error: e,
          stackTrace: stackTrace);
      if (e is DatabaseOperationException) rethrow;
      throw DatabaseOperationException(
        'Failed to update project $projectId: $e',
        e,
        stackTrace,
      );
    }
  }

  Future<void> deleteProject(String projectId) async {
    final userId = getCurrentUserId();
    logger.d(
        '[ProjectRepositoryOperationsMixin] Deleting project: $projectId for user $userId');

    try {
      final headers = await getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/projects/$projectId'),
        headers: headers,
      );

      if (response.statusCode != 204) {
        logger.e(
            '[ProjectRepositoryOperationsMixin] Error deleting project $projectId: ${response.statusCode}',
            error: response.body);
        throw DatabaseOperationException(
          'Failed to delete project $projectId: HTTP ${response.statusCode}',
          response.body,
          StackTrace.current,
        );
      }

      logger.d(
          '[ProjectRepositoryOperationsMixin] Deleted project $projectId for user $userId');
    } catch (e, stackTrace) {
      logger.e(
          '[ProjectRepositoryOperationsMixin] Error deleting project $projectId',
          error: e,
          stackTrace: stackTrace);
      if (e is DatabaseOperationException) rethrow;
      throw DatabaseOperationException(
        'Failed to delete project $projectId: $e',
        e,
        stackTrace,
      );
    }
  }
}
