import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../widgets/app_title.dart'; // Import AppTitle
import '../constants/app_colors.dart'; // Import color constants
import 'package:flutter_gen/gen_l10n/app_localizations.dart'; // Import generated class
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:travel/providers/repository_providers.dart'; // Import providers
import 'package:travel/constants/app_routes.dart'; // Import routes
import 'package:travel/widgets/form_field_group.dart'; // Import the helper widget

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
     ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Hide previous ones
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
             Text(message),
           ],
         ),
         backgroundColor: Theme.of(context).colorScheme.error,
       ),
     );
   }
   void _showSuccessSnackBar(BuildContext context, String title, String message) {
     ScaffoldMessenger.of(context).hideCurrentSnackBar();
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
             Text(message),
           ],
         ),
         // Use primary or secondary color for success?
         backgroundColor: Theme.of(context).colorScheme.primary, 
       ),
     );
   }

  // --- Forgot Password Handler ---
  Future<void> _handleForgotPassword() async {
    final l10n = AppLocalizations.of(context)!;
    // Read repository using ref
    final authRepository = ref.read(authRepositoryProvider);
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showErrorSnackBar(context, l10n.missingInfoTitle, l10n.enterEmailFirstDesc);
      return;
    }

    setState(() { _isLoading = true; });

    try {
      // Construct redirect URL - ideally base URL from env
      final redirectUri = kIsWeb ? Uri.parse('http://localhost:3000/update-password') : null;
      final redirectTo = redirectUri?.toString();

      await authRepository.resetPasswordForEmail(email, redirectTo: redirectTo);
      if (mounted) {
        _showSuccessSnackBar(context, l10n.passwordResetEmailSentTitle, l10n.passwordResetEmailSentDesc);
      }
    } on AuthException {
      // print('[AuthScreen] AuthException during password reset: ${e.message}'); // Log detailed error
      String localizedTitle = l10n.errorTitle;
      String localizedDesc = l10n.passwordResetFailedDesc;
      if (mounted) {
         _showErrorSnackBar(context, localizedTitle, localizedDesc);
      }
    } catch (_) {
       // Error ignored during password reset attempt (already handled by showing snackbar)
       if (mounted) {
          _showErrorSnackBar(context, l10n.errorTitle, l10n.logoutUnexpectedErrorDesc);
       }
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }
  // --- End Forgot Password Handler ---

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    // Read repository using ref
    final authRepository = ref.read(authRepositoryProvider);
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return; // Errors shown by TextFormField
    }
    
    setState(() { _isLoading = true; });
    FocusScope.of(context).unfocus();

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      
      if (_isSignUp) {
          await authRepository.signUp(email, password);
          if (mounted) {
             _showSuccessSnackBar(context, l10n.signUpSuccessTitle, l10n.signUpSuccessDesc);
            _formKey.currentState?.reset();
            _emailController.clear();
            _passwordController.clear();
          }
      } else {
        await authRepository.signInWithPassword(email, password);
        if (mounted) {
          context.go(AppRoutes.home); // Use constant
        }
      }
    } on AuthException catch (e) {
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
        _showErrorSnackBar(context, localizedTitle, localizedDesc);
      }
    } catch (_) {
       if (mounted) {
         _showErrorSnackBar(context, l10n.errorTitle, l10n.unexpectedErrorDesc);
       }
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  @override
  Widget build(BuildContext context) {
    // final errorColor = Theme.of(context).colorScheme.error; // Unused variable

    // Define the switch button widget separately
    final switchAuthModeButton = !_isLoading
        ? TextButton(
            onPressed: () {
              setState(() {
                _isSignUp = !_isSignUp;
                _formKey.currentState?.reset();
                _emailController.clear();
                _passwordController.clear();
              });
            },
            child: Text(
              _isSignUp
                  ? 'Already have an account? Sign In'
                  : 'Don\'t have an account? Sign Up',
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
                    // --- Email Field ---
                    FormFieldGroup(
                      label: 'Email', // TODO: Localize
                      child: TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          // Remove labelText
                          hintText: 'Enter your email',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textCapitalization: TextCapitalization.none,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty || !value.contains('@')) {
                            return 'Please enter a valid email address.';
                          }
                          return null;
                        },
                      ),
                      // No description needed for email typically
                    ),
                    const SizedBox(height: 16), // Increase spacing between fields
                    
                    // --- Password Field ---
                    FormFieldGroup(
                      label: 'Password', // TODO: Localize
                      child: TextFormField(
                        controller: _passwordController,
                         decoration: const InputDecoration(
                          // Remove labelText
                          hintText: 'Enter your password',
                        ),
                        obscureText: true,
                        validator: (value) {
                           if (value == null || value.trim().length < 6) {
                            return 'Password must be at least 6 characters long.';
                          }
                          return null;
                        },
                      ),
                      // No description needed for password typically
                    ),
                    const SizedBox(height: 20),
                    
                    // --- Button Section --- 
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      // Main Action Button (Sign In/Sign Up)
                      ElevatedButton(
                        onPressed: _submit,
                        child: Text(_isSignUp ? 'Sign Up' : 'Sign In'),
                      ),
                      const SizedBox(height: 12), // Spacing
                      
                      // Forgot Password Button (Left Aligned, conditional)
                      if (!_isSignUp)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _handleForgotPassword,
                            child: const Text('Forgot Password?'),
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
