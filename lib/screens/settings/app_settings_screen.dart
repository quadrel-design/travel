import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// import 'package:supabase_flutter/supabase_flutter.dart'; // Remove unused import
// import 'package:travel/l10n/l10n_provider.dart'; // Remove this import
import 'package:travel/constants/app_routes.dart';
import 'package:travel/providers/repository_providers.dart';
// import 'package:travel/providers/test_data_provider.dart'; // Remove incorrect import
// import 'package:travel/utils/app_colors.dart'; // Remove incorrect import
// import 'package:travel/widgets/confirm_dialog.dart'; // Remove incorrect import
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Add this for l10n

class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  // Helper SnackBar methods (or move to utils)
  void _showErrorSnackBar(BuildContext context, String title, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(message)
            ]),
        backgroundColor: Theme.of(context).colorScheme.error));
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!; // Get l10n
    try {
      await ref.read(authRepositoryProvider).signOut();
      // Navigate to auth screen after sign out
      if (context.mounted) {
        // Use goNamed for clarity if routes are named
        context.go(AppRoutes.auth); // Adjust if route name is different
      }
      // Replace specific Supabase exception with generic catch
    } catch (e) {
      // Handle sign-out errors (e.g., show a snackbar)
      if (context.mounted) {
        // Use the error snackbar function if available, or standard SnackBar
        _showErrorSnackBar(context, l10n.logoutErrorTitle, e.toString());
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('${l10n.logoutErrorTitle}: $e')),
        // );
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
          // Account Settings Section
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
            onTap: () {},
          ),
          buildSettingsTile(
            leadingIcon: Icons.archive_outlined,
            title: l10n.settingsItemArchive,
            onTap: () {},
          ),
          buildSettingsTile(
            leadingIcon: Icons.history_outlined,
            title: l10n.settingsItemActivity,
            onTap: () {},
          ),
          buildSettingsTile(
            leadingIcon: Icons.notifications_none,
            title: l10n.settingsItemNotifications,
            onTap: () {},
          ),
          buildSettingsTile(
            leadingIcon: Icons.timer_outlined,
            title: l10n.settingsItemTimeManagement,
            onTap: () {/* print('Time Management tapped'); */},
          ),

          // Logout Section
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Divider(color: theme.colorScheme.outline.withAlpha(128)),
          ),
          buildSettingsTile(
            leadingIcon: Icons.logout,
            title: l10n.settingsItemLogout,
            onTap: () => _signOut(context, ref),
          ),
        ],
      ),
    );
  }
}
