import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
// import '../providers/repository_providers.dart'; // Remove unused import
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logger/logger.dart';

class ProjectSettingsScreen extends ConsumerStatefulWidget {
  final Project project;

  const ProjectSettingsScreen({super.key, required this.project});

  @override
  ConsumerState<ProjectSettingsScreen> createState() =>
      _ProjectSettingsScreenState();
}

class _ProjectSettingsScreenState extends ConsumerState<ProjectSettingsScreen> {
  bool _isDeleting = false;
  final _logger = Logger();

  Future<void> _askDeleteConfirmation(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final currentContext = context;
    final projectTitle = widget.project.title;

    final bool? confirmed = await showDialog<bool>(
      context: currentContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.projectDeleteConfirmTitle),
          content: Text(l10n.projectDeleteConfirmDesc(projectTitle)),
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
        _deleteProject(currentContext);
      }
    }
  }

  Future<void> _deleteProject(BuildContext capturedContext) async {
    final scaffoldMessenger = ScaffoldMessenger.of(capturedContext);
    final l10n = AppLocalizations.of(capturedContext)!;
    final navigator = Navigator.of(capturedContext);
    final theme = Theme.of(capturedContext);
    final projectTitle = widget.project.title;

    if (!mounted) return;
    setState(() {
      _isDeleting = true;
    });

    try {
      // final projectRepository = ref.read(projectRepositoryProvider); // Comment out repo access
      // await projectRepository.deleteproject(widget.project.id); // Comment out delete call
      _logger.i('Simulated successful project delete: ${widget.project.id}');
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      navigator.pop();
      navigator.pop();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(l10n.projectDeleteSuccess(projectTitle)),
          backgroundColor: theme.colorScheme.primary,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content:
              Text(l10n.projectDeleteErrorDesc({'error': error.toString()})),
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
        title: Text(l10n.projectSettingsTitle),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.delete),
            title: Text(l10n.projectDeleteLabel),
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
