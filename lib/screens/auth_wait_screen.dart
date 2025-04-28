/// Auth Wait Screen
///
/// Displays a screen while waiting for the user to verify their email address.
/// Provides options to resend the verification email or sign out.
/// Relies on the global authentication state listener (e.g., in GoRouter)
/// to navigate away once the email is verified.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/constants/app_routes.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // For localized text

/// A screen shown to the user after registration, prompting them to verify their email.
///
/// This screen does not actively check for verification itself but relies on the
/// global auth state listener (in GoRouter redirect) to navigate away once the
/// user's `emailVerified` status becomes true.
class AuthWaitScreen extends ConsumerWidget {
  const AuthWaitScreen({super.key});

  /// Handles the action to resend the verification email.
  Future<void> _resendVerificationEmail(
      BuildContext context, WidgetRef ref) async {
    final authRepo = ref.read(authRepositoryProvider);
    final user = authRepo.currentUser;
    final l10n = AppLocalizations.of(context)!;

    if (user != null && !user.emailVerified) {
      try {
        await authRepo.sendVerificationEmail();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.verificationEmailResent)), // Use l10n
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${l10n.errorResendingVerification}: $e')), // Use l10n
        );
      }
    }
  }

  /// Handles the sign out action.
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final authRepo = ref.read(authRepositoryProvider);
    try {
      await authRepo.signOut();
      context.go(AppRoutes.auth); // Go back to auth screen
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign out failed: $e')), // Placeholder
      );
    }
  }

  /// Builds the UI for the Auth Wait screen.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.verifyEmailTitle), // Use l10n
        automaticallyImplyLeading: false, // Remove back button
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 32),
              Text(
                l10n.verificationEmailSentTitle, // Use l10n
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.checkYourEmailInstruction, // Use l10n
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () => _resendVerificationEmail(context, ref),
                child: Text(l10n.resendEmailButton), // Use l10n
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    _signOut(context, ref), // Allow user to go back
                child: Text(l10n.cancelButton), // Use l10n
              ),
            ],
          ),
        ),
      ),
    );
  }
}
