import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/repositories/journey_repository.dart';
import 'package:uuid/uuid.dart';
// import 'dart:convert'; // Likely unused now
// import 'dart:io'; // Likely unused now
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase client
import 'package:path/path.dart' as p; // For getting extension
// import 'package:go_router/go_router.dart'; // Remove unused import
import 'package:travel/models/journey.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Add import
// import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Unused import
import 'package:travel/providers/logging_provider.dart';
// import '../widgets/gallery_page_view.dart'; // Import the new PageView widget
import 'package:logger/logger.dart'; // Keep logger import
import '../widgets/full_screen_confirm_dialog.dart'; // Import the custom dialog
// import 'package:travel/constants/supabase.dart'; // REMOVED
// import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // REMOVED (Already changed/commented out)
// import 'package:travel/widgets/ca_app_bar.dart'; // REMOVED
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // Remove Re-import ML Kit Text Recognition
import '../models/journey_image_info.dart'; // Import the new model
import 'package:http/http.dart' as http; // Keep for now, might be needed in GalleryPageView scan
import 'dart:math'; // Keep for min()
import '../widgets/gallery_detail_view.dart'; // Import the new PageView widget
import 'dart:convert'; // Added for base64 encoding

// Rename class
class GalleryOverviewScreen extends ConsumerStatefulWidget {
  final Journey journey;
  // Update constructor name
  const GalleryOverviewScreen({super.key, required this.journey});

  @override
  // Update return type and method call
  ConsumerState<GalleryOverviewScreen> createState() => _GalleryOverviewScreenState();
}

// Rename state class
class _GalleryOverviewScreenState extends ConsumerState<GalleryOverviewScreen> {
  // Add state variables
  late JourneyRepository _journeyRepository;
  bool _isLoadingImages = true;
  String? _imageError;
  List<JourneyImageInfo> _journeyImages = [];
  bool _isUploading = false;
  late Logger _logger;
  // Removed Realtime/keyword variables

  @override
  void initState() {
    super.initState();
    _logger = ref.read(loggerProvider);
  }

  @override
  void dispose() {
    // Cleaned up
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _journeyRepository = ref.read(journeyRepositoryProvider);
    if (_isLoadingImages || _imageError != null) {
       _loadImages(); // Simplified
    }
  }

  // Removed Realtime methods

  // Add image loading function
  Future<void> _loadImages() async {
    // --- Add Check for valid Journey ID ---
    if (widget.journey.id.isEmpty) {
      _logger.e('_loadImages aborted: Journey ID is empty.');
      if (mounted) {
        setState(() {
          _isLoadingImages = false;
          _imageError = 'Cannot load images: Invalid Journey ID.'; // TODO: Localize
        });
      }
      return;
    }
    // --- End Check ---

    _logger.d('_loadImages started for journey ID: ${widget.journey.id}');
    if (!mounted) {
      _logger.w('_loadImages aborted: widget not mounted.');
      return;
    }
    setState(() {
      _isLoadingImages = true;
      _imageError = null; // Clear previous error on reload attempt
    });
    try {
      // Fetch JourneyImageInfo objects
      final imagesInfo = await _journeyRepository.fetchJourneyImages(widget.journey.id);
      if (!mounted) {
         _logger.w('_loadImages aborted after fetch: widget not mounted.');
         return;
      }
      setState(() {
        _journeyImages = imagesInfo; // Store the list of objects
        _isLoadingImages = false;
      });
      _logger.d('_loadImages finished successfully.');
    } catch (e) {
      _logger.e('_loadImages failed.', error: e);
      // Check mount status again after async operation
      if (!mounted) {
         _logger.w('_loadImages aborted after error: widget not mounted.');
         return;
      }
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
      if (userId == null) throw Exception("User not logged in.");

      int successCount = 0;
      List<String> errorMessages = [];
      for (final pickedFile in pickedFiles) {
        try {
          final imageRecordId = const Uuid().v4();
          _logger.d('Generated image record ID: $imageRecordId for ${pickedFile.name}');
          final imageBytes = await pickedFile.readAsBytes();
          
          final fileExt = p.extension(pickedFile.name);
          final fileName = '$imageRecordId$fileExt';
          final filePath = '$userId/${widget.journey.id}/$fileName';

          _logger.d('Uploading binary for $fileName...');
          await supabase.storage.from('journey_images').uploadBinary(
                filePath, imageBytes, fileOptions: FileOptions(contentType: pickedFile.mimeType));
          final imageUrl = supabase.storage.from('journey_images').getPublicUrl(filePath);
          _logger.d('Image uploaded to: $imageUrl');

          _logger.d('Adding initial DB reference for ID: $imageRecordId');
          await _journeyRepository.addImageReference(
            widget.journey.id,
            imageUrl,
            id: imageRecordId,
          );
          _logger.d('Initial image reference added to DB with ID: $imageRecordId');

          // --- Trigger Scan Immediately (REMOVED) --- 
          // try {
          //   _logger.i('Automatically triggering scan for new image ID: $imageRecordId');
          //   final imageBase64 = base64Encode(imageBytes); // Encode bytes for function
          //   final response = await supabase.functions.invoke(
          //     'detect-invoice-text',
          //     body: {
          //       'image_base64': imageBase64,
          //       'journey_image_id': imageRecordId,
          //     },
          //   );
          //   if (response.status == 200) {
          //     _logger.i('Auto-scan successful for $imageRecordId (results will update via Realtime).');
          //   } else {
          //     _logger.e('Auto-scan function call failed for $imageRecordId with status ${response.status}', error: response.data);
          //     // Optionally add to errorMessages or show a specific snackbar?
          //     errorMessages.add('Scan failed for ${pickedFile.name}.'); 
          //   }
          // } catch (scanError) {
          //   _logger.e('Error during auto-scan invocation for $imageRecordId', error: scanError);
          //   errorMessages.add('Scan failed for ${pickedFile.name}.'); 
          // }
          // --- End Trigger Scan (REMOVED) --- 

          successCount++;
        } catch (e) { 
          _logger.e('Error processing file ${pickedFile.name}', error: e);
          errorMessages.add('Failed to process ${pickedFile.name}.'); 
        }
      } // End for loop

      // Refresh AFTER the loop
      if (successCount > 0 || errorMessages.isNotEmpty) { 
        _logger.d('Upload loop finished, calling _loadImages...');
        await _loadImages(); 
      } else {
        _logger.d('Upload loop finished, nothing processed, skipping _loadImages.');
      }

      // Show snackbar after loop completes and refresh
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
    } finally {
       if (mounted) setState(() { _isUploading = false; });
    }
  }

  // Removed _triggerTextDetection method

  // Removed _showDetectedTextDialog method

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
        // Note: The actual removal from _journeyImages list happens
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
      body: SafeArea(child: _buildGalleryContent(theme)),
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
    if (_journeyImages.isEmpty) {
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
        itemCount: _journeyImages.length,
        itemBuilder: (context, index) {
          final imageInfo = _journeyImages[index];
          final imageUrl = imageInfo.url;
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
              // Pass the full list of JourneyImageInfo objects
              // final originalUrls = _journeyImages.map((info) => info.url).toList();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GalleryDetailView(
                    images: _journeyImages,
                    initialIndex: index,
                    logger: _logger,
                    onDeleteImage: _deleteImage,
                    onImageDeletedSuccessfully: (deletedUrl) {
                       _logger.d('GalleryDetailView reported successful deletion for: $deletedUrl');
                       // Refresh images after deletion is confirmed by the detail view
                       if (mounted) { _loadImages(); }
                    },
                  ),
                ),
              );
            },
            child: Hero(
              tag: imageUrl, 
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    child: imagePath == null
                      ? Container( // Show error if path extraction failed
                          color: theme.colorScheme.errorContainer,
                          child: Icon(Icons.broken_image, color: theme.colorScheme.onErrorContainer),
                        )
                      : FutureBuilder<String>(
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
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
} 