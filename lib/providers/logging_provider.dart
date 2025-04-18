import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

// Global Provider for the Logger instance
final loggerProvider = Provider<Logger>((ref) {
  // Configure the logger here (e.g., printer, output, level)
  return Logger(
    printer: PrettyPrinter(
      methodCount: 1, // number of method calls to be displayed
      errorMethodCount: 8, // number of method calls if stacktrace is provided
      lineLength: 120, // width of the output
      colors: true, // Colorful log messages
      printEmojis: true, // Print an emoji for each log message
      dateTimeFormat: DateTimeFormat.none // Use proper parameter instead of deprecated printTime
    ),
    // You can also set the minimum level, e.g., Level.debug for development
    // level: Level.debug, 
  );
}); 