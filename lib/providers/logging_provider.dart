/*
 * Logging Provider
 * 
 * This file defines a provider for centralized logging throughout the application.
 * It establishes a consistent logging approach that can be used across all components,
 * ensuring uniform log formatting, filtering, and output.
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

/// Provides a centralized logger instance for the entire application.
///
/// This provider creates a singleton Logger instance that can be used
/// throughout the app to maintain consistent logging behavior.
/// All log messages are filtered based on the PrettyPrinter settings.
///
/// The logger is configured with:
/// - Minimal method count for regular logs but expanded for errors
/// - Colorized output when supported
/// - Timestamps for all logs
/// - Emoji support for better visual distinction
///
/// In production builds, the log level can be adjusted to reduce verbosity.
///
/// Usage: `final logger = ref.read(loggerProvider);`
final loggerProvider = Provider<Logger>((ref) {
  // Configure the logger here (e.g., printer, output, level)
  return Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    // In production, you might want to change this to Level.warning or higher
    level: Level.debug,
  );
});
