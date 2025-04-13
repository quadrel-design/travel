import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_title.dart';
import '../repositories/auth_repository.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/constants/app_routes.dart';

class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({Key? key}) : super(key: key);

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final authRepository = ref.read(authRepositoryProvider);
    try {
      print('[AppSettings] Signing out...');
      await authRepository.signOut();
      if (context.mounted) {
        context.go(AppRoutes.auth);
      }
    } on AuthException catch (e) {
      print('Error logging out from settings: ${e.message}');
      if (context.mounted) {
         ShadToaster.of(context).show(
            ShadToast.destructive(
              title: Text(l10n.logoutErrorTitle), 
              description: Text(e.message)
            ),
         );
      }
    } catch (e) {
       print('Unexpected error logging out from settings: $e');
       if (context.mounted) {
         ShadToaster.of(context).show(
            ShadToast.destructive(
              title: Text(l10n.errorTitle), 
              description: Text(l10n.logoutUnexpectedErrorDesc)
            ),
         );
       }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final l10n = AppLocalizations.of(context)!;

    Widget buildSettingsTile({
      required IconData leadingIcon,
      required String title,
      required VoidCallback onTap,
    }) {
      return ListTile(
        leading: Icon(leadingIcon, color: theme.colorScheme.foreground),
        title: Text(title, style: theme.textTheme.p),
        trailing: Icon(LucideIcons.chevronRight, color: theme.colorScheme.mutedForeground),
        onTap: onTap,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: ShadButton.ghost(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.go(AppRoutes.home),
          padding: EdgeInsets.zero,
        ),
        title: const Text('App Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          Text(
            l10n.settingsGroupTitle,
            style: theme.textTheme.list.copyWith(/*...*/),
          ),
          const SizedBox(height: 16),
          buildSettingsTile(
            leadingIcon: LucideIcons.bookmark,
            title: l10n.settingsItemSaved,
            onTap: () { print('Saved tapped'); },
          ),
          buildSettingsTile(
            leadingIcon: LucideIcons.archive,
            title: l10n.settingsItemArchive,
            onTap: () { print('Archive tapped'); },
          ),
          buildSettingsTile(
            leadingIcon: LucideIcons.activity,
            title: l10n.settingsItemActivity,
            onTap: () { print('Activity tapped'); },
          ),
          buildSettingsTile(
            leadingIcon: LucideIcons.bell,
            title: l10n.settingsItemNotifications,
            onTap: () { print('Notifications tapped'); },
          ),
          buildSettingsTile(
            leadingIcon: LucideIcons.timer,
            title: l10n.settingsItemTimeManagement,
            onTap: () { print('Time Management tapped'); },
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Divider(color: theme.colorScheme.border),
          ),
          buildSettingsTile(
            leadingIcon: LucideIcons.logOut,
            title: l10n.settingsItemLogout,
            onTap: () => _handleLogout(context, ref),
          ),
        ],
      ),
    );
  }
}
