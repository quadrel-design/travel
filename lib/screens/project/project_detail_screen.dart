import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/constants/app_routes.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:travel/providers/logging_provider.dart';
import '../../models/project.dart';
import '../../models/invoice_image_process.dart';

class ProjectDetailScreen extends ConsumerWidget {
  final Project project;
  final String invoiceId;
  final String budgetId;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  ProjectDetailScreen({
    super.key,
    required this.project,
    required this.invoiceId,
    required this.budgetId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final logger = ref.watch(loggerProvider);

    // Watch the project stream for real-time updates
    final projectStream = ref.watch(projectStreamProvider(project.id));

    // The 'invoiceId' parameter passed to ProjectDetailScreen is used here.
    // However, the invoiceImagesStreamProvider now only takes projectId.
    // This discrepancy needs to be resolved. For now, using project.id.
    final String streamIdToUse = project.id;
    logger.d(
        '[ProjectDetailScreen] Using project ID for imagesStream: $streamIdToUse (original invoiceId was: $invoiceId)');

    final imagesStream = ref.watch(
      projectImagesStreamProvider(
          streamIdToUse), // Changed to projectImagesStreamProvider and using project.id
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.pop(),
        ),
        title: Text(project.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () =>
                context.push('${AppRoutes.projectSettings}/${project.id}'),
          ),
        ],
      ),
      body: projectStream.when(
        data: (Project? currentProject) {
          if (currentProject == null) {
            return Center(
              child: Text(l10n.projectNotFound),
            );
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentProject.title,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentProject.description,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Location: ${currentProject.location}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Dates: ${_dateFormat.format(currentProject.startDate)} - ${_dateFormat.format(currentProject.endDate)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Budget: \$${currentProject.budget.toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.invoiceImages,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      imagesStream.when(
                        data: (List<InvoiceImageProcess> images) {
                          if (images.isEmpty) {
                            return Center(
                              child: Text(l10n.noImagesYet),
                            );
                          }
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: images.length,
                            itemBuilder: (context, index) {
                              final image = images[index];
                              return FutureBuilder<String?>(
                                future: ref
                                    .read(authRepositoryProvider)
                                    .currentUser
                                    ?.getIdToken(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                          ConnectionState.waiting ||
                                      !snapshot.hasData ||
                                      snapshot.data == null) {
                                    return const Card(
                                      clipBehavior: Clip.antiAlias,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.0),
                                      ),
                                    );
                                  }

                                  if (snapshot.hasError) {
                                    return const Card(
                                      clipBehavior: Clip.antiAlias,
                                      child: Center(
                                          child: Icon(Icons.error_outline)),
                                    );
                                  }

                                  final token = snapshot.data!;
                                  final headers = {
                                    'Authorization': 'Bearer $token'
                                  };

                                  return GestureDetector(
                                    onTap: () => context.push(
                                      '${AppRoutes.invoiceImageDetail}/${project.id}/${image.id}',
                                      extra: image,
                                    ),
                                    child: Hero(
                                      tag: image.id,
                                      child: Card(
                                        clipBehavior: Clip.antiAlias,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            CachedNetworkImage(
                                              imageUrl: image.url,
                                              httpHeaders: headers,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) =>
                                                  const Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth:
                                                                  2.0)),
                                              errorWidget: (context, url,
                                                      error) =>
                                                  const Center(
                                                      child: Icon(Icons.error)),
                                            ),
                                            Positioned(
                                              bottom: 8,
                                              right: 8,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withAlpha(
                                                      (0.5 * 255).toInt()),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: IconButton(
                                                  icon: const Icon(
                                                      Icons.document_scanner,
                                                      size: 20,
                                                      color: Colors.white),
                                                  onPressed: () => _scanImage(
                                                      context,
                                                      ref,
                                                      image,
                                                      project
                                                          .id // Pass project.id as it's the relevant identifier now
                                                      ),
                                                  tooltip: 'Scan Invoice',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                        loading: () => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        error: (error, stack) => Center(
                          child: Text(
                            'Error loading images: $error',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Text(
            'Error loading project: $error',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            context.push('${AppRoutes.invoiceCapture}/${project.id}'),
        tooltip: l10n.addImage,
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }

  Future<void> _scanImage(BuildContext context, WidgetRef ref,
      InvoiceImageProcess image, String currentProjectId) async {
    final logger = ref.read(loggerProvider);
    logger.i('Scanning image ${image.id} for project $currentProjectId');
    // final scaffoldMessenger = ScaffoldMessenger.of(context);
    // final l10n = AppLocalizations.of(context)!;

    try {
      // final gcsService = ref.read(service_providers.gcsFileServiceProvider);
      // final imageUrl = await gcsService.getPublicUrl(image.imagePath);
      // if (imageUrl == null) {
      //   throw Exception('Could not get image public URL.');
      // }

      // Placeholder for actual scanning logic that would interact with a backend service
      // This service would take the image details (e.g., its GCS path or ID)
      // and trigger the OCR/analysis process.

      // Example: calling a repository method that hits your backend /analyze-invoice endpoint
      // final invoiceRepo = ref.read(invoiceRepositoryProvider);
      // await invoiceRepo.analyzeInvoiceImage(currentProjectId, image.id);

      logger.i(
          '_scanImage: Placeholder for backend analysis call for image ${image.id} in project $currentProjectId');
      // scaffoldMessenger.showSnackBar(
      //   SnackBar(content: Text(l10n.imageScanInitiated(image.originalFilename ?? l10n.thisImage))),
      // );

      // Commenting out direct Firestore updates as they are no longer valid
      /*
      final userId = ref.read(firebaseAuthProvider).currentUser?.uid;
      if (userId == null) {
        throw Exception(l10n.userNotAuthenticated);
      }

      // Assuming 'projects' is the correct top-level collection for projects if using Firestore elsewhere
      // This logic is Firestore-specific and should be replaced by backend calls.
      await FirebaseFirestore.instance
          .collection('users') // Or your top-level user collection
          .doc(userId)
          .collection('projects')
          .doc(currentProjectId) // Use currentProjectId which is project.id
          .collection('images') // Assuming a subcollection for images
          .doc(image.id)
          .update({
        'status': 'analysis_pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.imageSubmittedForAnalysis(image.originalFilename ?? l10n.thisImage))),
      );
      */
    } catch (e, stackTrace) {
      logger.e('Error scanning image ${image.id}:',
          error: e, stackTrace: stackTrace);
      // scaffoldMessenger.showSnackBar(
      //   SnackBar(content: Text(l10n.errorScanningImage(e.toString()))),
      // );
    }
  }

  // Commenting out Firestore-specific delete method
  /*
  Future<void> _deleteProjectImage(BuildContext context, WidgetRef ref, InvoiceImageProcess image) async {
    final logger = ref.read(loggerProvider);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    try {
      final userId = ref.read(firebaseAuthProvider).currentUser?.uid;
      if (userId == null) {
        throw Exception(l10n.userNotAuthenticated);
      }
      // final gcsService = ref.read(service_providers.gcsFileServiceProvider);
      // await gcsService.deleteFile(fileName: image.imagePath);
      
      // This is Firestore-specific logic for deleting the metadata
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('projects')
          .doc(project.id) // project.id is the projectId
          .collection('images')
          .doc(image.id)
          .delete();

      // Also delete any related expenses or other sub-collections if necessary (Firestore specific)
      // Example: Delete expenses subcollection (if it exists for this image)
      // final expensesCollection = FirebaseFirestore.instance
      //     .collection('users') 
      //     .doc(userId)
      //     .collection('projects')
      //     .doc(project.id)
      //     .collection('images')
      //     .doc(image.id)
      //     .collection('expenses');
      // final expensesSnapshot = await expensesCollection.get();
      // for (var doc in expensesSnapshot.docs) {
      //   await expensesCollection.doc(doc.id).delete();
      // }

      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.imageDeletedSuccessfully(image.originalFilename ?? l10n.thisImage))),
      );
      logger.i('Image ${image.id} and its GCS file ${image.imagePath} deleted successfully.');

    } catch (e, stackTrace) {
      logger.e('Error deleting image ${image.id}:', error: e, stackTrace: stackTrace);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.errorDeletingImage(e.toString()))),
      );
    }
  }
  */
}
