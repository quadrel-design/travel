import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/journey_image_info.dart';

class ImageStatusChip extends StatelessWidget {
  final JourneyImageInfo imageInfo;

  const ImageStatusChip({super.key, required this.imageInfo});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Determine status and style based on imageInfo
    String label;
    Color backgroundColor;
    Color textColor = Colors.white;

    // --- Revised Status Logic ---
    if (imageInfo.lastProcessedAt == null) {
      // Status: Not Scanned
      label = l10n.imageStatusNotScanned;
      backgroundColor = Colors.blue.shade700;
    } else if (imageInfo.hasPotentialText == false) {
      // Status: Processed, but No Text Found by Vision
      label = l10n.imageStatusNoText;
      backgroundColor = Colors.orange.shade700;
    } else if (imageInfo.detectedTotalAmount != null) {
      // Status: Processed Successfully with Amount
      label = l10n.imageStatusScanned;
      backgroundColor = Colors.green.shade700;
    } else if (imageInfo.isInvoiceGuess == false) {
      // Status: Processed, Text Found, but NOT an Invoice
      label = l10n.imageStatusNoInvoice;
      backgroundColor = Colors.black87;
    } else {
      // Status: Error during processing or Unknown
      label = l10n.imageStatusError;
      backgroundColor = Colors.red;
      // TODO: Maybe add an icon here too?
    }
    // --- End Revised Logic ---

    return Chip(
      label: Text(label),
      labelStyle:
          TextStyle(color: textColor, fontSize: 10), // Smaller font size
      backgroundColor: backgroundColor,
      visualDensity: VisualDensity.compact, // Make chip smaller
      padding: const EdgeInsets.symmetric(
          horizontal: 4, vertical: 0), // Reduce padding
      materialTapTargetSize:
          MaterialTapTargetSize.shrinkWrap, // Reduce tap target size
    );
  }
}
