/*
 * Invoice Capture Process Model
 *
 * This file defines the InvoiceCaptureProcess model which represents an image
 * associated with a project, including its metadata and any extracted information
 * such as text, invoice data, and processing status.
 */

// import 'package:cloud_firestore/cloud_firestore.dart'; // Removed this import
// Remove provider imports if they were added here
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:travel/providers/logging_provider.dart';
import 'package:equatable/equatable.dart';

/// Represents an image associated with a project and its metadata.
///
/// This model stores information about images including their storage path,
/// extracted data from OCR processing, and status information.
class InvoiceImageProcess extends Equatable {
  /// Unique identifier for the image
  final String id;

  /// Public URL for accessing the image
  final String url;

  /// Path to the image in storage
  final String imagePath;

  /// ID of the invoice this image belongs to
  final String invoiceId;

  /// Text extracted by OCR, populated after successful detection
  final String? ocrText;

  /// Structured analysis result from Gemini (if available)
  final Map<String, dynamic>? invoiceAnalysis;

  /// Last processed date
  final DateTime? lastProcessedAt;

  /// Location associated with the image
  final String? location;

  /// Whether the image is a guess for an invoice
  final bool isInvoiceGuess;

  /// Uploaded date
  final DateTime? uploadedAt;

  /// Creates a new InvoiceCaptureProcess instance.
  const InvoiceImageProcess({
    required this.id,
    required this.url,
    required this.imagePath,
    required this.invoiceId,
    this.ocrText,
    this.invoiceAnalysis,
    this.lastProcessedAt,
    this.location,
    this.isInvoiceGuess = false,
    this.uploadedAt,
  });

  @override
  List<Object?> get props => [
        id,
        url,
        imagePath,
        invoiceId,
        ocrText,
        invoiceAnalysis,
        lastProcessedAt,
        location,
        isInvoiceGuess,
        uploadedAt,
      ];

  /// Creates a InvoiceCaptureProcess instance from a JSON map.
  ///
  /// This method handles Firestore Timestamp objects and safely parses numeric values.
  /// Throws an exception if critical data is missing or malformed, but includes
  /// try-catch handling to provide better error messages.
  factory InvoiceImageProcess.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    try {
      return InvoiceImageProcess(
        id: json['id'] ?? '',
        url: json['url'] ?? '',
        imagePath: json['imagePath'] ?? json['image_path'] ?? '',
        invoiceId: json['id'] ?? '',
        ocrText: json['ocrText'],
        invoiceAnalysis: json['invoiceAnalysis'],
        lastProcessedAt: parseDate(json['lastProcessedAt']),
        location: json['location'],
        isInvoiceGuess:
            json['isInvoiceGuess'] ?? json['is_invoice_guess'] ?? false,
        uploadedAt: parseDate(json['uploadedAt']),
      );
    } catch (e) {
      // Log error details - in production, use a proper logger
      // logger.error('Error in InvoiceCaptureProcess.fromJson', e, stackTrace);
      // logger.debug('JSON that caused error: $json');
      throw Exception('Error parsing InvoiceCaptureProcess from JSON: $e');
    }
  }

  /// Converts this InvoiceCaptureProcess instance to a JSON map.
  ///
  /// The resulting map uses snake_case keys to match the database conventions.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'imagePath': imagePath,
      'invoiceId': invoiceId,
      'ocrText': ocrText,
      'invoiceAnalysis': invoiceAnalysis,
      'lastProcessedAt': lastProcessedAt?.toIso8601String(),
      'location': location,
      'isInvoiceGuess': isInvoiceGuess,
      'uploadedAt': uploadedAt?.toIso8601String(),
    };
  }

  /// Creates a string representation of this InvoiceCaptureProcess.
  ///
  /// Useful for debugging and logging.
  @override
  String toString() {
    return 'InvoiceCaptureProcess(id: $id, invoiceId: $invoiceId, ocrText: ${ocrText != null})';
  }

  InvoiceImageProcess copyWith({
    String? id,
    String? url,
    String? imagePath,
    String? invoiceId,
    String? ocrText,
    Map<String, dynamic>? invoiceAnalysis,
    DateTime? lastProcessedAt,
    String? location,
    bool? isInvoiceGuess,
    DateTime? uploadedAt,
  }) {
    return InvoiceImageProcess(
      id: id ?? this.id,
      url: url ?? this.url,
      imagePath: imagePath ?? this.imagePath,
      invoiceId: invoiceId ?? this.invoiceId,
      ocrText: ocrText ?? this.ocrText,
      invoiceAnalysis: invoiceAnalysis ?? this.invoiceAnalysis,
      lastProcessedAt: lastProcessedAt ?? this.lastProcessedAt,
      location: location ?? this.location,
      isInvoiceGuess: isInvoiceGuess ?? this.isInvoiceGuess,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }
}

class InvoiceAnalysis {
  final double? totalAmount;
  final String? currency;
  final String? merchantName;
  final String? date;
  final String? location;
  // New fields from Gemini analysis
  final double? taxes;
  final String? category;
  final String? taxonomy;

  InvoiceAnalysis({
    this.totalAmount,
    this.currency,
    this.merchantName,
    this.date,
    this.location,
    this.taxes,
    this.category,
    this.taxonomy,
  });

  factory InvoiceAnalysis.fromJson(Map<String, dynamic> json) {
    // For debugging - use this in production code with proper logging
    print('InvoiceAnalysis.fromJson received: $json');

    // Try to handle different possible structures
    Map<String, dynamic> data = json;

    // If there's an 'invoiceAnalysis' within the JSON, use that
    if (json.containsKey('invoiceAnalysis') &&
        json['invoiceAnalysis'] is Map<String, dynamic>) {
      data = json['invoiceAnalysis'] as Map<String, dynamic>;
    }

    // If there's a 'data' field within the JSON, use that
    if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
      data = json['data'] as Map<String, dynamic>;
    }

    return InvoiceAnalysis(
      totalAmount: _parseNumericValue(data['totalAmount']),
      currency: _parseStringValue(data['currency']),
      merchantName: _parseStringValue(data['merchantName']),
      date: _parseStringValue(data['date']),
      location: _parseStringValue(data['location']),
      // Parse new fields
      taxes: _parseNumericValue(data['taxes']),
      category: _parseStringValue(data['category']),
      taxonomy: _parseStringValue(data['taxonomy']),
    );
  }

  // Helper methods to safely parse various data types
  static double? _parseNumericValue(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.replaceAll(RegExp(r'[^\d.-]'), ''));
      return parsed;
    }
    return null;
  }

  static String? _parseStringValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  Map<String, dynamic> toJson() => {
        'totalAmount': totalAmount,
        'currency': currency,
        'merchantName': merchantName,
        'date': date,
        'location': location,
        'taxes': taxes,
        'category': category,
        'taxonomy': taxonomy,
      };
}
