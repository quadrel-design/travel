# Testing the Invoice Capture OCR Functionality

This directory contains Jest test scripts to verify the OCR functionality in the invoice capture process.

## Prerequisites

1. Make sure your environment is properly set up:
   - You have Firebase credentials set up locally
   - Google Cloud Vision API is enabled for your project
   - Environment variables are configured (check `.env` file)

2. Ensure you have the necessary permissions to use the Vision API

## Available Tests

### 1. URL-Only OCR Test (`test-detection-url.test.ts`)

This test focuses solely on testing the OCR functionality with a real image URL. It bypasses Firebase authentication and Firestore updates to test whether the Vision API interaction is working correctly.

#### How to run:

```bash
# Run just the URL-based test
npm run test:ocr:url
```

### 2. Full Test Suite (`image-detection.test.ts`)

This is a more comprehensive test that tests both local image processing and URL-based OCR.

#### How to run:

```bash
# Run all OCR-related tests
npm run test:ocr

# Run tests in watch mode (continuous testing)
npm run test:watch
```

### 3. Using Test Images

By default, the tests use a sample invoice image URL. You can modify the test files to use your own images:

- For local image testing: Place a test image in the `/test` directory (e.g., `test-invoice.jpg`)
- For URL testing: Update the `TEST_IMAGE_URL` constant in the test files

## Troubleshooting

If you encounter issues:

1. Check your Google Cloud credentials:
   ```bash
   echo $GOOGLE_APPLICATION_CREDENTIALS
   ```

2. Verify the Vision API is enabled in your Google Cloud console

3. Check the Firebase emulator if testing in a development environment:
   ```bash
   firebase emulators:start
   ```

4. Review error messages carefully - most issues are related to authentication or API access

## Common Error Solutions

- **Authentication errors**: Ensure your service account has the proper roles assigned
- **API not enabled**: Enable the Vision API in the Google Cloud Console
- **Quota exceeded**: Check your Google Cloud quota for Vision API usage
- **Network errors**: Check your internet connection and firewall settings
- **Test timeouts**: If tests timeout, increase the timeout value in Jest config or use `jest.setTimeout()`

## Jest Configuration

The tests use Jest as the test runner. The configuration is in the root `jest.config.js` file. Key settings:

- Test timeout: 30 seconds (to accommodate API calls)
- Environment: Node.js
- TypeScript handling: via ts-jest

You can add test files with `.test.ts` or `.spec.ts` extensions and Jest will automatically discover them. 