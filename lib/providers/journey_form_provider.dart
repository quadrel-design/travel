/*
 * Journey Form Provider
 * 
 * This file contains state management for the journey creation and editing form.
 * It handles the loading states, error handling, and success states for journey
 * CRUD operations.
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel/models/journey.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/repositories/repository_exceptions.dart';
import 'package:travel/repositories/invoice_repository.dart';

/// State class representing the current state of journey form operations.
///
/// This class encapsulates all the state information needed for creating or editing journeys,
/// including loading state, error messages, success state, and the journey object itself.
class JourneyFormState {
  /// Whether a form submission operation is in progress
  final bool isLoading;

  /// Error message if the operation failed, null otherwise
  final String? error;

  /// Whether the operation completed successfully
  final bool isSuccess;

  /// The journey object being created or edited
  final Journey? journey;

  const JourneyFormState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.journey,
  });

  /// Creates a copy of this state with the specified fields replaced with new values.
  ///
  /// The [clearError] and [clearJourney] flags can be used to reset those fields to null.
  JourneyFormState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    Journey? journey,
    bool clearError = false,
    bool clearJourney = false,
  }) {
    return JourneyFormState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      isSuccess: isSuccess ?? this.isSuccess,
      journey: clearJourney ? null : journey ?? this.journey,
    );
  }
}

/// StateNotifier that manages the journey form state and operations.
///
/// Provides methods for creating journeys and handling the related state transitions.
class JourneyFormNotifier extends StateNotifier<JourneyFormState> {
  final JourneyRepository _repository;

  JourneyFormNotifier(this._repository) : super(const JourneyFormState());

  /// Creates a new journey in the repository.
  ///
  /// Updates the state to reflect loading, error, and success states throughout the process.
  /// Handles various exception types with appropriate error messages.
  Future<void> createJourney(Journey journey) async {
    if (state.isLoading) return;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      isSuccess: false,
    );

    try {
      final createdJourney = await _repository.addJourney(journey);
      state = state.copyWith(
        isLoading: false,
        isSuccess: true,
        journey: createdJourney,
      );
    } on NotAuthenticatedException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'You must be logged in to create a journey',
      );
    } on DatabaseOperationException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to create journey: ${e.message}',
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
    state = const JourneyFormState();
  }
}

/// Provider for the journey form state and operations.
///
/// This provider creates and maintains a JourneyFormNotifier that manages the state
/// of journey creation and editing operations. It uses the journeyRepositoryProvider
/// to perform the actual data operations.
///
/// Usage: `final formState = ref.watch(journeyFormProvider);`
final journeyFormProvider =
    StateNotifierProvider.autoDispose<JourneyFormNotifier, JourneyFormState>(
  (ref) {
    final repository = ref.watch(journeyRepositoryProvider);
    return JourneyFormNotifier(repository);
  },
);
