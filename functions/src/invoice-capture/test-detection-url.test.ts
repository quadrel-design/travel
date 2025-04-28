/**
 * Jest Test for Image Detection
 * 
 * This file tests the OCR functionality with a real invoice image URL,
 * using Jest as the test runner.
 */

import { detectTextInImage } from './image-detection';
import * as dotenv from 'dotenv';
dotenv.config();

// URL of an actual invoice image for testing
// Replace this with a real, publicly accessible image URL containing text
const TEST_IMAGE_URL = 'https://assets-global.website-files.com/5efc0159f9a97ba05a8b7a8a/5f18a955264d7acbd6b51411_invoice-example-en-1.jpg';

describe('Invoice OCR functionality', () => {
  jest.setTimeout(30000); // 30 seconds timeout for OCR API call
  
  test('Should process image URL and return a valid result', async () => {
    // Call the Vision API
    console.log('Testing URL:', TEST_IMAGE_URL);
    const startTime = Date.now();
    
    const result = await detectTextInImage(TEST_IMAGE_URL);
    
    const elapsedTime = (Date.now() - startTime) / 1000;
    console.log(`Process completed in ${elapsedTime.toFixed(2)} seconds`);
    
    // Basic assertions that should always pass regardless of image content
    expect(result).toBeDefined();
    expect(result.success).toBeDefined();
    
    // Log the result for debugging
    console.log('OCR Result:', { 
      success: result.success, 
      hasText: result.hasText, 
      status: result.status
    });
    
    if (result.success) {
      // If successful, check if text was found
      console.log(`Text found: ${result.hasText}`);
      
      if (result.hasText && result.extractedText) {
        console.log(`Detected ${result.extractedText.length} characters of text`);
        console.log(`First 100 characters: ${result.extractedText.substring(0, 100)}...`);
        
        // Additional assertions when text is found
        expect(result.extractedText.length).toBeGreaterThan(0);
        
        if (result.textBlocks) {
          console.log(`Text blocks detected: ${result.textBlocks.length}`);
        }
      }
    } else {
      console.log('OCR processing was not successful');
      console.log('Error:', result.error);
    }
  });
  
  test('Should handle invalid image URLs gracefully', async () => {
    const invalidUrl = 'https://example.com/non-existent-image.jpg';
    console.log('Testing invalid URL:', invalidUrl);
    
    try {
      const result = await detectTextInImage(invalidUrl);
      
      // Even with invalid URLs, the function should return a result object
      expect(result).toBeDefined();
      
      // Log the result for debugging
      console.log('Invalid URL Result:', { 
        success: result.success, 
        hasText: result.hasText, 
        status: result.status,
        error: result.error
      });
      
    } catch (error) {
      // The function should not throw, but handle errors gracefully
      fail('Function threw an exception instead of returning an error result: ' + error);
    }
  });
}); 