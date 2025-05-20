/*
 * Project Form Provider
 * 
 * This file contains state management for the project creation and editing form.
 * It handles the loading states, error handling, and success states for project
 * CRUD operations.
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel/models/project.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/repositories/repository_exceptions.dart';
import 'package:travel/repositories/invoice_images_repository.dart';

/// State class representing the current state of project form operations.
///
/// This class encapsulates all the state information needed for creating or editing projects,
/// including loading state, error messages, success state, and the project object itself.
class ProjectFormState {
  /// Whether a form submission operation is in progress
  final bool isLoading;

  /// Error message if the operation failed, null otherwise
  final String? error;

  /// Whether the operation completed successfully
  final bool isSuccess;

  /// The project object being created or edited
  final Project? project;

  const ProjectFormState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.project,
  });

  /// Creates a copy of this state with the specified fields replaced with new values.
  ///
  /// The [clearError] and [clearProject] flags can be used to reset those fields to null.
  ProjectFormState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    Project? project,
    bool clearError = false,
    bool clearProject = false,
  }) {
    return ProjectFormState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      isSuccess: isSuccess ?? this.isSuccess,
      project: clearProject ? null : project ?? this.project,
    );
  }
}

/// StateNotifier that manages the project form state and operations.
///
/// Provides methods for creating projects and handling the related state transitions.
/// Consider adding `updateProject` method if form is used for editing.
class ProjectFormNotifier extends StateNotifier<ProjectFormState> {
  final InvoiceImagesRepository _repository;

  ProjectFormNotifier(this._repository) : super(const ProjectFormState());

  /// Creates a new project in the repository.
  ///
  /// Updates the state to reflect loading, error, and success states throughout the process.
  /// Handles various exception types with appropriate error messages.
  Future<void> createProject(Project project) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, clearError: true, isSuccess: false);

    try {
      final createdProject = await _repository.addProject(project);
      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        project: createdProject,
      );
    } on NotAuthenticatedException {
      state = state.copyWith(
        isLoading: false,
        error: 'You must be logged in to create a project',
      );
    } on DatabaseOperationException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to create project: ${e.message}',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  /// Resets the form state to its initial values.
  ///
  /// Useful when navigating away from a form or starting fresh.
  void resetState() {
    state = const ProjectFormState();
  }
}

/// Provider for the project form state and operations.
///
/// This provider creates and maintains a ProjectFormNotifier that manages the state
/// of project creation and editing operations. It uses the projectRepositoryProvider
/// to perform the actual data operations.
///
/// Usage: `final formState = ref.watch(projectFormProvider);`
final projectFormProvider =
    StateNotifierProvider.autoDispose<ProjectFormNotifier, ProjectFormState>(
  (ref) => ProjectFormNotifier(ref.watch(invoiceRepositoryProvider)),
);
