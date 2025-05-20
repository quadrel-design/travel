import 'package:flutter/material.dart';

/// A custom text input field widget with an external label and specific styling.
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final IconData? prefixIconData;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final AutovalidateMode? autovalidateMode;
  final FormFieldSetter<String>? onSaved;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onToggleObscureText;
  final FocusNode? focusNode; // Added for focus management

  const AppTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.prefixIconData,
    this.validator,
    this.keyboardType,
    this.autovalidateMode,
    this.onSaved,
    this.isPassword = false,
    this.obscureText = false,
    this.onToggleObscureText,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = Colors.pink.shade700; // Or theme.colorScheme.error

    return FormField<String>(
      validator: validator,
      onSaved: onSaved,
      autovalidateMode: autovalidateMode ?? AutovalidateMode.disabled,
      initialValue: controller
          .text, // Important for FormField to pick up initial state if controller has text
      builder: (FormFieldState<String> formFieldState) {
        // We need to manually trigger revalidation or update when controller changes
        // if we want the FormFieldState to reflect controller changes directly for validation
        // For simplicity, validator will run on interaction or form validation.

        // Manually update FormFieldState if controller changes, to reflect errors from external sources if needed
        // This can be tricky. Usually, validation is tied to user input or explicit form.validate() calls.
        // If error comes from an external source (like a provider after API call), FormFieldState needs to know.
        // For now, relying on standard form validation triggers.

        // Method to handle onChanged for TextField and update FormFieldState
        void onChangedHandler(String value) {
          formFieldState.didChange(value);
        }

        Widget? suffixIconWidget;
        if (formFieldState.hasError) {
          suffixIconWidget =
              Icon(Icons.warning_amber_rounded, color: errorColor, size: 20);
        } else if (isPassword) {
          suffixIconWidget = IconButton(
            icon: Icon(
              obscureText ? Icons.visibility_off : Icons.visibility,
              color: theme.iconTheme.color?.withOpacity(0.6),
              size: 20,
            ),
            onPressed: onToggleObscureText,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Important for Column height
          children: [
            Text(
              labelText,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500), // Style for the external label
            ),
            const SizedBox(height: 8.0),
            TextField(
              // Using TextField directly for more control over error display
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: hintText,
                prefixIcon: prefixIconData != null
                    ? Icon(prefixIconData,
                        color: theme.iconTheme.color?.withOpacity(0.6),
                        size: 20)
                    : null,
                suffixIcon: suffixIconWidget,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest
                    .withOpacity(0.3), // Light fill color
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide:
                      BorderSide.none, // No border for normal state, using fill
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide.none, // No border for normal state
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: errorColor, width: 1.0),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: BorderSide(color: errorColor, width: 1.5),
                ),
                // Remove errorText from InputDecoration to display it externally
                errorText: null,
                // Ensure hint and label styles are appropriate if used within InputDecoration
                hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.7)),
              ),
              keyboardType: keyboardType,
              obscureText: obscureText,
              textCapitalization: isPassword
                  ? TextCapitalization.none
                  : TextCapitalization.sentences,
              onChanged: onChangedHandler, // Update FormFieldState on change
              // Removed onSaved from TextField, FormField handles it
            ),
            if (formFieldState.hasError)
              Padding(
                padding: const EdgeInsets.only(
                    top: 6.0, left: 12.0), // Adjust padding as needed
                child: Text(
                  formFieldState.errorText ??
                      '', // Display error text from FormFieldState
                  style: TextStyle(color: errorColor, fontSize: 11.5),
                  textAlign: TextAlign.start,
                ),
              ),
          ],
        );
      },
    );
  }
}
