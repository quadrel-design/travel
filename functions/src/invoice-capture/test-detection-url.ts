/**
 * Test Script for Image Detection
 * 
 * This script tests the detectTextInImage function with a real invoice image URL.
 * It bypasses Firebase authentication and Firestore updates to focus solely on
 * testing whether OCR is working correctly.
 */

import { detectTextInImage } from './image-detection';
import * as dotenv from 'dotenv';
dotenv.config();

// URL of an actual invoice image for testing
// Replace this with a real, publicly accessible image URL containing text
const TEST_IMAGE_URL = 'https://assets-global.website-files.com/5efc0159f9a97ba05a8b7a8a/5f18a955264d7acbd6b51411_invoice-example-en-1.jpg';

/**
 * Main test function
 */
async function testImageDetection() {
  console.log('Testing image detection with URL:', TEST_IMAGE_URL);
  console.log('----------------------------------------');
  
  try {
    console.log('Calling Vision API...');
    const startTime = Date.now();
    
    const result = await detectTextInImage(TEST_IMAGE_URL);
    
    const endTime = Date.now();
    const elapsedTime = (endTime - startTime) / 1000;
    
    console.log('----------------------------------------');
    console.log(`Process completed in ${elapsedTime.toFixed(2)} seconds`);
    console.log('----------------------------------------');
    
    console.log('OCR Result:');
    console.log(`OCR Result Status: ${result.status}`);
    console.log(`Success: ${result.success}, Has Text: ${result.hasText}`);
    
    if (result.hasText && result.extractedText) {
      console.log('----------------------------------------');
      console.log('First 500 characters:');
      console.log(result.extractedText.substring(0, 500));
      console.log('----------------------------------------');
      console.log(`Full text length: ${result.extractedText.length} characters`);
      
      if (result.textBlocks && result.textBlocks.length > 0) {
        console.log('----------------------------------------');
        console.log(`Text blocks detected: ${result.textBlocks.length}`);
        console.log('First 5 text blocks:');
        result.textBlocks.slice(0, 5).forEach((block, index) => {
          console.log(`Block ${index + 1}: "${block.text}" (Confidence: ${block.confidence})`);
        });
      }
    }
    
    if (!result.success) {
      console.error('Error:', result.error);
    }
    
    console.log('----------------------------------------');
    console.log('Test completed');
  } catch (error) {
    console.error('Test failed with exception:', error);
  }
}

// Run the test
testImageDetection().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
}); 