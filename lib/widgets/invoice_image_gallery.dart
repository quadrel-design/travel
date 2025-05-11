import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice_image_process.dart';
import '../services/gcs_file_service.dart';
import '../providers/service_providers.dart' as service;
import 'dart:convert';

class InvoiceImageGallery extends ConsumerWidget {
  final List<InvoiceImageProcess> images;
  final int currentIndex;
  final ValueChanged<int>? onPageChanged;
  final PageController? pageController;

  const InvoiceImageGallery({
    super.key,
    required this.images,
    required this.currentIndex,
    this.onPageChanged,
    this.pageController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (images.isEmpty) {
      return const Center(child: Text('No images available'));
    }

    return PhotoViewGallery.builder(
      scrollPhysics: const BouncingScrollPhysics(),
      builder: (BuildContext context, int index) {
        final imageInfo = images[index];
        return PhotoViewGalleryPageOptions.customChild(
          child: FutureBuilder<String>(
            future:
                ref.read(service.gcsFileServiceProvider).getSignedDownloadUrl(
                      fileName: imageInfo.imagePath,
                    ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Center(
                  child: Text('Error loading image: ${snapshot.error}'),
                );
              }
              return Image.network(
                snapshot.data!,
                fit: BoxFit.contain,
              );
            },
          ),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
          heroAttributes: PhotoViewHeroAttributes(tag: imageInfo.id),
        );
      },
      itemCount: images.length,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      pageController: pageController,
      onPageChanged: onPageChanged,
    );
  }
}
