import 'package:flutter/material.dart';

class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color iconColor;
  final double size;
  final double padding;

  const CircleIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor = const Color(0xFFF2F2F2),
    this.iconColor = Colors.black87,
    this.size = 28,
    this.padding = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, size: size, color: iconColor),
        onPressed: onPressed,
        splashRadius: size,
        padding: EdgeInsets.all(padding),
      ),
    );
  }
}
