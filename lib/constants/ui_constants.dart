import 'package:flutter/material.dart';

/// UI Constants used throughout the app
class UIConstants {
  // Spacing
  static const double kPanelPadding = 16.0;
  static const double kSectionSpacing = 16.0;
  static const double kItemSpacing = 8.0;
  static const double kElementSpacing = 4.0;

  // Colors
  static const Color kPanelBackgroundColor = Colors.black87;
  static const Color kPanelForegroundColor = Colors.white;
  static const Color kPanelLabelColor = Colors.white70;
  static const Color kPanelHighlightColor = Colors.green;
  static const Color kPanelWarningColor = Colors.orange;
  static const Color kPanelErrorColor = Colors.redAccent;

  // Text Styles
  static const TextStyle kPanelTitleStyle = TextStyle(
    color: kPanelForegroundColor,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle kPanelLabelStyle = TextStyle(
    color: kPanelLabelColor,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle kPanelValueStyle = TextStyle(
    color: kPanelForegroundColor,
    fontSize: 16,
  );

  static const TextStyle kPanelHighlightedValueStyle = TextStyle(
    color: kPanelForegroundColor,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );
}
