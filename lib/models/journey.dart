import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class Journey {
  final String id;
  final String user_id;
  final String title;
  final String description;
  final String location;
  final DateTime start_date;
  final DateTime end_date;
  final double budget;
  final List<String> image_urls;
  final bool is_completed;

  const Journey({
    required this.id,
    required this.user_id,
    required this.title,
    required this.description,
    required this.location,
    required this.start_date,
    required this.end_date,
    required this.budget,
    this.image_urls = const [],
    required this.is_completed,
  });

  factory Journey.fromJson(Map<String, dynamic> json) {
    final imageUrlsList = json['image_urls'];
    final startDateStr = json['start_date'];
    final endDateStr = json['end_date'];

    return Journey(
      id: json['id'] as String,
      user_id: json['user_id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? '',
      start_date: startDateStr != null ? DateTime.parse(startDateStr as String) : DateTime.now(),
      end_date: endDateStr != null ? DateTime.parse(endDateStr as String) : DateTime.now(),
      budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
      image_urls: imageUrlsList is List 
                    ? List<String>.from(imageUrlsList.map((item) => item.toString())) 
                    : [],
      is_completed: json['is_completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'user_id': user_id,
      'title': title,
      'description': description,
      'location': location,
      'start_date': start_date.toIso8601String(),
      'end_date': end_date.toIso8601String(),
      'budget': budget,
      'image_urls': image_urls,
      'is_completed': is_completed,
    };
  }

  Journey copyWith({
    String? id,
    String? user_id,
    String? title,
    String? description,
    String? location,
    DateTime? start_date,
    DateTime? end_date,
    double? budget,
    List<String>? image_urls,
    bool? is_completed,
  }) {
    return Journey(
      id: id ?? this.id,
      user_id: user_id ?? this.user_id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      start_date: start_date ?? this.start_date,
      end_date: end_date ?? this.end_date,
      budget: budget ?? this.budget,
      image_urls: image_urls ?? this.image_urls,
      is_completed: is_completed ?? this.is_completed,
    );
  }

  @override
  String toString() {
    return 'Journey(id: $id, user_id: $user_id, title: $title, description: $description, location: $location, start_date: $start_date, end_date: $end_date, budget: $budget, image_urls: $image_urls, is_completed: $is_completed)';
  }

  @override
  bool operator ==(covariant Journey other) {
    if (identical(this, other)) return true;
  
    return 
      other.id == id &&
      other.user_id == user_id &&
      other.title == title &&
      other.description == description &&
      other.location == location &&
      other.start_date == start_date &&
      other.end_date == end_date &&
      other.budget == budget &&
      listEquals(other.image_urls, image_urls) &&
      other.is_completed == is_completed;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      user_id.hashCode ^
      title.hashCode ^
      description.hashCode ^
      location.hashCode ^
      start_date.hashCode ^
      end_date.hashCode ^
      budget.hashCode ^
      image_urls.hashCode ^
      is_completed.hashCode;
  }
}
