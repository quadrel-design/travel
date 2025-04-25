import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travel/providers/repository_providers.dart';
import 'package:travel/constants/app_routes.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // For localized text

class AuthWaitScreen extends ConsumerStatefulWidget {
  const AuthWaitScreen({super.key});

  @override
  ConsumerState<AuthWaitScreen> createState() => _AuthWaitScreenState();
}

class _AuthWaitScreenState extends ConsumerState<AuthWaitScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startVerificationCheck();
  }

  @override
  void dispose() {
    _timer?.cancel(); // Important: Cancel timer to avoid memory leaks
    super.dispose();
  }

  void _startVerificationCheck() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final authRepo = ref.read(authRepositoryProvider);
      final user = authRepo.currentUser;

      if (user == null) {
        _timer?.cancel();
        // Should not happen ideally, but handle gracefully
        if (mounted) context.go(AppRoutes.auth);
        return;
      }

      await user.reload(); // Refresh user data from Firebase
      final refreshedUser =
          authRepo.currentUser; // Get the refreshed user object

      if (refreshedUser != null && refreshedUser.emailVerified) {
        _timer?.cancel();
        if (mounted) {
          // Navigate to home or dashboard upon successful verification
          context.go(AppRoutes.home);
        }
      }
      // Otherwise, the timer continues...
    });
  }

  Future<void> _resendVerificationEmail() async {
    final authRepo = ref.read(authRepositoryProvider);
    final user = authRepo.currentUser;
    final l10n = AppLocalizations.of(context)!;

    if (user != null && !user.emailVerified) {
      try {
        await authRepo.sendVerificationEmail();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.verificationEmailResent)), // Use l10n
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('${l10n.errorResendingVerification}: $e')), // Use l10n
          );
        }
      }
    }
  }

  Future<void> _signOut() async {
    final authRepo = ref.read(authRepositoryProvider);
    try {
      await authRepo.signOut();
      if (mounted) {
        context.go(AppRoutes.auth); // Go back to auth screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign out failed: $e')), // Placeholder
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                onPressed: _resendVerificationEmail,
                child: Text(l10n.resendEmailButton), // Use l10n
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _signOut, // Allow user to go back
                child: Text(l10n.cancelButton), // Use l10n
              ),
            ],
          ),
        ),
      ),
    );
  }
}
