// Load environment variables from .env file
import * as dotenv from 'dotenv';
dotenv.config();

import * as fs from 'fs';
import * as path from 'path';
import { processScanImage } from './index';

// Check for Gemini API key
if (!process.env.GEMINI_API_KEY) {
  console.warn("⚠️ Warning: GEMINI_API_KEY environment variable is not set. Text analysis will be skipped.");
}

/**
 * Test function that loads an image from a file and processes it
 */
async function testScanImage() {
  try {
    // Path to test image
    const imagePath = path.resolve(__dirname, '../assets/test/invoice-test.png');
    console.log('Image path:', imagePath);
    
    // Environment setup details
    console.log('Environment setup:');
    console.log(`- GOOGLE_APPLICATION_CREDENTIALS: ${process.env.GOOGLE_APPLICATION_CREDENTIALS || './splitbase-7ec0f-9618a4571647.json'}`);
    console.log(`- GEMINI_API_KEY: ${process.env.GEMINI_API_KEY ? 'Set' : 'Not set'}`);
    
    // Check if file exists
    if (!fs.existsSync(imagePath)) {
      throw new Error(`Test image file not found: ${imagePath}`);
    }
    
    // Read the file as a buffer
    const imageBuffer = fs.readFileSync(imagePath);
    
    // Convert to base64
    const imageBase64 = imageBuffer.toString('base64');
    
    // First test: Extract text only
    console.log('\nTesting text extraction...');
    const textResult = await processScanImage(`data:image/png;base64,${imageBase64}`, true);
    
    if (textResult && textResult.text) {
      console.log('✅ Text extraction successful');
      console.log(`Text extracted (first 200 chars): ${textResult.text.substring(0, 200)}...`);
      if (textResult.confidence) {
        console.log(`Confidence: ${textResult.confidence}`);
      }
    } else {
      console.log('❌ Text extraction failed');
      console.log(textResult);
    }
    
    // If GEMINI_API_KEY is set, test full analysis
    if (process.env.GEMINI_API_KEY) {
      console.log('\nTesting full analysis with Gemini...');
      const fullResult = await processScanImage(`data:image/png;base64,${imageBase64}`, false);
      
      if (fullResult && fullResult.text) {
        console.log('✅ Full analysis successful');
        if (fullResult.invoiceAnalysis) {
          console.log('Analysis results:');
          console.log(JSON.stringify(fullResult.invoiceAnalysis, null, 2));
        } else {
          console.log('⚠️ Analysis performed but no results returned');
        }
      } else {
        console.log('❌ Analysis failed');
        console.log(fullResult);
      }
    }
    
    return 'Test completed';
  } catch (error) {
    console.error('Error processing image:', error);
    return error;
  }
}

async function runTests() {
  const result = await testScanImage();
  console.log('\nTest completed');
}

// Run the tests
runTests().catch(error => {
  console.error("Test failed with error:", error);
  process.exit(1);
}); 