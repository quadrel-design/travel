import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/constants/app_routes.dart';

import '../models/journey.dart';
import '../models/invoice_capture_process.dart';

class JourneyDetailScreen extends ConsumerWidget {
  final Journey journey;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  JourneyDetailScreen({super.key, required this.journey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Watch the journey stream for real-time updates
    final journeyStream = ref.watch(journeyStreamProvider(journey.id));

    // Watch the journey images stream
    final imagesStream = ref.watch(invoiceImagesStreamProvider(journey.id));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.pop(),
        ),
        title: Text(journey.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () =>
                context.push('${AppRoutes.journeySettings}/${journey.id}'),
          ),
        ],
      ),
      body: journeyStream.when(
        data: (Journey? currentJourney) {
          if (currentJourney == null) {
            return Center(
              child: Text(l10n.journeyNotFound),
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
                        currentJourney.title,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentJourney.description,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Location: ${currentJourney.location}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Dates: ${_dateFormat.format(currentJourney.startDate)} - ${_dateFormat.format(currentJourney.endDate)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Budget: \$${currentJourney.budget.toStringAsFixed(2)}',
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
                        data: (List<InvoiceCaptureProcess> images) {
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
                              return GestureDetector(
                                onTap: () => context.push(
                                  '${AppRoutes.invoiceImageDetail}/${currentJourney.id}/${image.id}',
                                  extra: image,
                                ),
                                child: Hero(
                                  tag: image.id,
                                  child: Card(
                                    clipBehavior: Clip.antiAlias,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.network(
                                          image.url,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Center(
                                                      child: Icon(Icons.error)),
                                        ),
                                        if (image.status != null)
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme
                                                    .primaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                image.status!,
                                                style:
                                                    theme.textTheme.labelSmall,
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
            'Error loading journey: $error',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            context.push('${AppRoutes.invoiceCapture}/${journey.id}'),
        tooltip: l10n.addImage,
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
}
