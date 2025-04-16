import 'package:equatable/equatable.dart';

class JourneyImageInfo extends Equatable {
  final String id;
  final String url;
  final bool? hasPotentialText;
  final String? detectedText;
  final bool isInvoiceGuess;
  final double? detectedTotalAmount;
  final String? detectedCurrency;
  final DateTime? lastProcessedAt;
  final bool scanInitiated;

  final String? localPath;

  const JourneyImageInfo({
    required this.id,
    required this.url,
    this.hasPotentialText,
    this.detectedText,
    this.isInvoiceGuess = false,
    this.detectedTotalAmount,
    this.detectedCurrency,
    this.lastProcessedAt,
    this.scanInitiated = false,
    this.localPath,
  });

  factory JourneyImageInfo.fromMap(Map<String, dynamic> map) {
    num? parseNumeric(dynamic value) {
       if (value is num) return value;
       if (value is String) return num.tryParse(value);
       return null;
    }

    DateTime? parseTimestamp(dynamic value) {
      if (value is String) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return JourneyImageInfo(
      id: map['id'] as String? ?? '',
      url: map['image_url'] as String? ?? '',
      hasPotentialText: map['has_potential_text'] as bool?,
      detectedText: map['detected_text'] as String?,
      isInvoiceGuess: map['is_invoice_guess'] as bool? ?? false,
      detectedTotalAmount: parseNumeric(map['detected_total_amount'])?.toDouble(),
      detectedCurrency: map['detected_currency'] as String?,
      lastProcessedAt: parseTimestamp(map['last_processed_at']),
    );
  }

  JourneyImageInfo copyWith({
    String? id,
    String? url,
    bool? hasPotentialText,
    String? detectedText,
    bool? isInvoiceGuess,
    double? detectedTotalAmount,
    String? detectedCurrency,
    DateTime? lastProcessedAt,
    bool? scanInitiated,
    String? localPath,
    bool setHasPotentialTextNull = false,
    bool setDetectedTextNull = false,
    bool setDetectedTotalAmountNull = false,
    bool setDetectedCurrencyNull = false,
    bool setLastProcessedAtNull = false,
  }) {
    return JourneyImageInfo(
      id: id ?? this.id,
      url: url ?? this.url,
      hasPotentialText: setHasPotentialTextNull ? null : hasPotentialText ?? this.hasPotentialText,
      detectedText: setDetectedTextNull ? null : detectedText ?? this.detectedText,
      isInvoiceGuess: isInvoiceGuess ?? this.isInvoiceGuess,
      detectedTotalAmount: setDetectedTotalAmountNull ? null : detectedTotalAmount ?? this.detectedTotalAmount,
      detectedCurrency: setDetectedCurrencyNull ? null : detectedCurrency ?? this.detectedCurrency,
      lastProcessedAt: setLastProcessedAtNull ? null : lastProcessedAt ?? this.lastProcessedAt,
      scanInitiated: scanInitiated ?? this.scanInitiated,
      localPath: localPath ?? this.localPath,
    );
  }

  @override
  List<Object?> get props => [
        id,
        url,
        hasPotentialText,
        detectedText,
        isInvoiceGuess,
        detectedTotalAmount,
        detectedCurrency,
        lastProcessedAt,
        scanInitiated,
        localPath,
      ];
} 