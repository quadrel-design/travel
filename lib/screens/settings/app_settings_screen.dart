import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:travel/constants/app_routes.dart';
import 'package:travel/providers/repository_providers.dart';
// import 'package:travel/repositories/auth_repository.dart'; // Unused import
// import 'package:travel/widgets/app_title.dart'; // Unused import
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  // Helper SnackBar methods (or move to utils)
  void _showErrorSnackBar(BuildContext context, String title, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(message)]), backgroundColor: Theme.of(context).colorScheme.error));
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final authRepository = ref.read(authRepositoryProvider);
    try {
      await authRepository.signOut();
      if (context.mounted) {
        context.go(AppRoutes.auth);
      }
    } on AuthException catch (e) {
      if (context.mounted) {
        _showErrorSnackBar(context, l10n.logoutErrorTitle, e.message);
      }
    } catch (e) {
       if (context.mounted) {
         _showErrorSnackBar(context, l10n.errorTitle, l10n.logoutUnexpectedErrorDesc);
       }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Use standard ListTile - styling from theme
    Widget buildSettingsTile({
      required IconData leadingIcon,
      required String title,
      required VoidCallback onTap,
    }) {
      return ListTile(
        leading: Icon(leadingIcon, color: theme.colorScheme.onSurfaceVariant),
        title: Text(title),
        trailing: Icon(Icons.chevron_right, color: theme.colorScheme.outline),
        onTap: onTap,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left), 
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.go(AppRoutes.home),
        ),
        title: const Text('App Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              l10n.settingsGroupTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          buildSettingsTile(
            leadingIcon: Icons.bookmark_border,
            title: l10n.settingsItemSaved,
            onTap: () { },
          ),
          buildSettingsTile(
            leadingIcon: Icons.archive_outlined,
            title: l10n.settingsItemArchive,
            onTap: () { },
          ),
          buildSettingsTile(
            leadingIcon: Icons.history_outlined,
            title: l10n.settingsItemActivity,
            onTap: () { },
          ),
          buildSettingsTile(
            leadingIcon: Icons.notifications_none,
            title: l10n.settingsItemNotifications,
            onTap: () { },
          ),
          buildSettingsTile(
            leadingIcon: Icons.timer_outlined,
            title: l10n.settingsItemTimeManagement,
            onTap: () { /* print('Time Management tapped'); */ },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Divider(color: theme.colorScheme.outline.withAlpha(128)),
          ),
          buildSettingsTile(
            leadingIcon: Icons.logout,
            title: l10n.settingsItemLogout,
            onTap: () => _handleLogout(context, ref),
          ),
        ],
      ),
    );
  }
}
