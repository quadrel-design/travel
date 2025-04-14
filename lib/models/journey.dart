// import 'dart:convert'; // Unused import
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

@immutable
class Journey extends Equatable {
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
    this.imageUrls = const [],
    required this.isCompleted,
  });

  factory Journey.fromJson(Map<String, dynamic> json) {
    final imageUrlsList = json['image_urls'];
    final startDateStr = json['start_date'];
    final endDateStr = json['end_date'];

    return Journey(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? '',
      startDate: startDateStr != null ? DateTime.parse(startDateStr as String) : DateTime.now(),
      endDate: endDateStr != null ? DateTime.parse(endDateStr as String) : DateTime.now(),
      budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
      imageUrls: imageUrlsList is List 
                    ? List<String>.from(imageUrlsList.map((item) => item.toString())) 
                    : [],
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'user_id': userId,
      'title': title,
      'description': description,
      'location': location,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'budget': budget,
      'image_urls': imageUrls,
      'is_completed': isCompleted,
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
  List<Object?> get props => [
        id,
        userId,
        title,
        description,
        location,
        startDate,
        endDate,
        budget,
        imageUrls,
        isCompleted,
      ];
}
