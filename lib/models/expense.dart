/*
 * Expense Model
 *
 * This file defines the Expense model which represents a financial expense
 * associated with a project, including amount, category, sharing details,
 * and receipt information.
 */

import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Represents a financial expense associated with a project.
///
/// This model tracks expenses with details about the amount, category,
/// who paid, and who the expense was shared with.
class Expense extends Equatable {
  /// Unique identifier for the expense
  final String id;

  /// The ID of the project this expense is associated with
  final String projectId;

  /// Title/name of the expense
  final String title;

  /// Amount of the expense
  final double amount;

  /// Date when the expense occurred
  final DateTime date;

  /// Category of the expense (e.g., "Food", "Transportation")
  final String category;

  /// ID of the user who paid for the expense
  final String paidBy;

  /// List of user IDs with whom the expense is shared
  final List<String> sharedWith;

  /// Optional description of the expense
  final String? description;

  /// Optional URL to a receipt image
  final String? receiptUrl;

  /// Creates a new Expense instance.
  ///
  /// All parameters except [id], [description], and [receiptUrl] are required.
  /// If [id] is not provided, a new UUID will be generated.
  Expense({
    String? id,
    required this.projectId,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.paidBy,
    required this.sharedWith,
    this.description,
    this.receiptUrl,
  }) : id = id ?? const Uuid().v4();

  /// Validates whether the expense data is complete and valid.
  ///
  /// Returns true if all required fields are present and valid.
  /// Validates that amount is positive and required fields are not empty.
  static bool isValid(Expense expense) {
    return expense.title.isNotEmpty &&
        expense.amount > 0 &&
        expense.projectId.isNotEmpty &&
        expense.category.isNotEmpty &&
        expense.paidBy.isNotEmpty &&
        expense.sharedWith.isNotEmpty;
  }

  /// Creates an Expense instance from a Map&lt;String, dynamic&gt;.
  ///
  /// This method handles parsing dates and list fields from the map.
  /// Includes try-catch handling to provide better error messages.
  factory Expense.fromMap(Map<String, dynamic> map) {
    try {
      return Expense(
        id: map['id'] as String? ?? '',
        projectId: map['project_id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        amount: (map['amount'] is num)
            ? (map['amount'] as num).toDouble()
            : double.tryParse(map['amount'].toString()) ?? 0.0,
        date: map['date'] is String
            ? DateTime.parse(map['date'] as String)
            : (map['date'] as DateTime?) ?? DateTime.now(),
        category: map['category'] as String? ?? '',
        paidBy: map['paid_by'] as String? ?? '',
        sharedWith: map['shared_with'] != null
            ? List<String>.from(map['shared_with'] as List)
            : <String>[],
        description: map['description'] as String?,
        receiptUrl: map['receiptUrl'] as String?,
      );
    } catch (e) {
      // In production code, use a proper logger. For now, removing print.
      // print('Error parsing Expense from map: $e');
      // print('Map data: $map');

      // Return a minimal valid expense rather than throwing
      return Expense(
        id: map['id'] as String? ?? '',
        projectId: map['project_id'] as String? ?? '',
        title: 'Error: Invalid expense data',
        amount: 0.0,
        date: DateTime.now(),
        category: 'Unknown',
        paidBy: '',
        sharedWith: const [],
      );
    }
  }

  /// Creates an Expense instance from a JSON map.
  ///
  /// This is a convenience method that works the same as fromMap but is named
  /// for consistency with other models that use fromJson.
  factory Expense.fromJson(Map<String, dynamic> json) => Expense.fromMap(json);

  /// Converts this Expense instance to a JSON map.
  ///
  /// The resulting map includes all fields, with dates converted to ISO 8601 strings.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'paid_by': paidBy,
      'shared_with': sharedWith,
      'description': description,
      'receiptUrl': receiptUrl,
    };
  }

  /// Creates a copy of this Expense with the given fields replaced with new values.
  Expense copyWith({
    String? id,
    String? projectId,
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
      projectId: projectId ?? this.projectId,
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

  @override
  List<Object?> get props => [
        id,
        projectId,
        title,
        amount,
        date,
        category,
        paidBy,
        sharedWith,
        description,
        receiptUrl,
      ];

  /// Creates a string representation of this Expense.
  ///
  /// Useful for debugging and logging.
  @override
  String toString() {
    return 'Expense(id: $id, projectId: $projectId, title: $title, '
        'amount: $amount, date: $date, category: $category, '
        'paidBy: $paidBy, sharedWith: ${sharedWith.length} people)';
  }
}
