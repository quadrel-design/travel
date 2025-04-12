import 'package:flutter/foundation.dart';

@immutable
class User {
  final String id;
  final String email;
  final String name;
  final String? profileImageUrl;
  final List<String> journeyIds;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.profileImageUrl,
    this.journeyIds = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      profileImageUrl: json['profileImageUrl'],
      journeyIds: List<String>.from(json['journeyIds'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'profileImageUrl': profileImageUrl,
      'journeyIds': journeyIds,
    };
  }

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

  @override
  String toString() {
    return 'User(id: $id, email: $email, name: $name, profileImageUrl: $profileImageUrl, journeyIds: $journeyIds)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.email == email &&
        other.name == name &&
        other.profileImageUrl == profileImageUrl &&
        listEquals(other.journeyIds, journeyIds);
  }

  @override
  int get hashCode {
    return id.hashCode ^
        email.hashCode ^
        name.hashCode ^
        profileImageUrl.hashCode ^
        journeyIds.hashCode;
  }
}
