/*
 * User Model
 *
 * This file defines the User model which represents a user of the application,
 * including their authentication information and associated journeys.
 * It includes serialization methods for JSON and Firestore compatibility.
 */

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Represents a user of the application.
///
/// This model stores user information such as authentication details,
/// profile data, and references to their journeys.
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

  /// List of journey IDs associated with this user
  final List<String> journeyIds;

  /// Creates a new User instance.
  ///
  /// The [id], [email], and [name] parameters are required.
  /// [profileImageUrl] is optional and may be null.
  /// [journeyIds] defaults to an empty list if not provided.
  const User({
    required this.id,
    required this.email,
    required this.name,
    this.profileImageUrl,
    this.journeyIds = const [],
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
        profileImageUrl: json['profileImageUrl'] as String?,
        journeyIds: json['journeyIds'] != null
            ? List<String>.from(json['journeyIds'])
            : const [],
      );
    } catch (e) {
      // In production code, use a proper logger
      print('Error parsing User from JSON: $e');
      print('JSON data: $json');

      // Return a basic user with error info rather than throwing
      return User(
        id: json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        name: 'Error: Invalid user data',
        journeyIds: const [],
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
      'profileImageUrl': profileImageUrl,
      'journeyIds': journeyIds,
    };
  }

  /// Creates a copy of this User with the given fields replaced with new values.
  User copyWith({
    String? id,
    String? email,
    String? name,
    String? profileImageUrl,
    List<String>? journeyIds,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      journeyIds: journeyIds ?? this.journeyIds,
    );
  }

  /// Adds a journey ID to the user's list of journeys.
  ///
  /// Returns a new User instance with the updated journey list.
  /// Ensures no duplicate journey IDs are added.
  User addJourney(String journeyId) {
    if (journeyIds.contains(journeyId)) {
      return this;
    }
    return copyWith(journeyIds: [...journeyIds, journeyId]);
  }

  /// Removes a journey ID from the user's list of journeys.
  ///
  /// Returns a new User instance with the updated journey list.
  User removeJourney(String journeyId) {
    return copyWith(
      journeyIds: journeyIds.where((id) => id != journeyId).toList(),
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
    return 'User(id: $id, email: $email, name: $name, profileImageUrl: $profileImageUrl, journeyIds: $journeyIds)';
  }

  @override
  List<Object?> get props => [
        id,
        email,
        name,
        profileImageUrl,
        journeyIds,
      ];
}
