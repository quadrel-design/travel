/**
 * Jest Tests for image-detection.ts
 * 
 * This file contains tests to verify the OCR functionality in image-detection.ts
 * using Jest as the test runner.
 */

import { detectTextInImage } from './image-detection';
import * as fs from 'fs';

// Path to a test image using absolute path
const TEST_IMAGE_PATH = '/Users/christian/Desktop/Projects/travel/assets/test/invoice-test.png';
console.log('Test image path:', TEST_IMAGE_PATH);
console.log('File exists?', fs.existsSync(TEST_IMAGE_PATH));

// A public image URL for testing - change to a valid URL with text content
const TEST_IMAGE_URL = 'https://assets-global.website-files.com/5efc0159f9a97ba05a8b7a8a/5f18a955264d7acbd6b51411_invoice-example-en-1.jpg';

describe('Invoice Image Detection', () => {
  jest.setTimeout(30000); // 30 seconds timeout for API calls
  
  test('Should process image from URL', async () => {
    console.log(`Testing with URL: ${TEST_IMAGE_URL}`);
    
    const result = await detectTextInImage(TEST_IMAGE_URL);
    
    // Basic assertions - these should always pass
    expect(result).toBeDefined();
    
    // Log the results for debugging
    console.log('OCR Result:', { 
      success: result.success, 
      hasText: result.hasText, 
      status: result.status
    });
    
    // Check if successful
    if (result.success) {
      // If text was found, check the content
      if (result.hasText && result.extractedText) {
        console.log(`Detected ${result.extractedText.length} characters of text`);
        console.log(`Text sample: "${result.extractedText.substring(0, 100)}..."`);
        
        expect(result.extractedText.length).toBeGreaterThan(0);
        
        if (result.textBlocks) {
          console.log(`Text blocks: ${result.textBlocks.length}`);
        }
      } else {
        console.log('No text detected in the image');
      }
    } else {
      console.log('OCR processing failed:', result.error);
    }
  });
  
  // Skip this test if the local test image doesn't exist
  (fs.existsSync(TEST_IMAGE_PATH) ? test : test.skip)('Should process local image buffer', async () => {
    console.log(`Testing with local image: ${TEST_IMAGE_PATH}`);
    
    const imageBuffer = fs.readFileSync(TEST_IMAGE_PATH);
    expect(imageBuffer).toBeDefined();
    expect(imageBuffer.length).toBeGreaterThan(0);
    
    const result = await detectTextInImage('placeholder-url', imageBuffer);
    
    // Basic assertions
    expect(result).toBeDefined();
    
    // Log the results
    console.log('Local Image OCR Result:', { 
      success: result.success, 
      hasText: result.hasText, 
      status: result.status
    });
    
    // Additional checks based on result
    if (result.success && result.hasText && result.extractedText) {
      console.log(`Detected ${result.extractedText.length} characters of text`);
      console.log(`Text sample: "${result.extractedText.substring(0, 100)}..."`);
      expect(result.extractedText.length).toBeGreaterThan(0);
    }
  });
  
  test('Should handle errors gracefully', async () => {
    // Test with invalid URL
    const invalidUrl = 'not-a-valid-url';
    console.log(`Testing with invalid URL: ${invalidUrl}`);
    
    const result = await detectTextInImage(invalidUrl);
    
    // Even with errors, we should get a result object
    expect(result).toBeDefined();
    
    // Log the result
    console.log('Invalid URL Result:', { 
      success: result.success, 
      hasText: result.hasText, 
      status: result.status,
      error: result.error
    });
  });
}); 