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
    final state = ref.watch(provider);
    final images = state.images;

    _logger.d('[INVOICE_CAPTURE] UI received ${images.length} images:');
    for (final img in images) {
      _logger.d(
          '[INVOICE_CAPTURE] Image: id=${img.id}, url=${img.url}, imagePath=${img.imagePath}');
    }

    if (images.isNotEmpty && currentIndex >= images.length) {
      currentIndex = images.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && pageController.hasClients) {
          pageController.jumpToPage(currentIndex);
        }
      });
    }

    _logger.d('[INVOICE_CAPTURE] Building with ${images.length} images');
    if (images.isNotEmpty) {
      _logger.d(
          '[INVOICE_CAPTURE] First image path (URL fetched on demand by display widget): ${images[0].imagePath}, initial URL field: "${images[0].url}"');
    }

    return Scaffold(
      appBar: _buildAppBar(images),
      body: images.isEmpty
          ? const Center(child: Text('No images available'))
          : Stack(
              children: [
                InvoiceImageGallery(
                  images: images,
                  currentIndex: currentIndex,
                  pageController: pageController,
                  onPageChanged: (index) {
                    setState(() {
                      currentIndex = index;
                    });
                  },
                ),
                if (_showAnalysis && images.isNotEmpty)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withAlpha((255 * 0.7).round()),
                      child: InvoiceAnalysisPanel(
                        imageInfo: images[currentIndex],
                        onClose: () => setState(() => _showAnalysis = false),
                        logger: _logger,
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: InvoiceDetailBottomBar(
        onUpload: null,
        onScan: images.isNotEmpty ? () => _controller.handleScan() : null,
        onInfo: null,
        onFavorite: null,
        onSettings: null,
        onDelete: images.isNotEmpty ? () => _controller.handleDelete() : null,
      ),
    );
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
