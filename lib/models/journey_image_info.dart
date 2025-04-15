import 'package:equatable/equatable.dart';

class JourneyImageInfo extends Equatable {
  final String id;
  final String url;
  final bool? hasPotentialText;
  final String? detectedText;
  final bool isInvoiceGuess;
  final double? detectedTotalAmount;
  final String? detectedCurrency;

  final String? localPath;

  const JourneyImageInfo({
    required this.id,
    required this.url,
    this.hasPotentialText,
    this.detectedText,
    this.isInvoiceGuess = false,
    this.detectedTotalAmount,
    this.detectedCurrency,
    this.localPath,
  });

  factory JourneyImageInfo.fromMap(Map<String, dynamic> map) {
    num? parseNumeric(dynamic value) {
       if (value is num) return value;
       if (value is String) return num.tryParse(value);
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
        localPath,
      ];
} 