import 'package:flutter/material.dart';
import '../models/invoice_capture_process.dart';
import '../models/invoice_capture_status.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ImageStatusChip extends StatelessWidget {
  final InvoiceCaptureProcess imageInfo;

  const ImageStatusChip({super.key, required this.imageInfo});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = InvoiceCaptureStatus.fromFirebaseStatus(imageInfo.status);

    // Get the appropriate label based on status
    String label;
    Color chipColor;
    bool showSpinner = false;

    switch (status) {
      case InvoiceCaptureStatus.ready:
        label = l10n.imageStatusNotScanned;
        chipColor = Colors.grey;
        break;
      case InvoiceCaptureStatus.processing:
        // Check the raw status to differentiate between OCR and analysis
        if (imageInfo.status == 'ocr_running') {
          label = 'OCR Processing';
          chipColor = Colors.blue;
          showSpinner = true;
        } else {
          label = l10n.imageStatusProcessing;
          chipColor = Colors.blue;
          showSpinner = true;
        }
        break;
      case InvoiceCaptureStatus.noText:
        label = l10n.imageStatusNoText;
        chipColor = Colors.orange;
        break;
      case InvoiceCaptureStatus.text:
        label = l10n.imageStatusText;
        chipColor = Colors.green;
        break;
      case InvoiceCaptureStatus.invoice:
        label = l10n.imageStatusInvoice;
        chipColor = Colors.blue;
        break;
      case InvoiceCaptureStatus.error:
        label = l10n.imageStatusError;
        chipColor = Colors.red;
        break;
    }

    if (showSpinner) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(chipColor),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: chipColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Chip(
      label: Text(label),
      backgroundColor: chipColor.withOpacity(0.2),
      labelStyle: TextStyle(color: chipColor),
      side: BorderSide(color: chipColor),
    );
  }
}
