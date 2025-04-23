import 'package:equatable/equatable.dart';
// Remove provider imports if they were added here
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:travel/providers/logging_provider.dart';

class JourneyImageInfo extends Equatable {
  final String id;
  final String url;
  final String imagePath;
  final bool? hasPotentialText;
  final String? detectedText;
  final bool isInvoiceGuess;
  final double? detectedTotalAmount;
  final String? detectedCurrency;
  final DateTime? lastProcessedAt;

  final String? localPath;

  const JourneyImageInfo({
    required this.id,
    required this.url,
    required this.imagePath,
    this.hasPotentialText,
    this.detectedText,
    this.isInvoiceGuess = false,
    this.detectedTotalAmount,
    this.detectedCurrency,
    this.lastProcessedAt,
    this.localPath,
  });

  factory JourneyImageInfo.fromJson(Map<String, dynamic> json) {
    try {
      // Comment out debug print statements
      // print('JourneyImageInfo.fromJson called with: $json');

      return JourneyImageInfo(
        id: json['id'] as String,
        url: json['url'] as String,
        imagePath: json['image_path'] as String? ?? '',
        lastProcessedAt: json['last_processed_at'] != null
            ? DateTime.parse(json['last_processed_at'] as String)
            : null,
        detectedText: json['detected_text'] as String?,
        detectedTotalAmount: json['detected_total_amount'] != null
            ? double.parse(json['detected_total_amount'].toString())
            : null,
        detectedCurrency: json['detected_currency'] as String?,
        hasPotentialText: json['has_potential_text'] as bool?,
      );
    } catch (e) {
      // Comment out error print statements
      // print('Error in JourneyImageInfo.fromJson: $e');
      // print('JSON that caused error: $json');
      rethrow; // Still rethrow the error
    }
  }

  factory JourneyImageInfo.fromMap(Map<String, dynamic> map) {
    // Comment out debug print
    // print('JourneyImageInfo.fromMap: $map');
    return JourneyImageInfo(
      id: map['id'] as String? ?? '',
      url: map['image_url'] as String? ?? '',
      imagePath: map['image_path'] as String? ?? '',
      lastProcessedAt: map['last_processed_at'] != null
          ? DateTime.tryParse(map['last_processed_at'] as String? ?? '')
          : null,
      detectedText: map['detected_text'] as String?,
      detectedTotalAmount: map['detected_total_amount'] != null
          ? double.tryParse(map['detected_total_amount'].toString())
          : null,
      detectedCurrency: map['detected_currency'] as String?,
      hasPotentialText: map['has_potential_text'] as bool?,
    );
  }

  JourneyImageInfo copyWith({
    String? id,
    String? url,
    String? imagePath,
    bool? hasPotentialText,
    String? detectedText,
    bool? isInvoiceGuess,
    double? detectedTotalAmount,
    String? detectedCurrency,
    DateTime? lastProcessedAt,
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
      localPath: localPath ?? this.localPath,
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
        localPath,
      ];
}
