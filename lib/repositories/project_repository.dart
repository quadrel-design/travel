import 'package:travel/models/project.dart';

abstract class ProjectRepository {
  Stream<List<Project>> fetchUserProjects();
  // Consider if _fetchUserProjectsOnce should be public or part of internal contract
  // Future<List<Project>> _fetchUserProjectsOnceInternal();

  Stream<Project?> getProjectStream(String projectId);
  // Consider if _getProjectOnce should be public or part of internal contract
  // Future<Project?> _getProjectOnceInternal(String projectId);

  Future<Project> createProject(
    String title, {
    String? description,
    String? location,
    DateTime? startDate,
    DateTime? endDate,
    double? budget,
    bool? isCompleted,
  });

  Future<Project> addProject(Project project);

  // Placeholder for other project operations that might exist
  Future<Project> updateProject(Project project);
  Future<void> deleteProject(String projectId);
}
