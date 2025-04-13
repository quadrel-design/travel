import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class Expense extends Equatable {
  final String id;
  final String journeyId;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final String paidBy;
  final List<String> sharedWith;
  final String? description;
  final String? receiptUrl;

  Expense({
    String? id,
    required this.journeyId,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.paidBy,
    required this.sharedWith,
    this.description,
    this.receiptUrl,
  }) : id = id ?? const Uuid().v4();

  // Validation method
  static bool isValid(Expense expense) {
    if (expense.title.isEmpty) return false;
    if (expense.amount <= 0) return false;
    if (expense.category.isEmpty) return false;
    if (expense.paidBy.isEmpty) return false;
    if (expense.sharedWith.isEmpty) return false;
    return true;
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      journeyId: map['journeyId'] as String,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      category: map['category'] as String,
      paidBy: map['paidBy'] as String,
      sharedWith: List<String>.from(map['sharedWith'] as List),
      description: map['description'] as String?,
      receiptUrl: map['receiptUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'journeyId': journeyId,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'paidBy': paidBy,
      'sharedWith': sharedWith,
      'description': description,
      'receiptUrl': receiptUrl,
    };
  }

  Expense copyWith({
    String? id,
    String? journeyId,
    String? title,
    double? amount,
    DateTime? date,
    String? category,
    String? paidBy,
    List<String>? sharedWith,
    String? description,
    String? receiptUrl,
  }) {
    return Expense(
      id: id ?? this.id,
      journeyId: journeyId ?? this.journeyId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      paidBy: paidBy ?? this.paidBy,
      sharedWith: sharedWith ?? this.sharedWith,
      description: description ?? this.description,
      receiptUrl: receiptUrl ?? this.receiptUrl,
    );
  }

  // Override props for Equatable
  @override
  List<Object?> get props => [
        id,
        journeyId,
        title,
        amount,
        date,
        category,
        paidBy,
        sharedWith,
        description,
        receiptUrl,
      ];

  // Assuming no manual == or hashCode were present
}
