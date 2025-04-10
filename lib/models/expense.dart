class Expense {
  final String id;
  final String journeyId;
  final String title;
  final String description;
  final double amount;
  final DateTime date;
  final String category;

  Expense({
    required this.id,
    required this.journeyId,
    required this.title,
    required this.description,
    required this.amount,
    required this.date,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'journey_id': journeyId,
      'title': title,
      'description': description,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      journeyId: map['journey_id'],
      title: map['title'],
      description: map['description'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      category: map['category'],
    );
  }
} 