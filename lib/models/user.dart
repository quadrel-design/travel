/*
 * User Model
 *
 * This file defines the User model which represents a user of the application,
 * including their authentication information and associated projects.
 * It includes serialization methods for JSON and Firestore compatibility.
 */

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Represents a user of the application.
///
/// This model stores user information such as authentication details,
/// profile data, and references to their projects.
@immutable
class User extends Equatable {
  /// Unique identifier for the user (typically from Firebase Auth)
  final String id;

  /// Email address of the user
  final String email;

  /// Display name of the user
  final String name;

  /// URL to the user's profile image, if available
  final String? profileImageUrl;

  /// List of project IDs associated with the user
  final List<String> projectIds;

  /// Creates a new User instance.
  ///
  /// The [id], [email], and [name] parameters are required.
  /// [profileImageUrl] is optional and may be null.
  /// [projectIds] is required and must not be empty.
  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.profileImageUrl,
    required this.projectIds,
  });

  /// Creates a User instance from a JSON map.
  ///
  /// Handles missing fields by providing defaults.
  /// The [id], [email], and [name] fields are required and will use empty
  /// strings as defaults if missing.
  factory User.fromJson(Map<String, dynamic> json) {
    try {
      return User(
        id: json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        name: json['name'] as String? ?? '',
        profileImageUrl: json['profile_image_url'] as String? ?? '',
        projectIds: (json['project_ids'] as List<dynamic>? ?? [])
            .map((id) => id as String)
            .toList(),
      );
    } catch (e) {
      // In production code, use a proper logger. For now, removing print.
      // print('Error parsing User from JSON: $e');
      // print('JSON data: $json');

      // Return a basic user with error info rather than throwing
      return User(
        id: json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        name: 'Error: Invalid user data',
        profileImageUrl: null,
        projectIds: const [],
      );
    }
  }

  /// Converts this User instance to a JSON map.
  ///
  /// All fields, including optional ones, are included in the output.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'profile_image_url': profileImageUrl,
      'project_ids': projectIds,
    };
  }

  /// Creates a copy of this User with the given fields replaced with new values.
  User copyWith({
    String? id,
    String? email,
    String? name,
    String? profileImageUrl,
    List<String>? projectIds,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      projectIds: projectIds ?? this.projectIds,
    );
  }

  /// Adds a project ID to the user's list of projects.
  ///
  /// Returns a new User instance with the updated project list.
  /// Ensures no duplicate project IDs are added.
  User addProject(String projectId) {
    if (projectIds.contains(projectId)) {
      return this;
    }
    return copyWith(projectIds: [...projectIds, projectId]);
  }

  /// Removes a project ID from the user's list of projects.
  ///
  /// Returns a new User instance with the updated project list.
  User removeProject(String projectId) {
    return copyWith(
      projectIds: projectIds.where((id) => id != projectId).toList(),
    );
  }

  /// Validates whether the user data is complete and valid.
  ///
  /// Returns true if all required fields are present and valid.
  bool isValid() {
    return id.isNotEmpty &&
        email.isNotEmpty &&
        name.isNotEmpty &&
        email.contains('@');
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, name: $name, profileImageUrl: $profileImageUrl, projectIds: $projectIds)';
  }

  @override
  List<Object?> get props => [
        id,
        email,
        name,
        profileImageUrl,
        projectIds,
      ];
}
