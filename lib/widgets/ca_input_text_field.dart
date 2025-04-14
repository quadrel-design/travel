import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// TODO: Define or import getColors(), AppDimens, AppIcons
// These are placeholders and need to be replaced with your actual definitions
Color _getPrimaryVariantColor(BuildContext context) => Theme.of(context).primaryColor;
Color _getErrorColor(BuildContext context) => Theme.of(context).colorScheme.error;
Color? _getTextSubtitleColor(BuildContext context) => Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey.shade600;
class AppDimens { static const double radiusSmall = 4.0; }
class AppIcons { 
  static const IconData passwordEye = Icons.visibility; 
  static const IconData passwordEyeBlind = Icons.visibility_off; 
}
// Helper function replacement
Map<String, Color> getColors(BuildContext context) {
  return {
    'primaryVariant': _getPrimaryVariantColor(context),
    'redError': _getErrorColor(context),
    'textSubtitle': _getTextSubtitleColor(context) ?? Colors.grey.shade600, // Provide a default
  };
}

// Use lowerCamelCase for constants
const String passwordEyeIcon = 'assets/icons/eye.svg';
const String passwordEyeBlindIcon = 'assets/icons/eye-slash.svg';

class MyInputTextField extends StatefulWidget {
  final String? title;
  final String? helperText;
  final bool isSecure;
  final int? maxLength;
  final String? hint;
  final TextInputType? inputType;
  final String? initValue;
  final Color? backColor;
  final Widget? suffix;
  final Widget? prefix;
  final TextEditingController? textEditingController;
  final String? Function(String? value)? validator;
  final Function(String)? onTextChanged;
  final Function(String)? onSaved;
  final List<TextInputFormatter>? inputFormatters;

  // Use lowerCamelCase for constant
  static const int defaultMaxLength = 500;

  const MyInputTextField({
    Key? key,
    this.title,
    this.hint,
    this.helperText,
    this.inputType,
    this.initValue = "",
    this.isSecure = false,
    this.textEditingController,
    this.validator,
    this.maxLength,
    this.onTextChanged,
    this.onSaved,
    this.inputFormatters,
    this.backColor,
    this.suffix,
    this.prefix,
  }) : super(key: key);

  @override
  _MyInputTextFieldState createState() => _MyInputTextFieldState();
}

class _MyInputTextFieldState extends State<MyInputTextField> {
  late bool _passwordVisibility;
  late ThemeData theme;

  final FocusNode _focusNode = FocusNode(); // Make final

  late Color _borderColor; // Initialize in initState/didChangeDependencies
  double _borderSize = 1;

  // Helper to get colors safely
  Color _getSafeColor(String key, BuildContext context, Color defaultColor) {
     return getColors(context)[key] ?? defaultColor;
  }


  @override
  void initState() {
    super.initState();
    _passwordVisibility = !widget.isSecure;
    if (widget.textEditingController != null && widget.initValue != null) {
      widget.textEditingController!.text = widget.initValue!;
    }
    
    _focusNode.addListener(_onFocusChange);
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    theme = Theme.of(context);
    // Initialize border color after theme is available
    _borderColor = _getSafeColor('primaryVariant', context, Colors.grey.shade400); 
  }

  void _onFocusChange() {
     if (!mounted) return; // Check if mounted before calling setState
      setState(() {
        _borderSize = _focusNode.hasFocus ? 1.7 : 1;
         _borderColor = _focusNode.hasFocus 
             ? _getSafeColor('primaryVariant', context, Colors.blue) // Example focus color
             : _getSafeColor('primaryVariant', context, Colors.grey.shade400); // Default border color
         // Re-validate on focus change to reset potential error state?
         widget.validator?.call(widget.textEditingController?.text); 
      });
  }


  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          // Increase top margin for more space between label and top border
          padding: const EdgeInsets.only(top: 14.0), 
          child: Container(
            height: 55, // Adjust height if needed with padding changes
            decoration: BoxDecoration(
              border: Border.all(color: _borderColor, width: _borderSize),
              borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
              color: widget.backColor, // Apply background color
            ),
          ),
        ),
        Padding(
          // Horizontal padding for text/icons, vertical padding to position within container
          padding: const EdgeInsets.symmetric(horizontal: 12.0).copyWith(top: 0), // Adjusted top for stack
          child: TextFormField(
            focusNode: _focusNode,
            controller: widget.textEditingController,
            autocorrect: false,
            obscureText: !_passwordVisibility,
            keyboardType: widget.inputType,
            // Use theme's cursor color
            cursorColor: theme.textSelectionTheme.cursorColor ?? _getSafeColor('primaryVariant', context, Colors.blue),
            validator: (value) {
              String? validationResult = widget.validator?.call(value);
              // Update border color based on validation only if it changed
              final newBorderColor = validationResult != null 
                                    ? _getSafeColor('redError', context, Colors.red) 
                                    : _getSafeColor('primaryVariant', context, Colors.grey.shade400);
              if (_borderColor != newBorderColor) {
                 // Schedule state update after build if validation changes border color
                 WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) { // Check mount status again
                       setState(() {
                          _borderColor = newBorderColor;
                       });
                    }
                 });
              }
              return validationResult;
            },
            // Use updated Material 3 text styles
            style: theme.textTheme.bodyLarge, 
            maxLength: widget.maxLength,
            inputFormatters: widget.inputFormatters,
            maxLines: 1,
            onChanged: (text) {
              widget.onTextChanged?.call(text);
              // Optional: Immediate validation feedback on change
              // String? validationResult = widget.validator?.call(text);
              // final newBorderColor = validationResult != null ? _getSafeColor('redError', context, Colors.red) : _getSafeColor('primaryVariant', context, Colors.grey.shade400);
              // if (_borderColor != newBorderColor) {
              //   setState(() { _borderColor = newBorderColor; });
              // }
            },
            decoration: InputDecoration(
              counterText: "",
              hintText: widget.hint,
              hintStyle: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey.shade500),
              // Increase font size for the floating label
              floatingLabelStyle: theme.textTheme.bodySmall?.copyWith(
                  color: _getSafeColor('textSubtitle', context, Colors.grey.shade600),
                  fontSize: 14.0, // Make label larger
              ), 
              labelText: widget.title,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              helperText: widget.helperText,
              suffixIcon: getSuffixIcon(),
              prefixIcon: widget.prefix,
              // Remove internal padding and borders; handled by Stack/Container
              contentPadding: const EdgeInsets.only(top: 16, bottom: 12), // Fine-tune vertical padding
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              disabledBorder: InputBorder.none, // Added for completeness
              // isDense: true, // May help alignment
            ),
          ),
        )
      ],
    );
  }

  Widget? getSuffixIcon() {
     if (!widget.isSecure && widget.suffix != null) {
       return widget.suffix;
     }
     if (widget.isSecure) {
        return getPasswordSuffixIcon();
     }
     return null; 
  }

  Widget? getPasswordSuffixIcon() {
    return IconButton(
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      splashColor: Colors.transparent,
      padding: EdgeInsets.zero,
      icon: Icon(_passwordVisibility ? AppIcons.passwordEye : AppIcons.passwordEyeBlind),
      // Use icon theme color
      color: theme.iconTheme.color ?? Colors.grey.shade600, 
      onPressed: () {
        // Check mount status before calling setState
        if (mounted) { 
          setState(() {
            _passwordVisibility = !_passwordVisibility;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange); // Remove listener
    _focusNode.dispose();
    super.dispose();
  }
} 