import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
// import 'package:supabase_flutter/supabase_flutter.dart'; // Unused import
// import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Unused import
// import 'package:travel/providers/repository_providers.dart'; // Unused import
// import 'package:travel/constants/app_routes.dart'; // Unused import
// import 'journey_gallery_screen.dart'; // Unused import

import '../models/journey.dart';
// import '../repositories/journey_repository.dart'; // Unused import

class JourneyDetailScreen extends ConsumerStatefulWidget {
  final Journey journey;

  const JourneyDetailScreen({super.key, required this.journey});

  @override
  ConsumerState<JourneyDetailScreen> createState() => _JourneyDetailScreenState();
}

class _JourneyDetailScreenState extends ConsumerState<JourneyDetailScreen> {
  // late JourneyRepository _journeyRepository; // Unused field

  // Unused fields related to image loading (handled differently now?)
  // bool _isLoadingImages = true;
  // String? _imageError;
  // List<String> _imageUrls = [];
  final _dateFormat = DateFormat('dd/MM/yyyy');
  
  @override
  void initState() {
    super.initState();
    // _loadImages();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // _journeyRepository = ref.read(journeyRepositoryProvider);
    // _loadImages();
  }

  // Unused method
  // Future<void> _loadImages() async {
  //   if (!mounted) return;
  //   setState(() {
  //     _isLoadingImages = true;
  //     _imageError = null;
  //   });

  //   try {
  //     final urls = await _journeyRepository.fetchJourneyImages(widget.journey.id);
  //     if (mounted) {
  //       setState(() {
  //         _imageUrls = urls;
  //         _isLoadingImages = false;
  //       });
  //     }
  //   } catch (e) {
  //     print('Failed to load images error: $e');
  //     if (mounted) {
  //       setState(() {
  //         _imageError = 'Failed to load images';
  //         _isLoadingImages = false;
  //       });
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final l10n = AppLocalizations.of(context)!; // Unused variable

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.pop(),
        ),
        title: Text(widget.journey.title),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.journey.title,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                widget.journey.description,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Text(
                'Location: ${widget.journey.location}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Dates: ${_dateFormat.format(widget.journey.startDate)} - ${_dateFormat.format(widget.journey.endDate)}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Budget: \$${widget.journey.budget.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
