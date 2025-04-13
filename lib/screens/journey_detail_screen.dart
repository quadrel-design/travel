import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/constants/app_routes.dart';

import '../models/journey.dart';
import '../repositories/journey_repository.dart';
import '../repositories/auth_repository.dart';

class JourneyDetailScreen extends ConsumerStatefulWidget {
  final Journey journey;

  const JourneyDetailScreen({Key? key, required this.journey})
      : super(key: key);

  @override
  ConsumerState<JourneyDetailScreen> createState() => _JourneyDetailScreenState();
}

class _JourneyDetailScreenState extends ConsumerState<JourneyDetailScreen> {
  late JourneyRepository _journeyRepository;
  final AuthRepository _authRepository = AuthRepository();

  bool _isLoadingImages = true;
  String? _imageError;
  List<String> _imageUrls = [];
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _journeyRepository = ref.read(journeyRepositoryProvider);
  }

  Future<void> _loadImages() async {
    if (!mounted) return;
    setState(() {
      _isLoadingImages = true;
      _imageError = null;
    });

    try {
      final urls = await _journeyRepository.fetchJourneyImages(widget.journey.id);
      if (mounted) {
        setState(() {
          _imageUrls = urls;
          _isLoadingImages = false;
        });
      }
    } catch (e) {
      print('Failed to load images error: $e');
      if (mounted) {
        setState(() {
          _imageError = 'Failed to load images';
          _isLoadingImages = false;
        });
      }
    }
  }

  Future<void> _deleteJourney() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this journey?'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      await _journeyRepository.deleteJourney(widget.journey.id);

      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast(description: Text(l10n.journeyDeleteSuccessDesc)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: Text(l10n.errorTitle),
            description: Text(l10n.journeyDeleteErrorDesc(e)),
          ),
        );
      }
    }
  }

  void _editJourney() {
    final l10n = AppLocalizations.of(context)!;
    ShadToaster.of(context).show(
      ShadToast(description: Text(l10n.editNotImplementedDesc)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.journey.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Journey',
            onPressed: _editJourney,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete Journey',
            onPressed: _deleteJourney,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoadingImages)
              const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            else if (_imageError != null)
               Container(
                 height: 200,
                 color: Colors.red[100],
                 child: Center(child: Text(_imageError!, style: const TextStyle(color: Colors.red))),
               )
            else if (_imageUrls.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageUrls.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.network(
                        _imageUrls[index],
                        fit: BoxFit.cover,
                        width: 200,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.broken_image, size: 50);
                        },
                      ),
                    );
                  },
                ),
              )
            else
               Container(
                 height: 200,
                 color: Colors.grey[200],
                 child: const Center(child: Text('No images for this journey yet')),
               ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.journey.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.journey.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Location: ${widget.journey.location}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dates: ${_dateFormat.format(widget.journey.start_date)} - ${_dateFormat.format(widget.journey.end_date)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Budget: \$${widget.journey.budget.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
