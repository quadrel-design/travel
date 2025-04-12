import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:go_router/go_router.dart';

// Convert to StatefulWidget
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

// Create State class
class _AuthScreenState extends State<AuthScreen> {
  // Re-introduce Form key
  final _formKey = GlobalKey<FormState>(); 
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false; // Start in Sign In mode
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill will now happen as the initial mode is Sign In
    _emailController.text = 'chris.wickmann@gmail.com';
    _passwordController.text = 'Amcath1011!';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Forgot Password Handler ---
  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ShadToaster.of(context).show(
        ShadToast.destructive(
          title: const Text('Missing Information'),
          description: const Text('Please enter your email address first.'),
        ),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      print('[AuthScreen] Sending password reset email to: $email');
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? 'http://localhost:3000/update-password' : null,
      );
      print('[AuthScreen] Password reset email request successful.');
      if (mounted) {
        ShadToaster.of(context).show(
          const ShadToast(
            title: Text('Check Your Email'),
            description: Text('Password reset email sent! Please check your inbox.'),
          ),
        );
      }
    } on AuthException catch (e) {
       print('[AuthScreen] Password reset failed: ${e.message}');
       String displayMessage = 'Could not send reset email. Please try again.';
       if (mounted) {
          ShadToaster.of(context).show(
            ShadToast.destructive(
              title: const Text('Error'),
              description: Text(displayMessage),
            ),
          );
       }
    } catch (e) {
      print('[AuthScreen] Unexpected error during password reset: $e');
       if (mounted) {
          ShadToaster.of(context).show(
             ShadToast.destructive(
              title: const Text('Error'),
              description: const Text('An unexpected error occurred.'),
            ),
          );
       }
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }
  // --- End Forgot Password Handler ---

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return; // Errors shown by ShadInputFormField
    }
    
    setState(() { _isLoading = true; });
    FocusScope.of(context).unfocus();

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final supabase = Supabase.instance.client;

      if (_isSignUp) {
        // --- REMOVE Pre-Sign Up Check --- 
        // print('[AuthScreen] Checking if user exists: $email');
        // try {
        //    ... (RPC call) ...
        // } catch (rpcError) {
        //   ... (RPC error handling) ...
        //   return; 
        // }
        // if (userExists) {
        //   ... (show existing user toast) ...
        // } else { 
        // --- Directly attempt Sign Up --- 
          print('[AuthScreen] Attempting Sign Up for: $email');
          await supabase.auth.signUp(email: email, password: password);
          print('[AuthScreen] Sign Up call completed.');
          if (mounted) {
             ShadToaster.of(context).show(
                const ShadToast(
                  title: Text('Sign Up Successful'),
                  description: Text('Please check your email to confirm.'),
                ),
             );
            _formKey.currentState?.reset();
            _emailController.clear();
            _passwordController.clear();
          }
        // }
      } else {
        // --- Sign In Logic --- 
        print('[AuthScreen] Attempting Sign In for: $email');
        await supabase.auth.signInWithPassword(email: email, password: password);
        print('[AuthScreen] Sign In call completed WITHOUT throwing.');
        if (mounted) {
          print('[AuthScreen] Sign In Successful, navigating...');
          context.go('/home'); 
        }
      }
    } on AuthException catch (e) {
      print('[AuthScreen] Caught AuthException: ${e.message}');
      String displayTitle = 'Authentication Error';
      String displayMessage = e.message;
      // --- Add handling for user already exists during sign up --- 
      if (_isSignUp && e.message.toLowerCase().contains('user already registered')) {
          displayTitle = 'Email Registered';
          displayMessage = 'This email is already registered. Please sign in instead.';
      } else if (!_isSignUp && e.message.toLowerCase().contains('email not confirmed')) {
        displayMessage = 'Please confirm your email before signing in.';
      } else if (!_isSignUp && e.message.toLowerCase().contains('invalid login credentials')) {
         displayTitle = 'Sign In Failed';
         displayMessage = 'Incorrect email or password.';
      } 
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: Text(displayTitle),
            description: Text(displayMessage),
          ),
        );
      }
    } catch (e) {
       print('[AuthScreen] Caught Generic Exception: $e');
       if (mounted) {
         ShadToaster.of(context).show(
           ShadToast.destructive(
             title: const Text('Error'),
             description: const Text('An unexpected error occurred. Please try again.'),
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

    // Define the switch button widget separately for clarity
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
            child: Text(
              _isSignUp
                  ? 'Already have an account? Sign In'
                  : 'Don\'t have an account? Sign Up',
            ),
          )
        : const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('TravelMouse'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Container( // Keep the outer container for styling
            constraints: const BoxConstraints(minWidth: 400, maxWidth: 600),
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              // borderRadius: BorderRadius.zero, // Keep sharp corners if desired
            ),
            child: Form( // Add Form widget back
              key: _formKey, // Assign the key
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
                  // --- Buttons Row (remains the same) ---
                   if (_isLoading)
                     const Center(child: CircularProgressIndicator())
                   else
                     Padding(
                        padding: const EdgeInsets.only(top: 8.0), // Add some space above the button row
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center, // Center the buttons horizontally
                          children: [
                            // Forgot Password Button (only in Sign In mode)
                            if (!_isSignUp) ...[
                              // Replace TextButton with ShadButton.link
                              ShadButton.link(
                                onPressed: _handleForgotPassword,
                                child: const Text('Forgot Password?'),
                              ),
                              const SizedBox(width: 24), // Space between buttons
                            ],
                            // Replace ElevatedButton with ShadButton
                            ShadButton(
                              onPressed: _submit,
                              child: Text(_isSignUp ? 'Sign Up' : 'Sign In'),
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: 12), // Space before the switch mode button
                  // --- Switch Mode Button (remains the same) ---
                  if (!_isLoading) switchAuthModeButton,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
