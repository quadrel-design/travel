import 'package:flutter/foundation.dart';

@immutable
class Journey {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String location;
  final DateTime startDate;
  final DateTime endDate;
  final double budget;
  final List<String> imageUrls;
  final bool isCompleted;

  const Journey({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.budget,
    required this.imageUrls,
    this.isCompleted = false,
  });

  factory Journey.fromJson(Map<String, dynamic> json) {
    return Journey(
      id: json['id'],
      userId: json['userId'],
      title: json['title'],
      description: json['description'],
      location: json['location'] ?? '',
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      budget: json['budget'].toDouble(),
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'location': location,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'budget': budget,
      'imageUrls': imageUrls,
      'isCompleted': isCompleted,
    };
  }

  Journey copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? location,
    DateTime? startDate,
    DateTime? endDate,
    double? budget,
    List<String>? imageUrls,
    bool? isCompleted,
  }) {
    return Journey(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budget: budget ?? this.budget,
      imageUrls: imageUrls ?? this.imageUrls,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  String toString() {
    return 'Journey(id: $id, userId: $userId, title: $title, description: $description, location: $location, startDate: $startDate, endDate: $endDate, budget: $budget, imageUrls: $imageUrls, isCompleted: $isCompleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Journey &&
        other.id == id &&
        other.userId == userId &&
        other.title == title &&
        other.description == description &&
        other.location == location &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.budget == budget &&
        listEquals(other.imageUrls, imageUrls) &&
        other.isCompleted == isCompleted;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        title.hashCode ^
        description.hashCode ^
        location.hashCode ^
        startDate.hashCode ^
        endDate.hashCode ^
        budget.hashCode ^
        imageUrls.hashCode ^
        isCompleted.hashCode;
  }
}
