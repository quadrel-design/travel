import 'package:flutter/material.dart';
import 'circle_icon_button.dart';
import 'circle_icon_group.dart';

class InvoiceDetailBottomBar extends StatelessWidget {
  final VoidCallback? onUpload;
  final VoidCallback? onScan;
  final VoidCallback? onInfo;
  final VoidCallback? onFavorite;
  final VoidCallback? onSettings;
  final VoidCallback? onDelete;

  const InvoiceDetailBottomBar({
    this.onUpload,
    this.onScan,
    this.onInfo,
    this.onFavorite,
    this.onSettings,
    this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Upload icon (left)
            CircleIconButton(icon: Icons.upload, onPressed: onUpload),
            // Scan icon (left-center)
            CircleIconButton(icon: Icons.document_scanner, onPressed: onScan),
            // Grouped icons (center)
            CircleIconGroup(
              children: [
                CircleIconButton(
                    icon: Icons.info_outline,
                    onPressed: onInfo,
                    size: 24,
                    padding: 4),
                CircleIconButton(
                    icon: Icons.favorite_border,
                    onPressed: onFavorite,
                    size: 24,
                    padding: 4),
                CircleIconButton(
                    icon: Icons.tune,
                    onPressed: onSettings,
                    size: 24,
                    padding: 4),
              ],
            ),
            // Delete icon (right)
            CircleIconButton(icon: Icons.delete_outline, onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}
