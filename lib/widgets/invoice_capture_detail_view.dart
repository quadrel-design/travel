import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../models/invoice_image_process.dart';
import '../providers/invoice_capture_provider.dart';
import '../providers/logging_provider.dart';
import './invoice_analysis_panel.dart';
import 'package:travel/widgets/invoice_detail_bottom_bar.dart';
import 'package:travel/widgets/invoice_image_gallery.dart';
import 'package:travel/widgets/invoice_capture_controller.dart';

class InvoiceCaptureDetailView extends ConsumerStatefulWidget {
  const InvoiceCaptureDetailView({
    super.key,
    this.initialIndex = 0,
    required this.projectId,
    required this.invoiceId,
  });

  final int initialIndex;
  final String projectId;
  final String invoiceId;

  @override
  ConsumerState<InvoiceCaptureDetailView> createState() {
    return _InvoiceCaptureDetailViewState();
  }
}

class _InvoiceCaptureDetailViewState
    extends ConsumerState<InvoiceCaptureDetailView> {
  late PageController pageController;
  late int currentIndex;
  final bool _isDeleting = false;
  final bool _showAppBar = true;
  bool _showAnalysis = false;
  late Logger _logger;
  late String invoiceId;
  late InvoiceCaptureController _controller;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    pageController = PageController(initialPage: widget.initialIndex);
    _logger = ref.read(loggerProvider);
    invoiceId = widget.invoiceId;
    _controller = InvoiceCaptureController(
        ref: ref,
        logger: _logger,
        context: context,
        projectId: widget.projectId,
        invoiceId: invoiceId,
        setState: setState,
        getCurrentIndex: () => currentIndex,
        getImages: () => ref
            .read(invoiceCaptureProvider(
                (projectId: widget.projectId, invoiceId: invoiceId)))
            .images);
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _logger.d('InvoiceCaptureDetailView build called');
    final provider = invoiceCaptureProvider(
        (projectId: widget.projectId, invoiceId: widget.invoiceId));
    final captureState = ref.watch(provider);

    if (captureState.images.isNotEmpty &&
        currentIndex >= captureState.images.length) {
      currentIndex = captureState.images.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && pageController.hasClients) {
          pageController.jumpToPage(currentIndex);
        }
      });
    }

    _logger.d(
        '[INVOICE_CAPTURE_DETAIL_VIEW] Building with imageListStatus: ${captureState.imageListStatus}, image count: ${captureState.images.length}');

    return Scaffold(
      appBar: _buildAppBar(captureState.images),
      body: _buildDetailBody(captureState),
      bottomNavigationBar: InvoiceDetailBottomBar(
        onUpload: null,
        onScan: captureState.imageListStatus == ImageListStatus.success &&
                captureState.images.isNotEmpty
            ? () => _controller.handleScan()
            : null,
        onInfo: null,
        onFavorite: null,
        onSettings: null,
        onDelete: captureState.imageListStatus == ImageListStatus.success &&
                captureState.images.isNotEmpty
            ? () => _controller.handleDelete()
            : null,
      ),
    );
  }

  Widget _buildDetailBody(InvoiceCaptureState captureState) {
    switch (captureState.imageListStatus) {
      case ImageListStatus.initial:
      case ImageListStatus.loading:
        _logger.d(
            '[INVOICE_CAPTURE_DETAIL_VIEW] Status: loading/initial - showing CircularProgressIndicator');
        return const Center(child: CircularProgressIndicator());
      case ImageListStatus.error:
        _logger.w(
            '[INVOICE_CAPTURE_DETAIL_VIEW] Status: error - showing error message: ${captureState.generalError}');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Text(captureState.generalError ?? 'An unknown error occurred.'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(invoiceCaptureProvider((
                    projectId: widget.projectId,
                    invoiceId: widget.invoiceId
                  )));
                },
                child: const Text('Retry List Load'),
              ),
            ],
          ),
        );
      case ImageListStatus.success:
        _logger.d(
            '[INVOICE_CAPTURE_DETAIL_VIEW] Status: success. Image count: ${captureState.images.length}');
        if (captureState.images.isEmpty) {
          _logger.i(
              '[INVOICE_CAPTURE_DETAIL_VIEW] No images available after successful load.');
          return const Center(child: Text('No images found for this project.'));
        }
        _logger.d('[INVOICE_CAPTURE_DETAIL_VIEW] Showing InvoiceImageGallery.');
        return Stack(
          children: [
            InvoiceImageGallery(
              images: captureState.images,
              currentIndex: currentIndex,
              pageController: pageController,
              onPageChanged: (index) {
                setState(() {
                  currentIndex = index;
                });
              },
            ),
            if (_showAnalysis && captureState.images.isNotEmpty)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withAlpha((255 * 0.7).round()),
                  child: InvoiceAnalysisPanel(
                    imageInfo: captureState.images[currentIndex],
                    onClose: () => setState(() => _showAnalysis = false),
                    logger: _logger,
                  ),
                ),
              ),
          ],
        );
    }
  }

  PreferredSizeWidget? _buildAppBar(List<InvoiceImageProcess> images) {
    if (!_showAppBar) return null;

    return AppBar(
      title: Text('Image ${currentIndex + 1} of ${images.length}'),
      actions: [
        if (!_isDeleting)
          IconButton(
            icon: const Icon(Icons.document_scanner),
            onPressed: () => _controller.handleScan(),
            tooltip: 'Scan Invoice',
          ),
        if (!_isDeleting)
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () async {
              _logger.d('Analyze button pressed!');
              setState(() => _showAnalysis = false);
              await _controller.handleAnalyze();
              setState(() => _showAnalysis = true);
            },
            tooltip: 'Analyze Invoice',
          ),
        if (!_isDeleting)
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _controller.handleDelete(),
            tooltip: 'Delete Image',
          ),
      ],
    );
  }
}
