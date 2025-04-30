/*
 * Invoice Capture Process Model
 *
 * This file defines the InvoiceCaptureProcess model which represents an image
 * associated with a project, including its metadata and any extracted information
 * such as text, invoice data, and processing status.
 */

import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
// Remove provider imports if they were added here
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:travel/providers/logging_provider.dart';

/// Represents an image associated with a project and its metadata.
///
/// This model stores information about images including their storage path,
/// extracted data from OCR processing, and status information.
class InvoiceCaptureProcess {
  /// Unique identifier for the image
  final String id;

  /// Public URL for accessing the image
  final String url;

  /// Processing status of the image (e.g., "Ready", "Processing", "NoText", "Text", "Invoice")
  final String status;

  /// Path to the image in storage
  final String imagePath;

  /// Text extracted by OCR, populated after successful detection
  final String? extractedText;

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
  const InvoiceCaptureProcess({
    required this.id,
    required this.url,
    required this.status,
    required this.imagePath,
    this.extractedText,
    this.invoiceAnalysis,
    this.lastProcessedAt,
    this.location,
    this.isInvoiceGuess = false,
    this.uploadedAt,
  });

  /// Creates a InvoiceCaptureProcess instance from a JSON map.
  ///
  /// This method handles Firestore Timestamp objects and safely parses numeric values.
  /// Throws an exception if critical data is missing or malformed, but includes
  /// try-catch handling to provide better error messages.
  factory InvoiceCaptureProcess.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    try {
      return InvoiceCaptureProcess(
        id: json['id'] ?? '',
        url: json['url'] ?? '',
        status: json['status'] ?? '',
        imagePath: json['imagePath'] ?? json['image_path'] ?? '',
        extractedText: json['extractedText'],
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
      'status': status,
      'imagePath': imagePath,
      'extractedText': extractedText,
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
    return 'InvoiceCaptureProcess(id: $id, status: $status, '
        'extractedText: ${extractedText != null})';
  }

  InvoiceCaptureProcess copyWith({
    String? id,
    String? url,
    String? status,
    String? imagePath,
    String? extractedText,
    Map<String, dynamic>? invoiceAnalysis,
    DateTime? lastProcessedAt,
    String? location,
    bool? isInvoiceGuess,
    DateTime? uploadedAt,
  }) {
    return InvoiceCaptureProcess(
      id: id ?? this.id,
      url: url ?? this.url,
      status: status ?? this.status,
      imagePath: imagePath ?? this.imagePath,
      extractedText: extractedText ?? this.extractedText,
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

  InvoiceAnalysis({
    this.totalAmount,
    this.currency,
    this.merchantName,
    this.date,
    this.location,
  });

  factory InvoiceAnalysis.fromJson(Map<String, dynamic> json) {
    return InvoiceAnalysis(
      totalAmount: (json['totalAmount'] is num)
          ? (json['totalAmount'] as num).toDouble()
          : (json['totalAmount'] is String)
              ? double.tryParse(json['totalAmount'])
              : null,
      currency: json['currency'] as String?,
      merchantName: json['merchantName'] as String?,
      date: json['date'] as String?,
      location: json['location'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalAmount': totalAmount,
        'currency': currency,
        'merchantName': merchantName,
        'date': date,
        'location': location,
      };
}
