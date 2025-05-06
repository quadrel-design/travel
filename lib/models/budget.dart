import 'package:flutter/foundation.dart';

@immutable
class Budget {
  final String id;
  final String name;
  final double sum;
  final DateTime createdAt;
  final List<String> invoiceIds;

  const Budget({
    required this.id,
    required this.name,
    required this.sum,
    required this.createdAt,
    required this.invoiceIds,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sum': sum,
        'createdAt': createdAt.toIso8601String(),
        'invoiceIds': invoiceIds,
      };

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
        id: json['id'] as String,
        name: json['name'] as String,
        sum: (json['sum'] as num).toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        invoiceIds: (json['invoiceIds'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
      );
}
