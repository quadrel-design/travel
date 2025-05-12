/// Authentication Screen
///
/// Provides the UI for user authentication, handling login, registration,
/// password reset, and email verification flows using Riverpod for state management.
library;

import 'dart:async'; // Added for Timer
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Import generated class
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:logger/logger.dart'; // Import logger
import 'package:travel/providers/repository_providers.dart'; // Import providers
import 'package:travel/providers/auth_providers.dart'; // Import auth specific providers
import 'package:travel/providers/logging_provider.dart'; // Import logger provider
// Import routes
// Import Firebase Auth (needed for error types maybe)
import 'package:firebase_auth/firebase_auth.dart'; // Needed for FirebaseAuthException

// Change to ConsumerStatefulWidget
/// The main screen widget for handling user authentication.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  // Change State link
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

// Change to ConsumerState
/// State class for the [AuthScreen] widget.
class _AuthScreenState extends ConsumerState<AuthScreen> {
  // Key for the login/signup form
  final _formKey = GlobalKey<FormState>();
  // Controller for the email input field
  final _emailController = TextEditingController();
  // Controller for the password input field
  final _passwordController = TextEditingController();
  // Logger instance obtained from provider
  late Logger _logger; // Initialize in initState

  // Local state for password visibility
  bool _obscurePassword = true;

  // Timer for email verification check
  Timer? _verificationTimer;

  @override
  void initState() {
    super.initState();
    _logger = ref.read(loggerProvider); // Initialize logger
    if (kDebugMode) {
      _emailController.text = dotenv.env['DEV_EMAIL'] ?? '';
      _passwordController.text = dotenv.env['DEV_PASSWORD'] ?? '';
    }
    // Check initial auth state for verification wait
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authNavigationProvider);
      if (authState == AuthNavigationState.waitForVerification) {
        _startVerificationTimer(ref);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _verificationTimer?.cancel(); // Cancel timer on dispose
    super.dispose();
  }

  /// Starts a periodic timer to check the user's email verification status.
  void _startVerificationTimer(WidgetRef ref) {
    _verificationTimer?.cancel(); // Cancel any existing timer
    _logger.d('Starting email verification check timer.');
    // Check immediately and then periodically
    _checkEmailVerificationStatus(ref);
    _verificationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _logger.d('Periodic email verification check running...');
      _checkEmailVerificationStatus(ref);
    });
  }

  /// Checks the email verification status of the current user.
  /// Reloads the user and cancels the timer if verified.
  void _checkEmailVerificationStatus(WidgetRef ref) async {
    final currentUser = ref.read(authRepositoryProvider).currentUser;
    if (currentUser != null &&
        _verificationTimer != null &&
        _verificationTimer!.isActive) {
      try {
        // Show loading indicator while checking
        ref.read(authLoadingProvider.notifier).state = true;
        await currentUser.reload();
        final freshUser = ref
            .read(authRepositoryProvider)
            .currentUser; // Re-fetch after reload
        if (freshUser != null && freshUser.emailVerified) {
          _logger.i('Email verified for ${freshUser.email}');
          _verificationTimer?.cancel();
          // Let GoRouter handle navigation via auth state change
          // ref.read(authNavigationProvider.notifier).state = AuthNavigationState.login; // No need to manually set state
          ref.read(authErrorProvider.notifier).state = null; // Clear any errors
        } else {
          _logger
              .d('Email verification still pending for ${currentUser.email}');
        }
      } catch (e) {
        // <-- FIX: Reverted back to catch (e)
        // Error during reload or verification check
        // No need to show error to user unless it's persistent
        // ref.read(authErrorProvider.notifier).state = e.toString(); // Keep this commented if e isn't used for user message
        _logger.e('Email verification check failed',
            error: e); // <-- FIX: Log the actual error 'e'
      } finally {
        // Always stop loading indicator after check attempt
        if (mounted) {
          ref.read(authLoadingProvider.notifier).state = false;
        }
      }
    } else {
      _logger.w('Verification check skipped: User null or timer inactive.');
      // Optionally cancel timer if user becomes null
      if (currentUser == null) {
        _verificationTimer?.cancel();
      }
      ref.read(authErrorProvider.notifier).state =
          'User is not logged in or timer not active.';
    }
  }

  /// Handles the sign-in process using email and password.
  /// Validates the form, calls the auth repository, and updates state providers.
  void _signInWithEmailAndPassword(BuildContext context, WidgetRef ref) async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      ref.read(authLoadingProvider.notifier).state = true;
      ref.read(authErrorProvider.notifier).state = null;
      try {
        // Use only Firebase Auth via your repository/provider
        await ref.read(authRepositoryProvider).signInWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );
        _logger.d(
            'Current user after login: ${FirebaseAuth.instance.currentUser}');
        _logger.i(
            'Sign in attempt successful for ${_emailController.text.trim()}');
      } on FirebaseAuthException catch (e) {
        // Catch specific Firebase exception
        _logger.e('Sign in failed', error: e);
        String errorMessage = 'An unknown error occurred.'; // Default message
        // Provide more specific user-friendly messages
        if (e.code == 'user-not-found' ||
            e.code == 'wrong-password' ||
            e.code == 'invalid-credential') {
          errorMessage = 'Invalid email or password.';
        } else if (e.code == 'user-disabled') {
          errorMessage = 'This user account has been disabled.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'The email address is not valid.';
        }
        ref.read(authErrorProvider.notifier).state = errorMessage;
      } catch (e) {
        // Generic catch for other errors
        _logger.e('Sign in failed with unexpected error', error: e);
        ref.read(authErrorProvider.notifier).state =
            'An unexpected error occurred during sign in.';
      } finally {
        // Ensure loading state is reset even if widget is disposed during async operation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(authLoadingProvider.notifier).state = false;
          }
        });
      }
    }
  }

  /// Handles the registration process using email and password.
  /// Validates the form, calls the auth repository to create user and send verification,
  /// and updates state providers, including navigating to the verification wait state.
  void _registerWithEmailAndPassword(
      BuildContext context, WidgetRef ref) async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      ref.read(authLoadingProvider.notifier).state = true;
      ref.read(authErrorProvider.notifier).state =
          null; // Clear previous errors
      try {
        await ref.read(authRepositoryProvider).createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );
        await ref.read(authRepositoryProvider).sendVerificationEmail();
        _logger.i(
            'Registration attempt successful for ${_emailController.text.trim()}, verification sent.');
        ref.read(authNavigationProvider.notifier).state =
            AuthNavigationState.waitForVerification;
        _startVerificationTimer(ref);
      } on FirebaseAuthException catch (e) {
        // Catch specific Firebase exception
        _logger.e('Registration failed', error: e);
        String errorMessage = 'An unknown error occurred.'; // Default message
        if (e.code == 'weak-password') {
          errorMessage = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = 'An account already exists for that email.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'The email address is not valid.';
        }
        ref.read(authErrorProvider.notifier).state = errorMessage;
      } catch (e) {
        // Generic catch
        _logger.e('Registration failed with unexpected error', error: e);
        ref.read(authErrorProvider.notifier).state =
            'An unexpected error occurred during registration.';
      } finally {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(authLoadingProvider.notifier).state = false;
          }
        });
      }
    }
  }

  /// Handles the password reset process for the entered email.
  /// Validates the email, calls the auth repository, and shows feedback via SnackBar.
  void _resetPassword(BuildContext context, WidgetRef ref) async {
    // Use email from controller
    final email = _emailController.text.trim();
    // Capture context-dependent objects BEFORE await
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final focusScope = FocusScope.of(context);

    final emailRegExp = RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    if (email.isEmpty || !emailRegExp.hasMatch(email)) {
      ref.read(authErrorProvider.notifier).state =
          'Please enter a valid email address to reset password.';
      return;
    }

    ref.read(authLoadingProvider.notifier).state = true;
    ref.read(authErrorProvider.notifier).state = null;
    try {
      await ref.read(authRepositoryProvider).resetPasswordForEmail(email);
      // Add specific check right before using context after await
      if (mounted) {
        // Use captured scaffoldMessenger
        scaffoldMessenger.showSnackBar(
          const SnackBar(
              content:
                  Text('Password reset email sent. Please check your inbox.')),
        );
        // Use captured focusScope
        focusScope.unfocus(); // Hide keyboard
      }
      _logger.i('Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      // Catch specific Firebase exception
      _logger.e('Password reset failed for $email', error: e);
      String errorMessage = 'An unknown error occurred.'; // Default message
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found for that email.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email address is not valid.';
      }
      ref.read(authErrorProvider.notifier).state = errorMessage;
      // Add check here before showing potential SnackBar for specific errors (optional)
      if (mounted) {
        // Use captured scaffoldMessenger if showing snackbar here
        // scaffoldMessenger.showSnackBar(...);
      }
    } catch (e) {
      // Generic catch
      _logger.e('Password reset failed for $email with unexpected error',
          error: e);
      ref.read(authErrorProvider.notifier).state =
          'An unexpected error occurred.';
      // Add specific check right before using context after await (error case)
      if (mounted) {
        // Use captured scaffoldMessenger
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Failed to send password reset email.')),
        );
      }
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(authLoadingProvider.notifier).state = false;
        }
      });
    }
  }

  // Method to toggle password visibility
  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  /// Builds the main UI based on the current [AuthNavigationState].
  @override
  Widget build(BuildContext context) {
    // final l10n = AppLocalizations.of(context)!; // L10N_COMMENT_OUT
    final currentAuthState = ref.watch(authNavigationProvider);
    final isLoading = ref.watch(authLoadingProvider);
    final errorMessage = ref.watch(authErrorProvider);

    // Determine if showing login or sign up form
    bool showLoginForm = currentAuthState == AuthNavigationState.login;
    bool showWaitScreen =
        currentAuthState == AuthNavigationState.waitForVerification;

    return Scaffold(
      // Use a simple AppBar for wait screen
      appBar: showWaitScreen
          // ? AppBar(title: Text(l10n.verifyEmailTitle)) // L10N_COMMENT_OUT
          ? AppBar(title: const Text('Verify Email')) // Placeholder
          : AppBar(
              // title: Text(l10n.appName),
              title: const Text('Travel App'), // Placeholder
              centerTitle: true,
            ),
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/travel_wallpaper.png'),
            fit: BoxFit.cover,
          ),
        ),
        alignment: Alignment.center,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                elevation: 4.0,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: showWaitScreen
                      ? _buildWaitForVerification(
                          context, ref, errorMessage, isLoading)
                      : _buildAuthForm(
                          context, ref, showLoginForm, isLoading, errorMessage),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the UI for the Login form.
  Widget _buildAuthForm(BuildContext context, WidgetRef ref, bool isLogin,
      bool isLoading, String? errorMessage) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Error Message Display ---
          if (errorMessage != null && !isLoading)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                errorMessage,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),

          // --- Email Field ---
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              // labelText: l10n.emailLabel,
              labelText: 'Email', // Placeholder
              // hintText: l10n.emailHint,
              hintText: 'Enter your email', // Placeholder
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            validator: (value) {
              if (value == null ||
                  value.trim().isEmpty ||
                  !value.contains('@')) {
                // return l10n.emailValidationError;
                return 'Please enter a valid email address.'; // Placeholder
              }
              return null;
            },
            onSaved: (value) {
              // No need to save to separate variable if using controller directly
            },
          ),
          const SizedBox(height: 16),

          // --- Password Field ---
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              // labelText: l10n.passwordLabel,
              labelText: 'Password', // Placeholder
              // hintText: l10n.passwordHint,
              hintText: 'Enter your password', // Placeholder
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                // Added suffix icon
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: _togglePasswordVisibility,
              ),
            ),
            obscureText: _obscurePassword, // Use local state
            validator: (value) {
              if (value == null || value.trim().length < 6) {
                // return l10n.passwordValidationError;
                return 'Password must be at least 6 characters long.'; // Placeholder
              }
              return null;
            },
            onSaved: (value) {
              // No need to save to separate variable if using controller directly
            },
          ),
          const SizedBox(height: 24),

          // --- Submit Button ---
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            ElevatedButton(
              onPressed: () => isLogin
                  ? _signInWithEmailAndPassword(context, ref)
                  : _registerWithEmailAndPassword(context, ref),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(isLogin ? 'Sign In' : 'Sign Up'), // Placeholder
            ),

            const SizedBox(height: 16),

            // --- OR Divider ---
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('OR'),
                ),
                Expanded(child: Divider()),
              ],
            ),

            const SizedBox(height: 16),

            // --- Google Sign In Button ---
            ElevatedButton.icon(
              onPressed: () {
                _signInWithGoogle(context, ref);
              },
              icon: Image.asset(
                'assets/images/google_signin_logo.png',
                height: 24,
              ),
              label: const Text('Sign in with Google'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // --- Auth Mode Switch Button ---
          if (!isLoading)
            TextButton(
              onPressed: () {
                // Toggle between Login and SignUp states
                ref.read(authNavigationProvider.notifier).state = isLogin
                    ? AuthNavigationState.signUp
                    : AuthNavigationState.login;
                _formKey.currentState?.reset();
                ref.read(authErrorProvider.notifier).state =
                    null; // Clear errors on switch
                if (!kDebugMode) {
                  _emailController.clear();
                  _passwordController.clear();
                }
              },
              // child: Text(isLogin ? l10n.signUpPrompt : l10n.signInPrompt),
              child: Text(isLogin
                  ? 'Need an account? Sign up'
                  : 'Have an account? Sign in'), // Placeholder
            ),

          // --- Forgot Password Button ---
          if (isLogin && !isLoading) // Show only in login mode
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: TextButton(
                onPressed: () => _resetPassword(context, ref),
                // child: Text(l10n.forgotPasswordButton),
                child: const Text('Forgot Password?'), // Placeholder
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the UI shown while waiting for email verification.
  Widget _buildWaitForVerification(BuildContext context, WidgetRef ref,
      String? errorMessage, bool isLoading) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Text(l10n.verifyEmailTitle, style: Theme.of(context).textTheme.headlineSmall), // L10N_COMMENT_OUT
        Text('Verify Your Email',
            style: Theme.of(context).textTheme.headlineSmall), // Placeholder
        const SizedBox(height: 16),
        Text(
            // l10n.verifyEmailMessage(_emailController.text.isNotEmpty ? _emailController.text : 'your email address'), // L10N_COMMENT_OUT
            'A verification link has been sent to ${_emailController.text.isNotEmpty ? _emailController.text : 'your email address'}. Please check your inbox and click the link.', // Placeholder
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        // --- Error Message Display ---
        if (errorMessage != null && !isLoading)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              errorMessage,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        if (isLoading) const CircularProgressIndicator(),
        if (!isLoading)
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            // label: Text(l10n.checkVerificationButton), // L10N_COMMENT_OUT
            label: const Text('Check Verification Status'), // Placeholder
            onPressed: () => _checkEmailVerificationStatus(ref),
          ),
        const SizedBox(height: 12),
        if (!isLoading)
          TextButton(
            onPressed: () async {
              // Resend verification email
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              ref.read(authLoadingProvider.notifier).state = true;
              ref.read(authErrorProvider.notifier).state = null;
              try {
                await ref.read(authRepositoryProvider).sendVerificationEmail();
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Verification email resent.')),
                  );
                }
              } catch (e) {
                _logger.e("Error resending verification email", error: e);
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                        content: Text('Failed to resend verification email.')),
                  );
                }
                ref.read(authErrorProvider.notifier).state =
                    "Failed to resend email.";
              } finally {
                if (mounted) {
                  ref.read(authLoadingProvider.notifier).state = false;
                }
              }
            },
            // child: Text(l10n.resendVerificationEmailButton), // L10N_COMMENT_OUT
            child: const Text('Resend Verification Email'), // Placeholder
          ),
        const SizedBox(height: 12),
        if (!isLoading)
          TextButton(
            // Button to go back to Login
            onPressed: () {
              _verificationTimer?.cancel(); // Stop timer
              ref.read(authNavigationProvider.notifier).state =
                  AuthNavigationState.login;
              ref.read(authErrorProvider.notifier).state = null; // Clear errors
            },
            // child: Text(l10n.backToLoginButton), // L10N_COMMENT_OUT
            child: const Text('Back to Login'), // Placeholder
          ),
      ],
    );
  }

  // Add Google Sign In Method
  void _signInWithGoogle(BuildContext context, WidgetRef ref) async {
    ref.read(authLoadingProvider.notifier).state = true;
    ref.read(authErrorProvider.notifier).state = null;

    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      _logger.i('Google sign in successful');
    } on FirebaseAuthException catch (e) {
      _logger.e('Google sign in failed', error: e);
      String errorMessage = 'An unknown error occurred.';

      if (e.code == 'account-exists-with-different-credential') {
        errorMessage = 'An account already exists with this email.';
      } else if (e.code == 'invalid-credential') {
        errorMessage = 'Invalid credentials.';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'This account has been disabled.';
      } else if (e.code == 'ERROR_ABORTED_BY_USER') {
        errorMessage = 'Sign in cancelled by user.';
      }

      ref.read(authErrorProvider.notifier).state = errorMessage;
    } catch (e) {
      _logger.e('Unexpected error during Google sign in', error: e);
      ref.read(authErrorProvider.notifier).state =
          'An unexpected error occurred during Google sign in.';
    } finally {
      if (mounted) {
        ref.read(authLoadingProvider.notifier).state = false;
      }
    }
  }
}
