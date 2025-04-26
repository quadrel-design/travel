/**
 * Main entry point for Firebase Functions
 * 
 * This file exports all functions from specialized modules in the invoice-capture folder.
 */

// Load environment variables from .env file
import * as dotenv from 'dotenv';
dotenv.config();

// Export OCR & detection functions
export { detectImage, detectTextInImage } from './invoice-capture/image-detection';

// Export text analysis functions
export { analyzeImage, analyzeDetectedText } from './invoice-capture/text-analysis';

// Export invoice capture function
export { scanImage } from './invoice-capture/invoice-capture';

// Export helper function for testing
import { detectTextInImage } from './invoice-capture/image-detection';
import { analyzeDetectedText } from './invoice-capture/text-analysis';
import { onCall } from "firebase-functions/v2/https";

// Test function to check if environment variables are properly loaded
export const testApiKeyConfig = onCall({
  enforceAppCheck: false,
  timeoutSeconds: 30,
  memory: "128MiB",
  maxInstances: 5
}, async (request) => {
  // Check Gemini API key
  const geminiApiKey = process.env.FUNCTIONS_CONFIG ? 
    JSON.parse(process.env.FUNCTIONS_CONFIG).gemini?.api_key || 
    JSON.parse(process.env.FUNCTIONS_CONFIG).gemini?.key : 
    process.env.GEMINI_API_KEY || "";
  
  return {
    success: true,
    hasGeminiKey: !!geminiApiKey,
    keyLength: geminiApiKey ? geminiApiKey.length : 0,
    envVars: Object.keys(process.env).filter(key => !key.includes('KEY') && !key.includes('SECRET'))
  };
});

// Helper function used by the test script
export async function processScanImage(imageUrl: string, skipAnalysis = false, imageBuffer?: Buffer) {
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
