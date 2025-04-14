import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart'; // Add main photo_view import
import 'package:photo_view/photo_view_gallery.dart'; // Use PhotoViewGallery for builder
import 'package:cached_network_image/cached_network_image.dart';
// import 'full_screen_image_viewer.dart'; // Not needed anymore

class GalleryPageView extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  // Callback when delete is pressed for a specific URL
  final Function(String) onDeleteImage;
  // Callback to remove URL locally after successful delete 
  // (Needed because PageView state doesn't automatically update)
  final Function(String) onImageDeletedSuccessfully;

  const GalleryPageView({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    required this.onDeleteImage, 
    required this.onImageDeletedSuccessfully,
  });

  @override
  State<GalleryPageView> createState() => _GalleryPageViewState();
}

class _GalleryPageViewState extends State<GalleryPageView> {
  late PageController _pageController;
  late List<String> _currentImageUrls; // Local copy to manage deletion
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentImageUrls = List.from(widget.imageUrls); // Make a mutable copy
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleDelete(String imageUrl) {
    // Call the passed-in delete function (which handles confirmation, repo call)
    widget.onDeleteImage(imageUrl);
    // If deletion is successful (or assumed successful optimistically),
    // remove it from the local list and update the PageView
    // Note: The actual success feedback should come from the onDeleteImage callback
    setState(() {
       final indexToRemove = _currentImageUrls.indexOf(imageUrl);
       if (indexToRemove != -1) {
         _currentImageUrls.removeAt(indexToRemove);
         // If no images left, pop the viewer
         if (_currentImageUrls.isEmpty) {
           Navigator.pop(context);
         } else {
           // Adjust index if the last item was deleted
           if (_currentIndex >= _currentImageUrls.length) {
             _currentIndex = _currentImageUrls.length - 1;
             // Jump to the new current page without animation 
             // after the state rebuilds in the next frame
             WidgetsBinding.instance.addPostFrameCallback((_) {
                _pageController.jumpToPage(_currentIndex);
             });
           }
         }
         // Notify the parent gallery screen that deletion occurred
         widget.onImageDeletedSuccessfully(imageUrl); 
       }
    });
  }

  @override
  Widget build(BuildContext context) {
    // If the list becomes empty somehow during build, pop
    if (_currentImageUrls.isEmpty) {
      // Schedule pop after build to avoid errors
      WidgetsBinding.instance.addPostFrameCallback((_) { 
         if(mounted && Navigator.canPop(context)) Navigator.pop(context);
      });
      return const Scaffold(body: Center(child: Text("No images left."))); // Placeholder
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      // Extend body behind AppBar for seamless look
      // extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white, // Ensure back button is visible
      ),
      body: PhotoViewGallery.builder(
        pageController: _pageController,
        itemCount: _currentImageUrls.length,
        builder: (context, index) {
          final imageUrl = _currentImageUrls[index];
          // Use the standard PageOptions, PhotoView is built-in
          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(imageUrl),
            initialScale: PhotoViewComputedScale.contained, // Use static member
            minScale: PhotoViewComputedScale.contained * 0.8,
            maxScale: PhotoViewComputedScale.covered * 2.0,
            heroAttributes: PhotoViewHeroAttributes(tag: imageUrl), // Use static member
          );
        },
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(),
        ),
        onPageChanged: (index) {
           setState(() {
             _currentIndex = index;
           });
        },
        // Add background decoration if needed (usually black is fine)
        // backgroundDecoration: BoxDecoration(color: Colors.black),
      ),
       // Keep BottomAppBar separate for delete button
       bottomNavigationBar: BottomAppBar(
         color: Colors.black.withOpacity(0.7),
         elevation: 0,
         child: Row(
           mainAxisAlignment: MainAxisAlignment.end,
           children: [
             IconButton(
               icon: const Icon(Icons.delete_outline),
               color: Colors.white, 
               tooltip: 'Delete Image', 
               // Use the current index to get the correct URL for deletion
               onPressed: () => _handleDelete(_currentImageUrls[_currentIndex]),
             ),
           ],
         ),
       ),
    );
  }
} 