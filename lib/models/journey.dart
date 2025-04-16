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
    required this.isCompleted,
  });

  factory Journey.fromJson(Map<String, dynamic> json) {
    final startDateStr = json['start_date'];
    final endDateStr = json['end_date'];

    // Helper to safely parse dates, providing a fallback
    DateTime _parseDate(dynamic dateValue, DateTime fallback) {
      if (dateValue is String) {
        // Use tryParse which returns null on failure instead of throwing
        final parsedDate = DateTime.tryParse(dateValue);
        if (parsedDate == null) {
           print('WARNING [Journey.fromJson]: Failed to parse date string: "$dateValue", using fallback.');
           return fallback;
        }
        return parsedDate;
      }
      // Log if the value is not null and not a string
      if (dateValue != null) {
          print('WARNING [Journey.fromJson]: Unexpected type for date field: ${dateValue.runtimeType}, value: "$dateValue", using fallback.');
      }
      return fallback;
    }

    return Journey(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? '',
      // Use the safe parsing helper
      startDate: _parseDate(startDateStr, DateTime.now()),
      endDate: _parseDate(endDateStr, DateTime.now()),
      budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
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
}
