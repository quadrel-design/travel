import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/journey.dart';
import '../providers/repository_providers.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class JourneySettingsScreen extends ConsumerStatefulWidget {
  final Journey journey;

  const JourneySettingsScreen({super.key, required this.journey});

  @override
  ConsumerState<JourneySettingsScreen> createState() =>
      _JourneySettingsScreenState();
}

class _JourneySettingsScreenState extends ConsumerState<JourneySettingsScreen> {
  bool _isDeleting = false;

  Future<void> _askDeleteConfirmation(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final currentContext = context;
    final journeyTitle = widget.journey.title;

    final bool? confirmed = await showDialog<bool>(
      context: currentContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.journeyDeleteConfirmTitle),
          content: Text(l10n.journeyDeleteConfirmDesc(journeyTitle)),
          actions: <Widget>[
            TextButton(
              child: Text(l10n.cancelButton),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text(l10n.deleteButton),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      if (currentContext.mounted) {
        _deleteJourney(currentContext);
      }
    }
  }

  Future<void> _deleteJourney(BuildContext capturedContext) async {
    final scaffoldMessenger = ScaffoldMessenger.of(capturedContext);
    final l10n = AppLocalizations.of(capturedContext)!;
    final navigator = Navigator.of(capturedContext);
    final theme = Theme.of(capturedContext);
    final journeyTitle = widget.journey.title;

    if (!mounted) return;
    setState(() {
      _isDeleting = true;
    });

    try {
      await ref
          .read(journeyRepositoryProvider)
          .deleteJourney(widget.journey.id);
      if (!mounted) return;

      navigator.pop();
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(l10n.journeyDeleteSuccess(journeyTitle)),
          backgroundColor: theme.colorScheme.primary,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(l10n.journeyDeleteErrorDesc(error.toString())),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.journeySettingsTitle),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.delete),
            title: Text(l10n.journeyDeleteLabel),
            subtitle: _isDeleting ? Text(l10n.deletingProgress) : null,
            enabled: !_isDeleting,
            trailing: _isDeleting ? const CircularProgressIndicator() : null,
            onTap: _isDeleting ? null : () => _askDeleteConfirmation(context),
          ),
        ],
      ),
    );
  }
}
