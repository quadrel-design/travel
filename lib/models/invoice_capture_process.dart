/*
 * Invoice Capture Process Model
 *
 * This file defines the InvoiceCaptureProcess model which represents an image
 * associated with a journey, including its metadata and any extracted information
 * such as text, invoice data, and processing status.
 */

import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Remove provider imports if they were added here
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:travel/providers/logging_provider.dart';

/// Represents an image associated with a journey and its metadata.
///
/// This model stores information about images including their storage path,
/// extracted data from OCR processing, and status information.
class InvoiceCaptureProcess extends Equatable {
  /// Unique identifier for the image
  final String id;

  /// Public URL for accessing the image
  final String url;

  /// Storage path of the image in Firebase Storage
  final String imagePath;

  /// Whether the image potentially contains text (from initial assessment)
  final bool? hasPotentialText;

  /// Text extracted from the image via OCR
  final String? detectedText;

  /// Whether the image is suspected to be an invoice based on content
  final bool isInvoiceGuess;

  /// Total amount detected if the image is an invoice
  final double? detectedTotalAmount;

  /// Currency of the detected amount
  final String? detectedCurrency;

  /// When the image was last processed for OCR
  final DateTime? lastProcessedAt;

  /// When the image info was last updated
  final DateTime? updatedAt;

  /// Location associated with the image or detected from the content
  final String? location;

  /// Local path for temporarily storing the image (not persisted)
  final String? localPath;

  /// Processing status of the image (e.g., "Ready", "Processing", "NoText", "Text", "Invoice")
  final String? status;

  /// Creates a new InvoiceCaptureProcess instance.
  const InvoiceCaptureProcess({
    required this.id,
    required this.url,
    required this.imagePath,
    this.hasPotentialText,
    this.detectedText,
    this.isInvoiceGuess = false,
    this.detectedTotalAmount,
    this.detectedCurrency,
    this.lastProcessedAt,
    this.updatedAt,
    this.location,
    this.localPath,
    this.status,
  });

  /// Creates a InvoiceCaptureProcess instance from a JSON map.
  ///
  /// This method handles Firestore Timestamp objects and safely parses numeric values.
  /// Throws an exception if critical data is missing or malformed, but includes
  /// try-catch handling to provide better error messages.
  factory InvoiceCaptureProcess.fromJson(Map<String, dynamic> json) {
    try {
      // Handle Timestamp objects for dates
      DateTime? processLastProcessedAt() {
        if (json['last_processed_at'] == null) return null;

        if (json['last_processed_at'] is Timestamp) {
          return (json['last_processed_at'] as Timestamp).toDate();
        } else if (json['last_processed_at'] is String) {
          return DateTime.parse(json['last_processed_at'] as String);
        }
        return null;
      }

      // Safely parse numeric values
      double? parseAmount() {
        if (json['detected_total_amount'] == null) return null;

        try {
          return double.parse(json['detected_total_amount'].toString());
        } catch (e) {
          return null;
        }
      }

      return InvoiceCaptureProcess(
        id: json['id'] as String? ?? '',
        url: json['url'] as String? ?? '',
        imagePath: json['image_path'] as String? ?? '',
        lastProcessedAt: processLastProcessedAt(),
        detectedText: json['detected_text'] as String?,
        detectedTotalAmount: parseAmount(),
        detectedCurrency: json['detected_currency'] as String?,
        hasPotentialText: json['has_potential_text'] as bool?,
        isInvoiceGuess: json['is_invoice_guess'] as bool? ?? false,
        location: json['location'] as String?,
        status: json['status'] as String?,
      );
    } catch (e, stackTrace) {
      // Log error details - in production, use a proper logger
      print('Error in InvoiceCaptureProcess.fromJson: $e');
      print('JSON that caused error: $json');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Creates a InvoiceCaptureProcess instance from a Map<String, dynamic>.
  ///
  /// This method is similar to fromJson but has different handling for
  /// date fields and expects a slightly different format.
  factory InvoiceCaptureProcess.fromMap(Map<String, dynamic> map) {
    try {
      // Helper to safely parse dates
      DateTime? parseDate(String? dateStr) {
        if (dateStr == null) return null;
        try {
          return DateTime.parse(dateStr);
        } catch (e) {
          return null;
        }
      }

      return InvoiceCaptureProcess(
        id: map['id'] as String? ?? '',
        url: map['url'] as String? ?? '',
        imagePath: map['image_path'] as String? ?? '',
        hasPotentialText: map['has_potential_text'] as bool?,
        detectedText: map['detected_text'] as String?,
        detectedTotalAmount: (map['detected_total_amount'] as num?)?.toDouble(),
        detectedCurrency: map['detected_currency'] as String?,
        isInvoiceGuess: map['is_invoice_guess'] as bool? ?? false,
        location: map['location'] as String?,
        lastProcessedAt: parseDate(map['last_processed_at'] as String?),
        updatedAt: parseDate(map['updated_at'] as String?),
        status: map['status'] as String?,
      );
    } catch (e) {
      print('Error in InvoiceCaptureProcess.fromMap: $e');
      print('Map that caused error: $map');
      // Return a minimal valid object rather than throwing
      return InvoiceCaptureProcess(
        id: map['id'] as String? ?? '',
        url: '',
        imagePath: '',
      );
    }
  }

  /// Converts this InvoiceCaptureProcess instance to a JSON map.
  ///
  /// The resulting map uses snake_case keys to match the database conventions.
  /// Local-only fields like localPath are not included in the output.
  Map<String, dynamic> toJson() {
    return {
      // Use Firestore field names (e.g., snake_case)
      'id': id,
      'url': url,
      'image_path': imagePath,
      'has_potential_text': hasPotentialText,
      'detected_text': detectedText,
      'is_invoice_guess': isInvoiceGuess,
      'detected_total_amount': detectedTotalAmount,
      'detected_currency': detectedCurrency,
      'last_processed_at': lastProcessedAt?.toIso8601String(),
      'location': location,
      'status': status,
      // localPath is typically not saved to Firestore
    };
  }

  /// Creates a copy of this InvoiceCaptureProcess with the given fields replaced with new values.
  ///
  /// This method includes boolean flags to explicitly set fields to null when needed,
  /// which is useful for clearing values during updates.
  InvoiceCaptureProcess copyWith({
    String? id,
    String? url,
    String? imagePath,
    bool? hasPotentialText,
    String? detectedText,
    bool? isInvoiceGuess,
    double? detectedTotalAmount,
    String? detectedCurrency,
    DateTime? lastProcessedAt,
    DateTime? updatedAt,
    String? location,
    String? localPath,
    String? status,
    bool setHasPotentialTextNull = false,
    bool setDetectedTextNull = false,
    bool setDetectedTotalAmountNull = false,
    bool setDetectedCurrencyNull = false,
    bool setLastProcessedAtNull = false,
    bool setUpdatedAtNull = false,
    bool setLocationNull = false,
    bool setStatusNull = false,
  }) {
    return InvoiceCaptureProcess(
      id: id ?? this.id,
      url: url ?? this.url,
      imagePath: imagePath ?? this.imagePath,
      hasPotentialText: setHasPotentialTextNull
          ? null
          : hasPotentialText ?? this.hasPotentialText,
      detectedText:
          setDetectedTextNull ? null : detectedText ?? this.detectedText,
      isInvoiceGuess: isInvoiceGuess ?? this.isInvoiceGuess,
      detectedTotalAmount: setDetectedTotalAmountNull
          ? null
          : detectedTotalAmount ?? this.detectedTotalAmount,
      detectedCurrency: setDetectedCurrencyNull
          ? null
          : detectedCurrency ?? this.detectedCurrency,
      lastProcessedAt: setLastProcessedAtNull
          ? null
          : lastProcessedAt ?? this.lastProcessedAt,
      updatedAt: setUpdatedAtNull ? null : updatedAt ?? this.updatedAt,
      location: setLocationNull ? null : location ?? this.location,
      localPath: localPath ?? this.localPath,
      status: setStatusNull ? null : status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
        id,
        url,
        imagePath,
        hasPotentialText,
        detectedText,
        isInvoiceGuess,
        detectedTotalAmount,
        detectedCurrency,
        lastProcessedAt,
        updatedAt,
        location,
        localPath,
        status,
      ];

  /// Creates a string representation of this InvoiceCaptureProcess.
  ///
  /// Useful for debugging and logging.
  @override
  String toString() {
    return 'InvoiceCaptureProcess(id: $id, status: $status, '
        'isInvoiceGuess: $isInvoiceGuess, '
        'hasAmount: ${detectedTotalAmount != null}, '
        'hasCurrency: ${detectedCurrency != null}, '
        'hasText: ${detectedText != null && detectedText!.isNotEmpty})';
  }
}
