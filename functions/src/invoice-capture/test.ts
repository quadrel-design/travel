// Load environment variables from .env file
import * as dotenv from 'dotenv';
dotenv.config();

import * as fs from 'fs';
import { detectTextInImage } from './image-detection';
import { analyzeDetectedText } from './text-analysis';

// Helper function for testing
async function processScanImage(imageUrl: string, skipAnalysis = false, imageBuffer?: Buffer) {
  const detectResult = await detectTextInImage(imageUrl, imageBuffer);
  
  if (!detectResult.hasText || skipAnalysis) {
    return detectResult;
  }
  
  const analysisResult = await analyzeDetectedText(detectResult.detectedText);
  
  return {
    ...detectResult,
    status: analysisResult.status,
    invoiceAnalysis: analysisResult.invoiceAnalysis,
    isInvoice: analysisResult.isInvoice
  };
}

// Check for Gemini API key
if (!process.env.GEMINI_API_KEY) {
  console.warn("⚠️ Warning: GEMINI_API_KEY environment variable is not set. Text analysis will be skipped.");
}

/**
 * Test function that loads an image from a file and processes it
 */
async function testScanImage() {
  try {
    // Path to test image - use the absolute path provided by user
    const imagePath = '/Users/christian/Desktop/Projects/travel/assets/test/invoice-test.png';
    console.log('Image path:', imagePath);
    
    // Environment setup details
    console.log('Environment setup:');
    console.log(`- GOOGLE_APPLICATION_CREDENTIALS: ${process.env.GOOGLE_APPLICATION_CREDENTIALS || './splitbase-7ec0f-9618a4571647.json'}`);
    console.log(`- GEMINI_API_KEY: ${process.env.GEMINI_API_KEY ? 'Set' : 'Not set'}`);
    
    // Check if file exists
    if (!fs.existsSync(imagePath)) {
      throw new Error(`Test image file not found: ${imagePath}`);
    }
    
    // Create a fake URL for testing instead of using a data URL
    // This avoids the ENAMETOOLONG error
    const fakeImageUrl = `https://example.com/test-image-${Date.now()}.png`;
    const imageBuffer = fs.readFileSync(imagePath);
    
    // Step 1: Test text detection only
    console.log('\nTesting text detection...');
    const detectResult = await detectTextInImage(fakeImageUrl, imageBuffer);
    
    if (detectResult && detectResult.hasText) {
      console.log('✅ Text detection successful');
      console.log(`Text detected (first 200 chars): ${detectResult.detectedText.substring(0, 200)}...`);
      if (detectResult.confidence) {
        console.log(`Confidence: ${detectResult.confidence}`);
      }
      console.log(`Status: ${detectResult.status}`);
    } else {
      console.log('❌ Text detection failed or no text found');
      console.log(detectResult);
    }
    
    // Step 2: If text was detected, test text analysis
    if (detectResult && detectResult.hasText) {
      console.log('\nTesting text analysis...');
      const analysisResult = await analyzeDetectedText(detectResult.detectedText);
      
      if (analysisResult && analysisResult.success) {
        console.log('✅ Text analysis successful');
        console.log(`Status: ${analysisResult.status}`);
        console.log(`Is invoice: ${analysisResult.isInvoice}`);
        if (analysisResult.invoiceAnalysis) {
          console.log('Analysis results:');
          console.log(JSON.stringify(analysisResult.invoiceAnalysis, null, 2));
        } else {
          console.log('⚠️ Analysis performed but no results returned');
        }
      } else {
        console.log('❌ Analysis failed');
        console.log(analysisResult);
      }
    }
    
    // For backward compatibility, also test the combined processScanImage function
    console.log('\nTesting combined image processing...');
    const combinedResult = await processScanImage(fakeImageUrl, false, imageBuffer);
    
    if (combinedResult && combinedResult.hasText) {
      console.log('✅ Combined processing successful');
      console.log(`Status: ${combinedResult.status}`);
      // Check if invoiceAnalysis exists in the result
      if (combinedResult.status === 'Invoice' && 'invoiceAnalysis' in combinedResult) {
        console.log('Invoice analysis results:');
        console.log(JSON.stringify((combinedResult as any).invoiceAnalysis, null, 2));
      }
    } else {
      console.log('❌ Combined processing failed');
      console.log(combinedResult);
    }
    
    return 'Test completed';
  } catch (error) {
    console.error('Error processing image:', error);
    return error;
  }
}

async function runTests() {
  await testScanImage();
  console.log('\nTest completed');
}

// Run the tests
runTests().catch(error => {
  console.error("Test failed with error:", error);
  process.exit(1);
}); 