import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice_image_process.dart';
import '../constants/ui_constants.dart';
import '../providers/service_providers.dart';
import 'package:logger/logger.dart';

class InvoiceAnalysisPanel extends ConsumerWidget {
  final InvoiceImageProcess imageInfo;
  final VoidCallback onClose;
  final Logger logger;

  const InvoiceAnalysisPanel({
    super.key,
    required this.imageInfo,
    required this.onClose,
    required this.logger,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Enhanced logging for debugging
    logger.d('INVOICE DATA DEBUG:');
    logger.d('- id: ${imageInfo.id}');
    logger.d('- location: ${imageInfo.location}');
    logger.d('- lastProcessedAt: ${imageInfo.lastProcessedAt}');
    logger.d('- isInvoiceGuess: ${imageInfo.isInvoiceGuess}');
    logger.d(
        '- ocrText: ${imageInfo.ocrText != null ? 'Available (${imageInfo.ocrText!.length} chars)' : 'Not available'}');

    // Detailed invoiceAnalysis logging
    logger.d('----- INVOICE ANALYSIS DEBUG -----');
    logger.d('invoiceAnalysis type: ${imageInfo.invoiceAnalysis.runtimeType}');
    logger.d('invoiceAnalysis null?: ${imageInfo.invoiceAnalysis == null}');
    if (imageInfo.invoiceAnalysis != null) {
      logger.d(
          'invoiceAnalysis keys: ${imageInfo.invoiceAnalysis!.keys.toList()}');
      logger.d(
          'totalAmount present?: ${imageInfo.invoiceAnalysis!.containsKey('totalAmount')}');
      logger
          .d('totalAmount value: ${imageInfo.invoiceAnalysis!['totalAmount']}');
      logger.d('currency value: ${imageInfo.invoiceAnalysis!['currency']}');
      logger.d('Full invoiceAnalysis:');
      logger.d(imageInfo.invoiceAnalysis.toString());
    }
    logger.d('---------------------------------');

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
              if (imageInfo.invoiceAnalysis != null)
                _buildStructuredAnalysis(
                    InvoiceAnalysis.fromJson(imageInfo.invoiceAnalysis!))
              else
                _buildNoAnalysisPanel(ref),
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
    // Determine status based on isInvoiceGuess
    String statusText = 'Unknown';
    Color statusColor = UIConstants.kPanelWarningColor;

    if (imageInfo.invoiceAnalysis != null) {
      if (imageInfo.isInvoiceGuess) {
        statusText = 'Valid Invoice';
        statusColor = Colors.green;
      } else {
        statusText = 'Not an Invoice';
        statusColor = Colors.orange;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Invoice Status:',
          style: UIConstants.kPanelLabelStyle,
        ),
        const SizedBox(height: UIConstants.kElementSpacing),
        Text(
          statusText,
          style: TextStyle(
            color: statusColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
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

  Widget _buildStructuredAnalysis(InvoiceAnalysis analysis) {
    // Debug the parsed InvoiceAnalysis object
    logger.d('----- PARSED INVOICE ANALYSIS -----');
    logger.d('totalAmount: ${analysis.totalAmount}');
    logger.d('currency: ${analysis.currency}');
    logger.d('merchantName: ${analysis.merchantName}');
    logger.d('date: ${analysis.date}');
    logger.d('location: ${analysis.location}');
    logger.d('taxes: ${analysis.taxes}');
    logger.d('category: ${analysis.category}');
    logger.d('taxonomy: ${analysis.taxonomy}');
    logger.d('-----------------------------------');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gemini Analysis:',
          style: UIConstants.kPanelLabelStyle,
        ),
        const SizedBox(height: UIConstants.kElementSpacing),
        if (analysis.totalAmount != null)
          Text('Total Amount: ${analysis.totalAmount}',
              style: UIConstants.kPanelValueStyle),
        if (analysis.currency != null)
          Text('Currency: ${analysis.currency}',
              style: UIConstants.kPanelValueStyle),
        if (analysis.merchantName != null)
          Text('Merchant: ${analysis.merchantName}',
              style: UIConstants.kPanelValueStyle),
        if (analysis.date != null)
          Text('Date: ${analysis.date}', style: UIConstants.kPanelValueStyle),
        if (analysis.location != null)
          Text('Location: ${analysis.location}',
              style: UIConstants.kPanelValueStyle),
        if (analysis.taxes != null)
          Text('Taxes: ${analysis.taxes} ${analysis.currency ?? ""}',
              style: UIConstants.kPanelValueStyle),
        if (analysis.category != null)
          Text('Category: ${analysis.category}',
              style: UIConstants.kPanelValueStyle),
        if (analysis.taxonomy != null)
          Text('Taxonomy: ${analysis.taxonomy}',
              style: UIConstants.kPanelValueStyle),
        const SizedBox(height: UIConstants.kSectionSpacing),
        const Divider(color: Colors.white30),
        const SizedBox(height: UIConstants.kElementSpacing),
        if (analysis.category != null && analysis.totalAmount != null)
          Text(
            imageInfo.isInvoiceGuess
                ? 'This is a valid ${analysis.category} invoice of ${analysis.totalAmount} ${analysis.currency ?? ""} ${analysis.merchantName != null ? 'from ${analysis.merchantName}' : ''} ${analysis.location != null ? 'in ${analysis.location}' : ''}.'
                : 'This appears to be a ${analysis.category} document, but may not be a valid invoice. Please verify the details.',
            style: UIConstants.kPanelValueStyle.copyWith(
              fontWeight: FontWeight.bold,
              color: imageInfo.isInvoiceGuess
                  ? Colors.lightBlueAccent
                  : Colors.orange,
            ),
          ),
      ],
    );
  }

  Widget _buildNoAnalysisPanel(WidgetRef ref) {
    final isProcessing = ref.watch(invoiceProcessingProvider(imageInfo.id));
    final needsOcr = imageInfo.ocrText == null || imageInfo.ocrText!.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            'No Gemini analysis available for this image.',
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        if (needsOcr)
          const Padding(
            padding: EdgeInsets.only(bottom: 12.0),
            child: Text(
              'OCR must be run first to extract text from the image.',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              icon: isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ))
                  : const Icon(Icons.refresh, size: 18),
              label: Text(isProcessing ? 'Processing...' : 'Run Analysis'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              onPressed:
                  needsOcr || isProcessing ? null : () => _runAnalysis(ref),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              icon: isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ))
                  : const Icon(Icons.document_scanner, size: 18),
              label: Text(isProcessing ? 'Processing...' : 'Run OCR First'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: isProcessing ? null : () => _runOCR(ref),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (needsOcr)
          const Text(
            'Note: OCR needs to be run before analysis can be completed.',
            style: TextStyle(
              color: Colors.white70,
              fontStyle: FontStyle.italic,
              fontSize: 14,
            ),
          ),
        if (isProcessing)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text(
              'Processing your request. This may take a few moments...',
              style: TextStyle(
                color: Colors.lightBlue,
                fontSize: 14,
              ),
            ),
          ),
        const SizedBox(height: UIConstants.kSectionSpacing),
      ],
    );
  }

  Future<void> _runOCR(WidgetRef ref) async {
    logger.i('OCR requested for image: ${imageInfo.id}');
    ref.read(invoiceProcessingProvider(imageInfo.id).notifier).state = true;

    try {
      final service = ref.read(invoiceProcessingServiceProvider);

      // Extract projectId from the image path
      // Format: users/{userId}/projects/{projectId}/invoice_images/{filename}
      final pathComponents = imageInfo.imagePath.split('/');
      String? projectId;

      final projectsIndex = pathComponents.indexOf('projects');
      if (projectsIndex != -1 && projectsIndex + 1 < pathComponents.length) {
        projectId = pathComponents[projectsIndex + 1];
        logger.d('Extracted projectId: $projectId');
      }

      // The invoiceId for the backend call is the image's own ID
      final String invoiceIdForBackend = imageInfo.id;
      logger.d(
          'Using imageInfo.id as invoiceId for backend OCR call: $invoiceIdForBackend');

      if (projectId == null) {
        logger.e(
            'Failed to extract project ID from path: ${imageInfo.imagePath}');
        throw Exception('Invalid image path format for project ID extraction');
      }

      final result = await service.runOCR(
        projectId,
        invoiceIdForBackend, // Use imageInfo.id as the invoiceId for the service
        imageInfo.id, // This is the imageId (image's own unique ID)
      );

      if (result) {
        logger.i('OCR request sent successfully');
      } else {
        logger.e('OCR request failed');
      }
    } catch (e) {
      logger.e('Error processing OCR request', error: e);
    } finally {
      ref.read(invoiceProcessingProvider(imageInfo.id).notifier).state = false;
    }
  }

  Future<void> _runAnalysis(WidgetRef ref) async {
    logger.i('Analysis requested for image: ${imageInfo.id}');
    ref.read(invoiceProcessingProvider(imageInfo.id).notifier).state = true;

    try {
      final service = ref.read(invoiceProcessingServiceProvider);

      // Extract projectId from the image path
      // Format: users/{userId}/projects/{projectId}/invoice_images/{filename}
      final pathComponents = imageInfo.imagePath.split('/');
      String? projectId;

      final projectsIndex = pathComponents.indexOf('projects');
      if (projectsIndex != -1 && projectsIndex + 1 < pathComponents.length) {
        projectId = pathComponents[projectsIndex + 1];
        logger.d('Extracted projectId: $projectId');
      }

      // The invoiceId for the backend call is the image's own ID
      final String invoiceIdForBackend = imageInfo.id;
      logger.d(
          'Using imageInfo.id as invoiceId for backend analysis call: $invoiceIdForBackend');

      if (projectId == null) {
        logger.e(
            'Failed to extract project ID from path: ${imageInfo.imagePath}');
        throw Exception('Invalid image path format for project ID extraction');
      }

      final result = await service.runAnalysis(
        projectId,
        invoiceIdForBackend, // Use imageInfo.id as the invoiceId for the service
        imageInfo.id, // This is the imageId (image's own unique ID)
      );

      if (result) {
        logger.i('Analysis request sent successfully');
      } else {
        logger.e('Analysis request failed');
      }
    } catch (e) {
      logger.e('Error processing analysis request', error: e);
    } finally {
      ref.read(invoiceProcessingProvider(imageInfo.id).notifier).state = false;
    }
  }
}

// Image processing state provider
final invoiceProcessingProvider =
    StateProvider.family<bool, String>((ref, imageId) => false);
