import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
// Import AppTitle
// Import color constants
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import generated class
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:travel/providers/repository_providers.dart'; // Import providers
import 'package:travel/constants/app_routes.dart'; // Import routes
// Import the helper widget

// Change to ConsumerStatefulWidget
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  // Change State link
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

// Change to ConsumerState
class _AuthScreenState extends ConsumerState<AuthScreen> {
  // Re-introduce Form key
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false; // Start in Sign In mode
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      // Access dotenv directly, no context needed here
      _emailController.text = dotenv.env['DEV_EMAIL'] ?? '';
      _passwordController.text = dotenv.env['DEV_PASSWORD'] ?? '';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Helper to show SnackBar
  void _showErrorSnackBar(BuildContext context, String title, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        // Simpler content for standard Material
        content: Text('$title: $message'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccessSnackBar(
      BuildContext context, String title, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        // Simpler content for standard Material
        content: Text('$title: $message'),
        backgroundColor:
            Theme.of(context).colorScheme.primary, // Or another success color
      ),
    );
  }

  // --- Forgot Password Handler ---
  Future<void> _handleForgotPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final authRepository = ref.read(authRepositoryProvider);
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      // Use the simpler snackbar helper
      _showErrorSnackBar(
          context, l10n.missingInfoTitle, l10n.enterEmailFirstDesc);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final redirectUri =
          kIsWeb ? Uri.parse('http://localhost:3000/update-password') : null;
      final redirectTo = redirectUri?.toString();

      await authRepository.resetPasswordForEmail(email, redirectTo: redirectTo);
      if (mounted) {
        // Use the simpler snackbar helper
        _showSuccessSnackBar(context, l10n.passwordResetEmailSentTitle,
            l10n.passwordResetEmailSentDesc);
      }
    } on AuthException {
      String localizedTitle = l10n.errorTitle;
      String localizedDesc = l10n.passwordResetFailedDesc;
      if (mounted) {
        _showErrorSnackBar(context, localizedTitle, localizedDesc);
      }
    } catch (_) {
      if (mounted) {
        _showErrorSnackBar(
            context, l10n.errorTitle, l10n.logoutUnexpectedErrorDesc);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  // --- End Forgot Password Handler ---

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final authRepository = ref.read(authRepositoryProvider);
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() {
      _isLoading = true;
    });
    FocusScope.of(context).unfocus();

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (_isSignUp) {
        await authRepository.signUp(email, password);
        if (mounted) {
          _showSuccessSnackBar(
              context, l10n.signUpSuccessTitle, l10n.signUpSuccessDesc);
          // Keep optional logic
          // _formKey.currentState?.reset();
          // _emailController.clear();
          // _passwordController.clear();
        }
      } else {
        await authRepository.signInWithPassword(email, password);
        if (mounted) {
          context.go(AppRoutes.home);
        }
      }
    } on AuthException catch (e) {
      String localizedTitle = l10n.authErrorTitle;
      String localizedDesc = e.message; // Default to raw message
      // Keep specific error message handling
      if (_isSignUp &&
          e.message.toLowerCase().contains('user already registered')) {
        localizedTitle = l10n.emailRegisteredTitle;
        localizedDesc = l10n.emailRegisteredDesc;
      } else if (!_isSignUp &&
          e.message.toLowerCase().contains('email not confirmed')) {
        localizedDesc = l10n.emailNotConfirmedDesc;
      } else if (!_isSignUp &&
          e.message.toLowerCase().contains('invalid login credentials')) {
        localizedTitle = l10n.signInFailedTitle;
        localizedDesc = l10n.invalidLoginCredentialsDesc;
      }
      if (mounted) {
        _showErrorSnackBar(context, localizedTitle, localizedDesc);
      }
    } catch (_) {
      if (mounted) {
        _showErrorSnackBar(context, l10n.errorTitle, l10n.unexpectedErrorDesc);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        // Replace custom AppTitle with standard Text
        title: Text(l10n.appName), // Ensure l10n.appName exists
        centerTitle: true, // Keep centered
      ),
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/travel_wallpaper.png'),
            fit: BoxFit.cover,
          ),
        ),
        alignment: Alignment.center, // Center content
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            // Replace custom Container with Material Card
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 400), // Typical max width
              child: Card(
                elevation: 4.0,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- Email Field (Standard TextFormField) ---
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            // Use standard labels/hints/icons
                            labelText: l10n.emailLabel, // Ensure key exists
                            hintText: l10n.emailHint, // Ensure key exists
                            prefixIcon: const Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          textCapitalization: TextCapitalization.none,
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty ||
                                !value.contains('@')) {
                              // Ensure key exists
                              return l10n.emailValidationError;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // --- Password Field (Standard TextFormField) ---
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            // Use standard labels/hints/icons
                            labelText: l10n.passwordLabel, // Ensure key exists
                            hintText: l10n.passwordHint, // Ensure key exists
                            prefixIcon: const Icon(Icons.lock),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.trim().length < 6) {
                              // Ensure key exists
                              return l10n.passwordValidationError;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // --- Submit Button (Standard ElevatedButton) ---
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                                onPressed: _submit,
                                style: ElevatedButton.styleFrom(
                                  // Optional standard styling
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                // Ensure keys exist
                                child: Text(_isSignUp
                                    ? l10n.signUpButton
                                    : l10n.signInButton),
                              ),
                        const SizedBox(height: 12),

                        // --- Auth Mode Switch Button (Standard TextButton) ---
                        if (!_isLoading)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isSignUp = !_isSignUp;
                                _formKey.currentState?.reset();
                                // Keep filled dev creds if switching
                                if (!kDebugMode) {
                                  _emailController.clear();
                                  _passwordController.clear();
                                }
                              });
                            },
                            // Ensure keys exist
                            child: Text(_isSignUp
                                ? l10n.signInPrompt
                                : l10n.signUpPrompt),
                          ),

                        // --- Forgot Password Button (Standard TextButton) ---
                        if (!_isSignUp && !_isLoading)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: TextButton(
                              onPressed: _handleForgotPassword,
                              // Ensure key exists
                              child: Text(l10n.forgotPasswordButton),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
