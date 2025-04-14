import 'package:flutter/material.dart';

/// Custom AppBar for the CA Travel App
class CaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  const CaAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    // Use the themed AppBar for consistency
    return AppBar(
      title: Text(title),
      leading: leading,
      actions: actions,
      // Other properties will be inherited from the theme (centerTitle, elevation, etc.)
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
} 