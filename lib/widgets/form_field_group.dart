import 'package:flutter/material.dart';

/// A widget that groups a label, an input field (child), and an optional description.
class FormFieldGroup extends StatelessWidget {
  final String label;
  final Widget child; // The TextFormField or other input
  final String? description;
  final EdgeInsetsGeometry labelPadding;
  final EdgeInsetsGeometry fieldPadding;
  final EdgeInsetsGeometry descriptionPadding;

  const FormFieldGroup({
    super.key,
    required this.label,
    required this.child,
    this.description,
    this.labelPadding = const EdgeInsets.only(bottom: 6), // Default spacing
    this.fieldPadding = EdgeInsets.zero, // No extra padding around field by default
    this.descriptionPadding = const EdgeInsets.only(top: 6), // Default spacing
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desc = description;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: labelPadding,
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: fieldPadding,
          child: child, // The actual input field
        ),
        if (desc != null && desc.isNotEmpty)
          Padding(
            padding: descriptionPadding,
            child: Text(
              desc,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
} 