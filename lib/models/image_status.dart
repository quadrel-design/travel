/// Enum representing the processing status of a journey image.
enum ImageStatus {
  ready, // Initial state, ready for processing or upload
  processing, // Actively being processed (e.g., by Edge Function)
  scanComplete, // Processed successfully, text/data found
  noTextFound, // Processed successfully, but no text detected
  error // An error occurred during processing
} 