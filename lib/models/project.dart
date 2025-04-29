/*
 * Project Model
 *
 * This file defines the Project model which represents a travel project with
 * details such as destination, dates, budget, and completion status.
 * It includes serialization methods for JSON and Firestore compatibility.
 */

// import 'dart:convert'; // Unused import
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Represents a travel project with its associated details.
///
/// A Project is the core entity in the travel app, representing a trip with
/// start and end dates, budget information, and other metadata.
@immutable
class Project extends Equatable {
  /// Unique identifier for the project
  final String id;

  /// ID of the user who owns this project
  final String userId;

  /// Title/name of the project
  final String title;

  /// Detailed description of the project
  final String description;

  /// Location/destination of the project
  final String location;

  /// Start date of the project
  final DateTime startDate;

  /// End date of the project
  final DateTime endDate;

  /// Planned budget for the project
  final double budget;

  /// Whether the project has been completed
  final bool isCompleted;

  /// Creates a new Project instance.
  ///
  /// All parameters except [isCompleted] are required.
  const Project({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.budget,
    required this.isCompleted,
  });

  /// Creates a Project instance from a JSON map.
  ///
  /// Handles various edge cases like missing fields and invalid date formats.
  /// Returns a Project with default values for missing or invalid fields.
  factory Project.fromJson(Map<String, dynamic> json) {
    final startDateStr = json['start_date'];
    final endDateStr = json['end_date'];

    // Helper to safely parse dates, providing a fallback
    DateTime parseDate(dynamic dateValue, DateTime fallback) {
      if (dateValue is String) {
        // Use tryParse which returns null on failure instead of throwing
        final parsedDate = DateTime.tryParse(dateValue);
        if (parsedDate == null) {
          // WARNING: Failed to parse date string, using fallback
          // print('WARNING [Project.fromJson]: Failed to parse date string: "$dateValue", using fallback.');
          return fallback;
        }
        return parsedDate;
      }
      // Log if the value is not null and not a string
      if (dateValue != null) {
        // WARNING: Unexpected type for date field, using fallback
        // print('WARNING [Project.fromJson]: Unexpected type for date field: ${dateValue.runtimeType}, value: "$dateValue", using fallback.');
      }
      return fallback;
    }

    return Project(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? '',
      // Use the safe parsing helper
      startDate: parseDate(startDateStr, DateTime.now()),
      endDate: parseDate(endDateStr, DateTime.now()),
      budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }

  /// Converts this Project instance to a JSON map.
  ///
  /// The resulting map uses snake_case keys to match the API/database conventions.
  /// Note that the 'id' field is not included as it's typically managed by the database.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'user_id': userId,
      'title': title,
      'description': description,
      'location': location,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'budget': budget,
      'is_completed': isCompleted,
    };
  }

  /// Creates a copy of this Project with the given fields replaced with new values.
  ///
  /// This is useful for updating a Project without modifying the original instance.
  Project copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? location,
    DateTime? startDate,
    DateTime? endDate,
    double? budget,
    bool? isCompleted,
  }) {
    return Project(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budget: budget ?? this.budget,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        description,
        location,
        startDate,
        endDate,
        budget,
        isCompleted,
      ];

  /// Creates a Project instance from a Map<String, dynamic>.
  ///
  /// This method handles error cases gracefully, returning a default Project
  /// with error indicators if parsing fails.
  ///
  /// Differs from fromJson in that it expects specific formats for certain fields
  /// and provides different defaults.
  factory Project.fromMap(Map<String, dynamic> map) {
    try {
      return Project(
        id: map['id'] ?? '',
        userId: map['user_id'] ?? '',
        title: map['title'] ?? 'Untitled Project',
        description: map['description'] ?? '',
        location: map['location'] ?? 'Unknown',
        startDate: map['start_date'] != null
            ? DateTime.parse(map['start_date'])
            : DateTime.now(),
        endDate: map['end_date'] != null
            ? DateTime.parse(map['end_date'])
            : DateTime.now().add(const Duration(days: 7)),
        budget: (map['budget'] as num?)?.toDouble() ?? 0.0,
        isCompleted: map['is_completed'] ?? false,
      );
    } catch (e) {
      // In case of parsing errors, return a default Project with error indicators
      return Project(
        id: map['id'] ?? '',
        userId: map['user_id'] ?? '',
        title: 'Error Loading Project',
        description: 'Error loading project data.',
        location: 'Unknown',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
        budget: 0.0,
        isCompleted: false,
      );
    }
  }

  /// Creates a string representation of this Project.
  ///
  /// Useful for debugging and logging.
  @override
  String toString() {
    return 'Project(id: $id, title: $title, location: $location, '
        'startDate: $startDate, endDate: $endDate, budget: $budget, '
        'isCompleted: $isCompleted)';
  }
}
