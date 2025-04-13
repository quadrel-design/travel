import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_title.dart';
import '../repositories/auth_repository.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({Key? key}) : super(key: key);

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {

  final AuthRepository _authRepository = AuthRepository();

  Future<void> _handleLogout() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      print('[UserSettings] Signing out...');
      await _authRepository.signOut();
      if (mounted) {
        context.go('/auth');
      }
    } on AuthException catch (e) {
      print('Error logging out from settings: ${e.message}');
      if (mounted) {
         ShadToaster.of(context).show(
            ShadToast.destructive(
              title: Text(l10n.logoutErrorTitle), 
              description: Text(e.message)
            ),
         );
      }
    } catch (e) {
       print('Unexpected error logging out from settings: $e');
       if (mounted) {
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
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final materialTheme = Theme.of(context);

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
          onPressed: () => context.go('/home'),
          padding: EdgeInsets.zero,
        ),
        title: const Text('App Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        children: [
          buildSettingsTile(
            leadingIcon: LucideIcons.bookmark,
            title: 'Saved',
            onTap: () { print('Saved tapped'); },
          ),
          buildSettingsTile(
            leadingIcon: LucideIcons.archive,
            title: 'Archive',
            onTap: () { print('Archive tapped'); },
          ),
          buildSettingsTile(
            leadingIcon: LucideIcons.activity,
            title: 'Your Activity',
            onTap: () { print('Activity tapped'); },
          ),
          buildSettingsTile(
            leadingIcon: LucideIcons.bell,
            title: 'Notifications',
            onTap: () { print('Notifications tapped'); },
          ),
          buildSettingsTile(
            leadingIcon: LucideIcons.timer,
            title: 'Time Management',
            onTap: () { print('Time Management tapped'); },
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Divider(color: theme.colorScheme.border),
          ),
          buildSettingsTile(
            leadingIcon: LucideIcons.logOut,
            title: 'Logout',
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }
}
