import 'package:flutter/material.dart';
import 'dart:math';
import '../models/invoice_capture_process.dart';
import '../constants/ui_constants.dart';
import 'package:logger/logger.dart';

class InvoiceAnalysisPanel extends StatelessWidget {
  final InvoiceCaptureProcess imageInfo;
  final VoidCallback onClose;
  final Logger logger;

  const InvoiceAnalysisPanel({
    super.key,
    required this.imageInfo,
    required this.onClose,
    required this.logger,
  });

  @override
  Widget build(BuildContext context) {
    // Log data for debugging
    logger.d('INVOICE DATA DEBUG:');
    logger.d('- id: ${imageInfo.id}');
    logger.d('- status: ${imageInfo.status}');
    logger.d('- detectedTotalAmount: ${imageInfo.detectedTotalAmount}');
    logger.d('- detectedCurrency: ${imageInfo.detectedCurrency}');
    logger.d('- location: ${imageInfo.location}');
    logger.d('- lastProcessedAt: ${imageInfo.lastProcessedAt}');
    logger.d(
        '- detectedText: ${imageInfo.detectedText?.substring(0, min(50, imageInfo.detectedText?.length ?? 0))}...');
    logger.d('- isInvoiceGuess: ${imageInfo.isInvoiceGuess}');
    logger.d('- hasPotentialText: ${imageInfo.hasPotentialText}');

    return Container(
      color: UIConstants.kPanelBackgroundColor,
      width: double.infinity,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(UIConstants.kPanelPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: UIConstants.kSectionSpacing),
              _buildInvoiceStatus(),
              if (imageInfo.detectedTotalAmount != null) _buildTotalAmount(),
              if (imageInfo.location != null && imageInfo.location!.isNotEmpty)
                _buildLocation(),
              if (imageInfo.lastProcessedAt != null) _buildProcessedDate(),
              if (imageInfo.detectedText != null &&
                  imageInfo.detectedText!.isNotEmpty)
                _buildDetectedText(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Invoice Analysis',
          style: UIConstants.kPanelTitleStyle,
        ),
        IconButton(
          icon:
              const Icon(Icons.close, color: UIConstants.kPanelForegroundColor),
          onPressed: onClose,
        ),
      ],
    );
  }

  Widget _buildInvoiceStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Invoice Status:',
          style: UIConstants.kPanelLabelStyle,
        ),
        const SizedBox(height: UIConstants.kElementSpacing),
        Text(
          imageInfo.status == 'Invoice' ? 'Invoice' : 'Not an Invoice',
          style: TextStyle(
            color: imageInfo.status == 'Invoice'
                ? UIConstants.kPanelHighlightColor
                : UIConstants.kPanelWarningColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: UIConstants.kSectionSpacing),
      ],
    );
  }

  Widget _buildTotalAmount() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Total Amount:',
          style: UIConstants.kPanelLabelStyle,
        ),
        const SizedBox(height: UIConstants.kElementSpacing),
        Text(
          '${imageInfo.detectedTotalAmount} ${imageInfo.detectedCurrency ?? ''}',
          style: UIConstants.kPanelHighlightedValueStyle,
        ),
        const SizedBox(height: UIConstants.kSectionSpacing),
      ],
    );
  }

  Widget _buildLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location:',
          style: UIConstants.kPanelLabelStyle,
        ),
        const SizedBox(height: UIConstants.kElementSpacing),
        Text(
          imageInfo.location!,
          style: UIConstants.kPanelValueStyle,
        ),
        const SizedBox(height: UIConstants.kSectionSpacing),
      ],
    );
  }

  Widget _buildProcessedDate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Processed On:',
          style: UIConstants.kPanelLabelStyle,
        ),
        const SizedBox(height: UIConstants.kElementSpacing),
        Text(
          imageInfo.lastProcessedAt!.toLocal().toString().split('.')[0],
          style: UIConstants.kPanelValueStyle.copyWith(fontSize: 14),
        ),
        const SizedBox(height: UIConstants.kSectionSpacing),
      ],
    );
  }

  Widget _buildDetectedText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detected Text:',
          style: UIConstants.kPanelLabelStyle,
        ),
        const SizedBox(height: UIConstants.kElementSpacing),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            child: Text(
              imageInfo.detectedText!,
              style: const TextStyle(color: UIConstants.kPanelForegroundColor),
            ),
          ),
        ),
      ],
    );
  }
}
