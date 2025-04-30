enum InvoiceImageStatus {
  uploaded,
  ocrInProgress,
  ocrError,
  ocrNoText,
  ocrFinished,
  analyzeInProgress,
  analyzeError,
  analyzeFinished,
}

extension InvoiceImageStatusX on InvoiceImageStatus {
  String get asString => toString().split('.').last;
  static InvoiceImageStatus fromString(String value) =>
      InvoiceImageStatus.values.firstWhere(
        (e) => e.asString == value,
        orElse: () => InvoiceImageStatus.uploaded,
      );
}
