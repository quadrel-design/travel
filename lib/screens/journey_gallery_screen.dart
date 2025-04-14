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
import 'package:travel/providers/logging_provider.dart';
import '../widgets/gallery_page_view.dart'; // Import the new PageView widget
import 'package:logger/logger.dart'; // Keep logger import
import '../widgets/full_screen_confirm_dialog.dart'; // Import the custom dialog
// import 'package:travel/constants/supabase.dart'; // REMOVED
// import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // REMOVED (Already changed/commented out)
// import 'package:travel/widgets/ca_app_bar.dart'; // REMOVED

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
  late Logger _logger;

  @override
  void initState() {
    super.initState();
    // Initialize logger here using ref (available in initState for ConsumerStatefulWidget)
    _logger = ref.read(loggerProvider);
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

  // Adjusted delete logic
  Future<void> _deleteImage(String imageUrl) async {
    bool confirm = await showDialog(
      context: context,
      // Use the custom dialog widget
      builder: (ctx) => FullScreenConfirmDialog(
        title: 'Delete Image?', // TODO: Localize
        content: 'Are you sure you want to permanently delete this image?', // TODO: Localize
      ),
      // barrierDismissible: false, // Optional: prevent dismissal by tapping outside
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
    // Logger is now a member variable, no need to read here
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
          // --- Signed URL Logic Start ---
          // Function to extract path (similar to repository delete logic)
          String? extractPath(String url) {
            try {
              final uri = Uri.parse(url);
              final bucketName = 'journey_images'; // Ensure this matches
              final pathStartIndex = uri.path.indexOf(bucketName) + bucketName.length + 1;
              if (pathStartIndex <= bucketName.length) return null;
              return uri.path.substring(pathStartIndex);
            } catch (e) {
              _logger.e('Failed to parse path from URL: $url', error: e);
              return null;
            }
          }

          final imagePath = extractPath(imageUrl);
          // --- Signed URL Logic End ---

          return GestureDetector(
            onTap: () async {
              // Pass original URLs to the PageView
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GalleryPageView(
                    imageUrls: _imageUrls,
                    initialIndex: index,
                    onDeleteImage: _deleteImage, // Pass original URL for deletion
                    onImageDeletedSuccessfully: (deletedUrl) {
                       _logger.d('onImageDeletedSuccessfully callback received for: $deletedUrl');
                       // Refresh the list from the repository instead of just local removal
                       if (mounted) {
                         _loadImages(); 
                       }
                    },
                    logger: _logger,
                  ),
                ),
              );
            },
            child: Hero(
              tag: imageUrl, // Use original URL for Hero tag
              child: ClipRRect(
                // --- Signed URL Logic Start ---
                child: imagePath == null
                  ? Container( // Show error if path extraction failed
                      color: theme.colorScheme.errorContainer,
                      child: Icon(Icons.broken_image, color: theme.colorScheme.onErrorContainer),
                    )
                  : FutureBuilder<String>(
                      // Generate signed URL (e.g., valid for 1 hour)
                      future: Supabase.instance.client.storage
                          .from('journey_images')
                          .createSignedUrl(imagePath, 3600),
                      builder: (context, snapshot) {
                        // --- Check for errors first ---
                        if (snapshot.hasError) {
                           _logger.e('Error creating signed URL for $imagePath', error: snapshot.error);
                           // Show error if URL generation failed
                           return Container(
                              color: theme.colorScheme.errorContainer, // Restore theme color
                              child: Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer), // Restore icon
                           );
                        }
                        
                        // --- Check if done and has data ---
                        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                           // Once signed URL is ready, load it with CachedNetworkImage
                           final signedUrl = snapshot.data!;
                           if (signedUrl.isEmpty) {
                               _logger.w('createSignedUrl returned empty string for $imagePath');
                                return Container(
                                  color: theme.colorScheme.errorContainer, // Restore theme color
                                  child: Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer), // Restore icon
                                );
                           }

                           return CachedNetworkImage(
                             // Use the generated signedUrl
                             imageUrl: signedUrl,
                             fit: BoxFit.cover,
                             placeholder: (context, url) => Container(
                                 color: theme.colorScheme.surfaceContainerHighest, // Restore theme color
                             ),
                             errorWidget: (context, url, error) {
                                // Log error with original path for clarity
                                _logger.w('Failed to load image via signed URL for path: $imagePath', error: error);
                                return Container(
                                  color: theme.colorScheme.surfaceContainerHighest, // Restore theme color
                                  child: Icon(Icons.error_outline, color: theme.colorScheme.onSurfaceVariant), // Restore icon
                                );
                             },
                           );
                        }

                        // --- Otherwise, assume loading ---
                        return Container(
                          color: theme.colorScheme.surfaceContainerHighest, // Restore theme color
                        );
                      },
                    ),
                 // --- Signed URL Logic Start (end of FutureBuilder scope) ---
              ),
            ),
          );
        },
      ),
    );
  }
} 