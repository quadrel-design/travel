import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice_image_process.dart';
import 'package:travel/providers/service_providers.dart';

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
        final asyncSignedUrl =
            ref.watch(signedUrlProvider(imageInfo.imagePath));

        return PhotoViewGalleryPageOptions.customChild(
          child: asyncSignedUrl.when(
            data: (signedUrl) {
              if (signedUrl.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_outlined,
                          size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Image not available.',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }
              return PhotoView(
                imageProvider: CachedNetworkImageProvider(signedUrl),
                loadingBuilder: (context, event) {
                  double? progress;
                  if (event != null && event.expectedTotalBytes != null) {
                    progress =
                        event.cumulativeBytesLoaded / event.expectedTotalBytes!;
                  }
                  return Center(
                    child: CircularProgressIndicator(value: progress),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.redAccent),
                        const SizedBox(height: 8),
                        const Text('Error loading image.',
                            style: TextStyle(color: Colors.redAccent)),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            ref.invalidate(
                                signedUrlProvider(imageInfo.imagePath));
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                },
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
                heroAttributes: PhotoViewHeroAttributes(tag: imageInfo.id),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off_outlined,
                        size: 48, color: Colors.orangeAccent),
                    const SizedBox(height: 8),
                    const Text('Could not load image URL.',
                        style: TextStyle(color: Colors.orangeAccent)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(signedUrlProvider(imageInfo.imagePath));
                      },
                      child: const Text('Retry URL Fetch'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
      itemCount: images.length,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      pageController: pageController,
      onPageChanged: onPageChanged,
    );
  }
}
