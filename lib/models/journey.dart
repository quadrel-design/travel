class Journey {
  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final double budget;

  Journey({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.budget,
  });

  Journey copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    double? budget,
  }) {
    return Journey(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budget: budget ?? this.budget,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'budget': budget,
    };
  }

  factory Journey.fromMap(Map<String, dynamic> map) {
    return Journey(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      startDate: DateTime.parse(map['start_date']),
      endDate: DateTime.parse(map['end_date']),
      budget: map['budget'],
    );
  }
} 