# Invoice Image Capture and Analysis Workflow

This directory contains the Cloud Functions responsible for processing uploaded invoice images, performing Optical Character Recognition (OCR), and analyzing the extracted text using Gemini to identify invoice details.

## Core Functions

- `image-detection.ts`: Handles OCR via Google Cloud Vision API.
- `text-analysis.ts`: Handles text analysis via Google Gemini API.
- `invoice-capture.ts`: Contains shared models/types and the unified scan function.

## Key Client Components

- `invoice_capture_overview_screen.dart`: Dedicated screen for viewing and scanning multiple invoice images
- `invoice_capture_detail_view.dart`: Detailed image view with comprehensive scan and analysis capabilities
- `invoice_scan_util.dart`: Utility class for handling OCR scan operations from multiple screens

## Workflow Steps

1.  **Image Upload (Client):**
    - The user uploads an image file through the Flutter application.
    - The client-side repository (`FirestoreInvoiceRepository`) uploads the image to Firebase Storage under a path like `/users/{userId}/invoices/{invoiceId}/images/{fileName}`.
    - Initial status is set to `uploading` or `ready`.
    - The uploaded image appears in the UI with a "Scan" button.

2.  **Manual OCR Trigger (Scan Button):**
    - The user clicks the "Scan" button in the UI.
    - The UI updates the status to `ocr_running` and displays a spinner.
    - The client calls the `detectImage` function with the image URL, **invoiceId**, and **imageId**.
    - This OCR trigger can be initiated from any invoice image view.

3.  **OCR Processing (`detectImage` Function):**
    - The function authenticates the user.
    - It calls the Google Cloud Vision API (`vision.textDetection`) to perform OCR on the provided image.
    - It updates the user's estimated costs based on Vision API usage.
    - It updates the corresponding `InvoiceCaptureProcess` document in Firestore (`/users/{userId}/invoices/{invoiceId}/images/{imageId}`):
        - **If text is found:** Sets `status: 'invoice'`, populates `extractedText` with the OCR result. UI will display a blue chip.
        - **If no text or error:** Sets `status: 'no invoice'`. UI will display an orange chip.

4.  **Analysis Trigger (Client -> `analyzeImage` Function):**
    - The Flutter UI listens to the `InvoiceCaptureProcess` document's stream.
    - When text is detected (status is `'invoice'`), the UI enables analysis capabilities.
    - The client can call the `analyzeImage` HTTPS Callable Function (`text-analysis.ts`).
    - The client passes the `extractedText`, **invoiceId**, and **imageId**.

5.  **Analysis Processing (`analyzeImage` Function):**
    - The function authenticates the user.
    - **Immediately** updates the Firestore document status to `status: 'analysis_running'` to provide UI feedback (spinner).
    - It calls the Google Gemini API with the `extractedText` and a specific prompt requesting invoice details in JSON format.
    - It parses and cleans the JSON response from Gemini.
    - It determines if the extracted data constitutes an invoice (checking for `totalAmount` and `currency`).
    - It updates the Firestore document again:
        - **If Gemini identifies invoice data:** Sets `status: 'analysis_complete'`. Populates `isInvoice: true`, `invoiceAnalysis` (JSON result), and individual fields (`totalAmount`, `currency`, `merchantName`, etc.).
        - **If Gemini doesn't find invoice data or an error occurs:** Sets `status: 'analysis_failed'`. Sets `isInvoice: false`.

## Firestore Document (`InvoiceCaptureProcess`)

Located at: `/users/{userId}/invoices/{invoiceId}/images/{imageId}`

Key fields involved in this workflow:

- `url`: (String) Storage URL of the image.
- `status`: (String) Tracks the processing state:
    - `uploading` or `ready` (Set by client initially)
    - `ocr_running` (OCR process is running)
    - `invoice` (OCR complete, text found, displayed with blue chip)
    - `no invoice` (OCR complete, no text found, displayed with orange chip)
    - `analysis_running` (Gemini analysis initiated)
    - `analysis_complete` (Gemini analysis finished, invoice data found)
    - `analysis_failed` (Gemini analysis finished, not an invoice or error)
- `extractedText`: (String) Full text extracted by OCR.
- `isInvoice`: (Boolean) Flag set by Gemini analysis.
- `invoiceAnalysis`: (Map) Raw JSON result object from Gemini.
- `totalAmount`: (Number) Extracted total amount.
- `currency`: (String) Extracted currency code.
- `merchantName`: (String) Extracted merchant name.
- `invoiceDate`: (String) Extracted date (ISO format).
- `merchantLocation`: (String) Extracted location.
- `lastProcessedAt`: (Timestamp) Firestore server timestamp of the last update.

## Field Name Consistency

- All Cloud Functions and client code now use `invoiceId` as the standard field/parameter name for invoice-related operations.
- All function calls, Firestore paths, and UI logic expect and use `invoiceId` and `imageId`.
- Any previous references to `projectsId` for invoices have been renamed to `invoiceId` for clarity and consistency.

## UI Status Handling

- The UI displays appropriate status chips based on the processing state:
  - `uploading` or `ready` (Gray chip): Initial state after upload
  - `ocr_running` (Blue chip with spinner): OCR is in progress
  - `invoice` (Blue chip): Text was detected in the image
  - `no invoice` (Orange chip): No text was detected in the image
  - `analysis_running` (Blue chip with spinner): Analysis is in progress
  - `analysis_complete` (Blue chip): Analysis completed successfully
  - `analysis_failed` (Red chip): Analysis failed

- During OCR or analysis processing (status `ocr_running` or `analysis_running`), a spinner is displayed to indicate work in progress.
- When status is `invoice`, analysis actions are enabled.
- The analysis panel displays extracted text when available for user review.
- Delete button is available for all statuses except during processing.

## Implementation Notes

- The Scan button triggers OCR processing on demand, giving users control over when to process images.
- Status changes are reflected in real-time in the UI as the Firestore document updates.
- Status transitions:
  1. `uploading` or `ready` (set by client at upload time)
  2. `ocr_running` (set when Scan button is clicked)
  3. `invoice` or `no invoice` (set by OCR function)
  4. `analysis_running` (set at beginning of analysis)
  5. `analysis_complete` or `analysis_failed` (set at end of analysis)
- The spinner UI components replace action buttons during processing states to prevent users from initiating multiple operations simultaneously.
- The utility class `invoice_scan_util.dart` centralizes OCR functionality across different screens.

## Testing

A set of Jest test scripts is included to verify that the OCR functionality works correctly:

- `image-detection.test.ts`: Comprehensive test suite for testing OCR with both local images and URLs
- `test-detection-url.test.ts`: Focused test for testing OCR with a public image URL

### Running the Tests

To run the OCR tests:

1. Ensure your environment is properly configured with Firebase and Google Cloud credentials
2. Run the tests using the provided npm scripts:
   ```bash
   # Run all OCR tests
   npm run test:ocr
   
   # Run only the URL test
   npm run test:ocr:url
   
   # Run tests in watch mode
   npm run test:watch
   ```

See [TESTING.md](./TESTING.md) for detailed instructions and troubleshooting tips.

## OCR Triggering Using the Utility Class

The application now uses a centralized utility class `InvoiceScanUtil` to handle OCR operations from any screen:

```dart
// Example usage from any screen
Future<void> _scanImage(BuildContext context, WidgetRef ref,
    InvoiceCaptureProcess imageInfo) async {
  await InvoiceScanUtil.scanImage(context, ref, projectsId, imageInfo);
}
```

The utility class handles:
1. Status updates to Firestore
2. Cloud Function calls
3. Error handling and fallbacks
4. Field name compatibility
5. User feedback via snackbars 