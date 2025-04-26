/*
 * Invoice Capture Status Model
 *
 * This file defines the InvoiceCaptureStatus enum which represents the various 
 * processing states of journey images, particularly in the invoice capture
 * workflow. It includes conversion methods between app-level statuses and
 * Firebase Function status strings.
 */

/// Enum representing the processing status of a journey image.
///
/// Used to track the current state of image processing in the invoice
/// capture workflow, from initial state through OCR processing and analysis.
enum InvoiceCaptureStatus {
  /// Initial state, ready for processing
  ready,

  /// Processing is in progress
  processing,

  /// No text was detected in the image
  noText,

  /// Text was detected but not identified as an invoice
  text,

  /// Text was detected and identified as an invoice
  invoice,

  /// An error occurred during processing
  error;

  /// Convert the enum to a string that matches the Firebase Function status
  String toFirebaseStatus() {
    switch (this) {
      case InvoiceCaptureStatus.noText:
        return 'NoText';
      case InvoiceCaptureStatus.text:
        return 'Text';
      case InvoiceCaptureStatus.invoice:
        return 'Invoice';
      case InvoiceCaptureStatus.error:
        return 'Error';
      case InvoiceCaptureStatus.ready:
        return 'Ready';
      case InvoiceCaptureStatus.processing:
        return 'Processing';
    }
  }

  /// Create an InvoiceCaptureStatus from a Firebase Function status string
  static InvoiceCaptureStatus fromFirebaseStatus(String? status) {
    switch (status) {
      case 'NoText':
        return InvoiceCaptureStatus.noText;
      case 'Text':
        return InvoiceCaptureStatus.text;
      case 'Invoice':
        return InvoiceCaptureStatus.invoice;
      case 'Error':
        return InvoiceCaptureStatus.error;
      case 'Ready':
        return InvoiceCaptureStatus.ready;
      case 'Processing':
        return InvoiceCaptureStatus.processing;
      default:
        return InvoiceCaptureStatus.ready;
    }
  }

  /// Whether the image can be processed (OCR and analysis)
  bool get isProcessable => this == InvoiceCaptureStatus.ready;

  /// Whether the image is currently being processed
  bool get isInProgress => this == InvoiceCaptureStatus.processing;

  /// Whether the image processing is complete (success or failure)
  bool get isComplete =>
      this == InvoiceCaptureStatus.text ||
      this == InvoiceCaptureStatus.noText ||
      this == InvoiceCaptureStatus.invoice ||
      this == InvoiceCaptureStatus.error;

  /// Whether the image is recognized as an invoice
  bool get isInvoice => this == InvoiceCaptureStatus.invoice;

  /// Whether the image has any recognized text
  bool get hasText =>
      this == InvoiceCaptureStatus.text || this == InvoiceCaptureStatus.invoice;

  /// Whether the image processing failed with an error
  bool get hasError => this == InvoiceCaptureStatus.error;

  /// A user-friendly name for this status
  String get displayName {
    switch (this) {
      case InvoiceCaptureStatus.ready:
        return 'Ready for processing';
      case InvoiceCaptureStatus.processing:
        return 'Processing';
      case InvoiceCaptureStatus.noText:
        return 'No text found';
      case InvoiceCaptureStatus.text:
        return 'Text detected';
      case InvoiceCaptureStatus.invoice:
        return 'Invoice detected';
      case InvoiceCaptureStatus.error:
        return 'Processing error';
    }
  }
}
