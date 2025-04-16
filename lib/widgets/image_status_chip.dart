import 'package:flutter/material.dart';
import 'package:travel/models/journey_image_info.dart';

class ImageStatusChip extends StatelessWidget {
  final JourneyImageInfo imageInfo;

  const ImageStatusChip({super.key, required this.imageInfo});

  @override
  Widget build(BuildContext context) {
    // Determine status and style based on imageInfo
    String label;
    Color backgroundColor;
    Color textColor = Colors.white;

    // --- Revised Status Logic --- 
    if (imageInfo.lastProcessedAt == null) {
      // Status: Not Scanned
      label = 'Not Scanned'; // TODO: Localize
      backgroundColor = Colors.blue.shade700;
    } else if (imageInfo.hasPotentialText == false) {
      // Status: Processed, but No Text Found by Vision
      label = 'No Text'; // Using "No Text" label - TODO: Localize & Confirm Label
      backgroundColor = Colors.orange.shade700;
    } else if (imageInfo.detectedTotalAmount != null) {
      // Status: Processed Successfully with Amount
      label = 'Scanned'; // TODO: Localize
      backgroundColor = Colors.green.shade700;
    } else if (imageInfo.isInvoiceGuess == false) {
      // Status: Processed, Text Found, but NOT an Invoice
      label = 'No Invoice'; // TODO: Localize
      backgroundColor = Colors.black87;
    } else {
      // Status: Processed, Text Found, Was Invoice Guess, BUT extraction failed (Error)
      label = 'Error'; // TODO: Localize
      backgroundColor = Colors.red.shade700;
    }
    // --- End Revised Logic --- 

    return Chip(
      label: Text(label),
      labelStyle: TextStyle(color: textColor, fontSize: 10), // Smaller font size
      backgroundColor: backgroundColor,
      visualDensity: VisualDensity.compact, // Make chip smaller
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0), // Reduce padding
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduce tap target size
    );
  }
} 