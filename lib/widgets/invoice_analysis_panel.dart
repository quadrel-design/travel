import 'package:flutter/material.dart';
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
    logger.d('- location: ${imageInfo.location}');
    logger.d('- lastProcessedAt: ${imageInfo.lastProcessedAt}');
    logger.d('- isInvoiceGuess: ${imageInfo.isInvoiceGuess}');
    logger.d(
        '- extractedText: ${imageInfo.extractedText != null ? 'Available (${imageInfo.extractedText!.length} chars)' : 'Not available'}');

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
              if (imageInfo.extractedText != null &&
                  imageInfo.extractedText!.isNotEmpty)
                _buildExtractedText(),
              if (imageInfo.location != null && imageInfo.location!.isNotEmpty)
                _buildLocation(),
              if (imageInfo.lastProcessedAt != null) _buildProcessedDate(),
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
          imageInfo.status == 'invoice'
              ? 'Invoice'
              : (imageInfo.status ?? 'Unknown'),
          style: TextStyle(
            color: imageInfo.status == 'invoice'
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

  Widget _buildExtractedText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Extracted Text:',
          style: UIConstants.kPanelLabelStyle,
        ),
        const SizedBox(height: UIConstants.kElementSpacing),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: Text(
              imageInfo.extractedText!,
              style: UIConstants.kPanelValueStyle,
            ),
          ),
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
}
