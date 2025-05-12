import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/constants/app_routes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:travel/providers/logging_provider.dart';
import 'package:travel/providers/service_providers.dart' as service_providers;

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

    // Watch the project stream for real-time updates
    final projectStream = ref.watch(invoiceStreamProvider(project.id));

    final imagesStream = ref.watch(
      invoiceImagesStreamProvider(
          {'projectId': project.id, 'invoiceId': invoiceId}),
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
                                                      invoiceId),
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
      InvoiceImageProcess image, String invoiceId) async {
    try {
      final logger = ref.read(loggerProvider);
      logger.d(
          "🔍 Starting OCR scan for image ${image.id} using Cloud Run service...");

      // First update status to ocr_running
      try {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('projects')
            .doc(project.id)
            .collection('budgets')
            .doc(budgetId)
            .collection('invoices')
            .doc(invoiceId)
            .collection('invoice_images')
            .doc(image.id);

        await docRef.update({
          'status': 'ocr_running',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        logger.d("🔍 Status updated to ocr_running");
      } catch (updateError) {
        logger.e("🔍 Error updating status to ocr_running", error: updateError);
        // Continue even if this fails
      }

      // Call the OCR service via CloudRunOcrService
      final ocrService = ref.read(service_providers.cloudRunOcrServiceProvider);

      // Ensure all required parameters are available and correct
      // CloudRunOcrService.scanImage expects:
      // String imagePath, String projectId, String invoiceId, String imageId

      logger.d(
          "🔍 Calling Cloud Run OCR endpoint with imagePath: ${image.imagePath}, projectId: ${project.id}, invoiceId: $invoiceId, imageId: ${image.id}");

      final result = await ocrService.scanImage(
        image.imagePath, // imagePath from InvoiceImageProcess
        project.id, // projectId from the current project
        invoiceId, // invoiceId passed to _scanImage
        image.id, // imageId from InvoiceImageProcess
      );

      // Process the result if needed, e.g., update UI based on result.success
      logger.i("🔍 OCR processing via Cloud Run completed. Result: $result");

      if (context.mounted) {
        // Example: Show a message based on the 'status' or 'success' field in the result
        String message = "OCR processing completed.";
        if (result.containsKey('success') && result['success'] == true) {
          message =
              result['message'] as String? ?? "OCR successful via Cloud Run.";
          // Potentially, update local state or re-fetch data if OCR modifies data significantly
        } else {
          message = result['error'] as String? ?? "OCR failed via Cloud Run.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final logger = ref.read(loggerProvider);
        logger.e("🔍 Error during Cloud Run OCR process", error: e);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during OCR: ${e.toString()}')),
        );
      }

      // Try to reset status on error
      try {
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection('projects')
            .doc(project.id)
            .collection('budgets')
            .doc(budgetId)
            .collection('invoices')
            .doc(invoiceId)
            .collection('invoice_images')
            .doc(image.id);

        await docRef.update({
          'status': 'ready',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Ignore errors when resetting status
      }
    }
  }
}
