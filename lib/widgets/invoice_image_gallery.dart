import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../models/invoice_image_process.dart';

class InvoiceImageGallery extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const Center(child: Text('No images available'));
    }
    return PhotoViewGallery.builder(
      scrollPhysics: const BouncingScrollPhysics(),
      builder: (BuildContext context, int index) {
        final imageInfo = images[index];
        return PhotoViewGalleryPageOptions.customChild(
          child: Image.network(imageInfo.url, fit: BoxFit.contain),
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
