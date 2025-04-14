import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/repositories/journey_repository.dart';
import 'package:uuid/uuid.dart';
// import 'dart:typed_data'; // Unused import
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase client
import 'package:path/path.dart' as p; // For getting extension
// import 'package:go_router/go_router.dart'; // Remove unused import
import 'package:travel/models/journey.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Add import
// import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Unused import
import 'package:travel/providers/gallery_state.dart'; // Import the new provider
// import '../widgets/full_screen_image_viewer.dart'; // Remove this import
import '../widgets/gallery_page_view.dart'; // Import the new PageView widget

// Change back to ConsumerStatefulWidget
class JourneyGalleryScreen extends ConsumerStatefulWidget {
  final Journey journey;
  const JourneyGalleryScreen({super.key, required this.journey});

  @override
  ConsumerState<JourneyGalleryScreen> createState() => _JourneyGalleryScreenState();
}

class _JourneyGalleryScreenState extends ConsumerState<JourneyGalleryScreen> {
  // Add state variables
  late JourneyRepository _journeyRepository;
  bool _isLoadingImages = true;
  String? _imageError;
  List<String> _imageUrls = [];
  bool _isUploading = false; // Add back uploading state

  @override
  void initState() {
    super.initState();
    // Defer reading provider to didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _journeyRepository = ref.read(journeyRepositoryProvider);
    // Load images only once initially or if an error occurred previously
    if (_isLoadingImages || _imageError != null) {
       _loadImages();
    }
  }

  // Add image loading function
  Future<void> _loadImages() async {
    // Avoid calling setState if the widget is already disposed
    if (!mounted) return;
    setState(() {
      _isLoadingImages = true;
      _imageError = null; // Clear previous error on reload attempt
    });
    try {
      // Use original fetch without pagination
      final urls = await _journeyRepository.fetchJourneyImages(widget.journey.id);
      // Check mount status again after async operation
      if (!mounted) return;
      setState(() {
        _imageUrls = urls;
        _isLoadingImages = false;
      });
    } catch (e) {
      // Check mount status again after async operation
      if (!mounted) return;
      setState(() {
        _imageError = 'Failed to load images'; // TODO: Localize
        _isLoadingImages = false;
      });
    }
  }

  // Add back _addImage function
  Future<void> _addImage() async {
    if (_isUploading) return;
    final picker = ImagePicker();
    try {
      final List<XFile> pickedFiles = await picker.pickMultiImage();
      if (!mounted || pickedFiles.isEmpty) return;
      setState(() { _isUploading = true; });
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("User not logged in."); // TODO: Handle gracefully

      int successCount = 0;
      List<String> errorMessages = [];
      for (final pickedFile in pickedFiles) {
        try {
          final bytes = await pickedFile.readAsBytes();
          final fileExt = p.extension(pickedFile.name);
          final fileName = '${const Uuid().v4()}$fileExt';
          final filePath = '$userId/${widget.journey.id}/$fileName';
          await supabase.storage.from('journey_images').uploadBinary(
                filePath, bytes, fileOptions: FileOptions(contentType: pickedFile.mimeType));
          final imageUrl = supabase.storage.from('journey_images').getPublicUrl(filePath);
          await _journeyRepository.addImageReference(widget.journey.id, imageUrl);
          successCount++;
        } catch (e) { errorMessages.add('Failed to upload ${pickedFile.name}.'); } // TODO: Localize
      }
      _loadImages(); // Refresh list after upload
      if (mounted && (successCount > 0 || errorMessages.isNotEmpty)) {
          String message = '$successCount image(s) uploaded.'; // TODO: Localize
          if (errorMessages.isNotEmpty) {
            message += '\nErrors:\n${errorMessages.join("\n")}'; // TODO: Localize
          }
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message), duration: Duration(seconds: errorMessages.isEmpty ? 2 : 5))
          );
      }
    } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error processing images: $e')) // TODO: Localize
          );
        }
    } finally { if (mounted) setState(() { _isUploading = false; }); }
  }

  // Adjusted delete logic - PageView handles its own UI updates
  Future<void> _deleteImage(String imageUrl) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Image?'), // TODO: Localize
        content: const Text('Are you sure you want to permanently delete this image?'), // TODO: Localize
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')), // TODO: Localize
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')), // TODO: Localize
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      // No immediate UI removal from this screen's state
      await _journeyRepository.deleteImage(widget.journey.id, imageUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image deleted.')) // TODO: Localize
        );
        // Note: The actual removal from _imageUrls list happens
        // in the onImageDeletedSuccessfully callback passed to GalleryPageView
      }
    } catch (e) {
      if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error deleting image: $e')) // TODO: Localize
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Get theme for potential use
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.journey.title} - Gallery'),
        centerTitle: true,
        actions: [
          // Add a refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoadingImages ? null : _loadImages, // Allow manual refresh, disable while loading
            tooltip: 'Refresh', // TODO: Localize
          ),
        ],
      ),
      // Update body based on state
      body: _buildGalleryContent(theme),
      // Add FloatingActionButton back
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoadingImages || _isUploading ? null : _addImage, // Disable while loading/uploading
        tooltip: 'Add Image', // TODO: Localize
        child: _isUploading 
               ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0) // Use smaller indicator
               : const Icon(Icons.add_photo_alternate_outlined),
      ),
    );
  }

  // Add content building function
  Widget _buildGalleryContent(ThemeData theme) {
    if (_isLoadingImages) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_imageError != null) {
      // Show error message and a retry button
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_imageError!, style: TextStyle(color: theme.colorScheme.error), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadImages, // Retry loading
                child: const Text('Retry'), // TODO: Localize
              )
            ]
          ),
        )
      );
    }
    if (_imageUrls.isEmpty) {
      // Show message when there are no images
      return const Center(child: Text('No images added yet.')); // TODO: Localize
    }

    // Use GridView.builder to display images
    return RefreshIndicator( // Wrap with RefreshIndicator for pull-to-refresh
      onRefresh: _loadImages,
      child: GridView.builder(
        // Adjust padding slightly if needed, 1px spacing might look better edge-to-edge
        padding: const EdgeInsets.all(1.0), // Use 1.0 padding to complement spacing
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, // Increase count for smaller images
          crossAxisSpacing: 1.0, // 1px spacing
          mainAxisSpacing: 1.0, // 1px spacing
        ),
        itemCount: _imageUrls.length,
        itemBuilder: (context, index) {
          final imageUrl = _imageUrls[index];
          return GestureDetector(
            onTap: () async {
              // Navigate to GalleryPageView and wait for it to pop
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GalleryPageView(
                    imageUrls: _imageUrls, 
                    initialIndex: index,   
                    onDeleteImage: _deleteImage, 
                    onImageDeletedSuccessfully: (deletedUrl) {
                       print('[DEBUG] onImageDeletedSuccessfully called for: $deletedUrl (Applying setState)');
                       if (mounted) { 
                         setState(() {
                           _imageUrls.remove(deletedUrl);
                         });
                       }
                    },
                  ),
                ),
              );
            },
            child: Hero( 
              tag: imageUrl, 
              child: ClipRRect(
                 child: CachedNetworkImage(
                   imageUrl: imageUrl,
                   fit: BoxFit.cover, 
                   placeholder: (context, url) => Container( 
                       color: theme.colorScheme.surfaceContainerHighest,
                   ),
                   errorWidget: (context, url, error) => Container(
                     color: theme.colorScheme.surfaceContainerHighest, 
                     child: Icon(Icons.error_outline, color: theme.colorScheme.onSurfaceVariant),
                   ),
                 ),
              ),
            ),
          );
        },
      ),
    );
  }
} 