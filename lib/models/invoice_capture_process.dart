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

  /// Whether the image is suspected to be an invoice based on content
  final bool isInvoiceGuess;

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
    this.isInvoiceGuess = false,
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

      return InvoiceCaptureProcess(
        id: json['id'] as String? ?? '',
        url: json['url'] as String? ?? '',
        imagePath: json['image_path'] as String? ?? '',
        lastProcessedAt: processLastProcessedAt(),
        isInvoiceGuess: json['is_invoice_guess'] as bool? ?? false,
        location: json['location'] as String?,
        status: json['status'] as String?,
      );
    } catch (e, stackTrace) {
      // Log error details - in production, use a proper logger
      // logger.error('Error in InvoiceCaptureProcess.fromJson', e, stackTrace);
      // logger.debug('JSON that caused error: $json');
      throw Exception('Error parsing InvoiceCaptureProcess from JSON: $e');
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
        isInvoiceGuess: map['is_invoice_guess'] as bool? ?? false,
        location: map['location'] as String?,
        lastProcessedAt: parseDate(map['last_processed_at'] as String?),
        updatedAt: parseDate(map['updated_at'] as String?),
        status: map['status'] as String?,
      );
    } catch (e) {
      // Log error with proper logger in production
      // logger.error('Error in InvoiceCaptureProcess.fromMap', e);
      // logger.debug('Map that caused error: $map');

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
      'is_invoice_guess': isInvoiceGuess,
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
    bool? isInvoiceGuess,
    DateTime? lastProcessedAt,
    DateTime? updatedAt,
    String? location,
    String? localPath,
    String? status,
    bool setLastProcessedAtNull = false,
    bool setUpdatedAtNull = false,
    bool setLocationNull = false,
    bool setStatusNull = false,
  }) {
    return InvoiceCaptureProcess(
      id: id ?? this.id,
      url: url ?? this.url,
      imagePath: imagePath ?? this.imagePath,
      isInvoiceGuess: isInvoiceGuess ?? this.isInvoiceGuess,
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
        isInvoiceGuess,
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
        'location: ${location != null})';
  }
}
