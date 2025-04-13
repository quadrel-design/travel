import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:go_router/go_router.dart';
import '../widgets/app_title.dart'; // Import AppTitle
import '../constants/app_colors.dart'; // Import color constants
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import generated class
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:travel/providers/repository_providers.dart'; // Import providers
import 'package:travel/constants/app_routes.dart'; // Import routes

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
       print('DEBUG: Pre-filled Auth fields.');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Forgot Password Handler ---
  Future<void> _handleForgotPassword() async {
    final l10n = AppLocalizations.of(context)!;
    // Read repository using ref
    final authRepository = ref.read(authRepositoryProvider);
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ShadToaster.of(context).show(
        ShadToast.destructive(
          title: Text(l10n.missingInfoTitle),
          description: Text(l10n.enterEmailFirstDesc),
        ),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      // Construct redirect URL - ideally base URL from env
      final redirectUri = kIsWeb ? Uri.parse('http://localhost:3000/update-password') : null;
      final redirectTo = redirectUri?.toString();

      print('[AuthScreen] Sending password reset email to: $email with redirect: $redirectTo');
      await authRepository.resetPasswordForEmail(email, redirectTo: redirectTo);
      print('[AuthScreen] Password reset email request successful.');
      if (mounted) {
        ShadToaster.of(context).show(
           ShadToast(
            title: Text(l10n.passwordResetEmailSentTitle),
            description: Text(l10n.passwordResetEmailSentDesc),
          ),
        );
      }
    } on AuthException catch (e) {
       print('Error logging out: ${e.message}'); // Log detailed error
       String localizedTitle = l10n.errorTitle;
       String localizedDesc = l10n.passwordResetFailedDesc;
       if (mounted) {
          ShadToaster.of(context).show(
            ShadToast.destructive(
              title: Text(localizedTitle),
              description: Text(localizedDesc),
            ),
          );
       }
    } catch (e) {
       print('Unexpected error during password reset: $e'); // Log detailed error
       if (mounted) {
          ShadToaster.of(context).show(
             ShadToast.destructive(
              title: Text(l10n.errorTitle),
              description: Text(l10n.logoutUnexpectedErrorDesc), // Used logout error here, might need specific one
            ),
          );
       }
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }
  // --- End Forgot Password Handler ---

  Future<void> _handleLogout() async { // Assuming logout might be added back later
     // ... logic ...
       if (mounted) {
         context.go(AppRoutes.auth); // Use constant
       }
     // ...
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    // Read repository using ref
    final authRepository = ref.read(authRepositoryProvider);
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return; // Errors shown by ShadInputFormField
    }
    
    setState(() { _isLoading = true; });
    FocusScope.of(context).unfocus();

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      
      if (_isSignUp) {
          print('[AuthScreen] Attempting Sign Up for: $email');
          await authRepository.signUp(email, password);
          print('[AuthScreen] Sign Up call completed.');
          if (mounted) {
             ShadToaster.of(context).show(
                 ShadToast(
                  title: Text(l10n.signUpSuccessTitle),
                  description: Text(l10n.signUpSuccessDesc),
                ),
             );
            _formKey.currentState?.reset();
            _emailController.clear();
            _passwordController.clear();
          }
      } else {
        print('[AuthScreen] Attempting Sign In for: $email');
        await authRepository.signInWithPassword(email, password);
        print('[AuthScreen] Sign In call completed WITHOUT throwing.');
        if (mounted) {
          print('[AuthScreen] Sign In Successful, navigating...');
          context.go(AppRoutes.home); // Use constant
        }
      }
    } on AuthException catch (e) {
      print('[AuthScreen] AuthException during submit: ${e.message}'); // Log detailed error
      String localizedTitle = l10n.authErrorTitle;
      String localizedDesc = e.message; // Default to raw message
      if (_isSignUp && e.message.toLowerCase().contains('user already registered')) {
          localizedTitle = l10n.emailRegisteredTitle;
          localizedDesc = l10n.emailRegisteredDesc;
      } else if (!_isSignUp && e.message.toLowerCase().contains('email not confirmed')) {
        localizedDesc = l10n.emailNotConfirmedDesc;
      } else if (!_isSignUp && e.message.toLowerCase().contains('invalid login credentials')) {
         localizedTitle = l10n.signInFailedTitle;
         localizedDesc = l10n.invalidLoginCredentialsDesc;
      } 
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(title: Text(localizedTitle), description: Text(localizedDesc)),
        );
      }
    } catch (e) {
       print('[AuthScreen] Caught Generic Exception during submit: $e'); // Log detailed error
       if (mounted) {
         ShadToaster.of(context).show(
           ShadToast.destructive(
             title: Text(l10n.errorTitle),
             description: Text(l10n.unexpectedErrorDesc),
           ),
         );
       }
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    // Define the switch button widget separately
    final switchAuthModeButton = !_isLoading
        ? ShadButton.link(
            onPressed: () {
              setState(() {
                _isSignUp = !_isSignUp;
                _formKey.currentState?.reset();
                _emailController.clear();
                _passwordController.clear();
              });
            },
            // Wrap Text with Flexible to encourage wrapping
            child: Flexible( 
              child: Text(
                _isSignUp
                    ? 'Already have an account? Sign In'
                    : 'Don\'t have an account? Sign Up',
                 // softWrap: true, // Should be true by default
              ),
            ),
          )
        : const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        // Use the reusable AppTitle widget
        title: const AppTitle(), 
      ),
      // Wrap body with Container for background image
      body: Container(
        // Set constraints to fill the screen
        constraints: const BoxConstraints.expand(),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/travel_wallpaper.png'),
            fit: BoxFit.cover, // Make image cover the whole area
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            // Add a semi-transparent overlay container for readability?
            child: Container(
              constraints: const BoxConstraints(minWidth: 400, maxWidth: 600),
              padding: const EdgeInsets.all(24.0),
              // Add background color to form container for readability
              decoration: BoxDecoration(
                color: Colors.white,
                // Use constant for border color
                border: Border.all(color: AppColors.borderGrey),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Replace ShadInput with ShadInputFormField
                    ShadInputFormField(
                      id: 'email',
                      controller: _emailController,
                      label: const Text('Email'),
                      placeholder: const Text('Enter your email'), // Optional
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty || !v.contains('@')) {
                          return 'Please enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // Replace ShadInput with ShadInputFormField
                    ShadInputFormField(
                      id: 'password',
                      controller: _passwordController,
                      label: const Text('Password'),
                      placeholder: const Text('Enter your password'), // Optional
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.trim().length < 6) {
                          return 'Password must be at least 6 characters long.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20), // Space before error/button
                    
                    // --- Button Section --- 
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      // Main Action Button (Sign In/Sign Up)
                      ShadButton(
                        onPressed: _submit,
                        child: Text(_isSignUp ? 'Sign Up' : 'Sign In'),
                      ),
                      const SizedBox(height: 12), // Spacing
                      
                      // Forgot Password Button (Left Aligned, conditional)
                      if (!_isSignUp)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ShadButton.link(
                            onPressed: _handleForgotPassword,
                            child: const Text('Forgot Password?'),
                            // Optional: Reduce padding for tighter alignment
                            // padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                          ),
                        ),
                        // Add spacing only if Forgot Password button was shown
                      if (!_isSignUp) const SizedBox(height: 8),

                      // Mode Switch Button (Left Aligned, conditional)
                      Align(
                         alignment: Alignment.centerLeft,
                         child: switchAuthModeButton,
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
