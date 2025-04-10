import 'user.dart';

class Journey {
  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final List<User> users;

  Journey({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    this.users = const [],
  });

  factory Journey.fromJson(Map<String, dynamic> json) {
    try {
      return Journey(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        startDate: DateTime.tryParse(json['start_date'] as String? ?? '') ?? DateTime.now(),
        endDate: DateTime.tryParse(json['end_date'] as String? ?? '') ?? DateTime.now().add(const Duration(days: 7)),
        users: (json['users'] as List?)?.map((user) => User.fromJson(user as Map<String, dynamic>)).toList() ?? [],
      );
    } catch (e) {
      print('Error parsing Journey from JSON: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'users': users.map((user) => user.toJson()).toList(),
    };
  }

  Journey copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    List<User>? users,
  }) {
    return Journey(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      users: users ?? this.users,
    );
  }
} 