import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Convert to StatefulWidget
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

// Create State class
class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = true; // Start in Sign Up mode
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final supabase = Supabase.instance.client;

      if (_isSignUp) {
        // --- Pre-Sign Up Check --- 
        print('[AuthScreen] Checking if user exists: $email');
        bool userExists = false;
        try {
          final result = await supabase.rpc(
            'check_user_exists', // Name of the SQL function created
            params: {'email_arg': email},
          );
          // Ensure result is treated as boolean
          userExists = (result as bool?) ?? false; 
          print('[AuthScreen] User exists check result: $userExists');
        } catch (rpcError) {
          print('[AuthScreen] RPC check_user_exists failed: $rpcError');
          // Show a generic error if the check fails and stop
          if (mounted) {
              setState(() { 
                 _errorMessage = 'Could not verify email. Please try again.'; 
              });
          }
          // Ensure loading is stopped in finally block
          return; 
        }

        if (userExists) {
          // --- User Found - Show SnackBar and stop --- 
          print('[AuthScreen] User already exists, showing SnackBar.');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This email is already registered. Please sign in instead.'),
                backgroundColor: Colors.orangeAccent,
              ),
            );
          }
          // Don't clear form, allow user to switch to sign in
        } else {
          // --- User Not Found - Proceed with Sign Up --- 
          print('[AuthScreen] User does not exist, proceeding with signUp.');
          await supabase.auth.signUp(
            email: email,
            password: password,
          );
          print('[AuthScreen] Sign Up call completed.');
          // Show confirmation SnackBar
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sign-up successful! Please check your email to confirm.'),
                backgroundColor: Colors.green,
              ),
            );
            _formKey.currentState?.reset();
            _emailController.clear();
            _passwordController.clear();
          }
        }
      } else {
        // --- Sign In Logic --- 
        print('[AuthScreen] Attempting Sign In for: $email');
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        print('[AuthScreen] Sign In call completed WITHOUT throwing.');
        if (mounted) {
          print('[AuthScreen] Sign In Successful, navigating...');
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } on AuthException catch (e) {
      // --- Auth Error Handling (SignIn or unexpected SignUp errors) --- 
      print('[AuthScreen] Caught AuthException: ${e.message}');
      String displayMessage = e.message;
      // No need to check for user exists here as it was checked before signUp
      if (!_isSignUp && e.message.toLowerCase().contains('email not confirmed')) {
        displayMessage = 'Please confirm your email before signing in.';
      } else if (!_isSignUp && e.message.toLowerCase().contains('invalid login credentials')) {
         displayMessage = 'Incorrect email or password.';
      } 
      // Add other specific error message mappings if needed

      if (mounted) {
        setState(() {
          _errorMessage = displayMessage;
        });
      }
    } catch (e) {
      // --- Generic Error Handling --- 
      print('[AuthScreen] Caught Generic Exception: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred. Please try again.';
        });
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
    return Scaffold(
      appBar: AppBar(title: Text(_isSignUp ? 'Sign Up' : 'Sign In')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.trim().length < 6) {
                      return 'Password must be at least 6 characters long.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text(_isSignUp ? 'Sign Up' : 'Sign In'),
                  ),
                const SizedBox(height: 12),
                if (!_isLoading)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _errorMessage = null; // Clear error on mode switch
                        _formKey.currentState?.reset(); // Optional: reset form on switch
                      });
                    },
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign In'
                          : 'Don\'t have an account? Sign Up',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
