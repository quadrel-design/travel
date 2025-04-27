/**
 * Main entry point for Firebase Functions
 * 
 * This file exports all functions from specialized modules in the invoice-capture folder.
 */

// Initialize Firebase Admin
import * as admin from 'firebase-admin';
try {
  admin.initializeApp();
  console.log('Firebase Admin initialized successfully in index.ts');
} catch (e) {
  console.log('Firebase Admin initialization error:', (e instanceof Error) ? e.message : String(e));
}

// Load environment variables from .env file
import * as dotenv from 'dotenv';
dotenv.config();

// Environment variables like GOOGLE_CLOUD_PROJECT and GEMINI_API_KEY
// should be set via Firebase Runtime Configuration or system environment variables.
// Removing hardcoded fallbacks. Ensure they are configured during deployment.
// Example: firebase functions:config:set gemini.key="YOUR_API_KEY" other.setting="value"
// Or set via Google Cloud Functions environment variables settings.

// Export functions from migration directory
// export * from './migration/rename-journeys-to-invoices'; // Commented out if not present

// Export functions from invoice-capture directory
export * from './invoice-capture/image-detection';
export * from './invoice-capture/invoice-capture';
export * from './invoice-capture/text-analysis';

// --- Billing Functions --- 
// import * as functions from 'firebase-functions'; // Using v1 SDK - Removed as unused
// Import v2 scheduler
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";

// Import the master update function
import { updateAllPricing } from './billing/update-all-pricing';

/**
 * Scheduled Cloud Function triggered daily to update pricing for all services.
 * Calls the `updateAllPricing` function from the billing module.
 * Schedule: Runs at 1 AM UTC every day. Adjust `schedule` as needed.
 * Timezone: UTC.
 */
export const updateAllServicePricingScheduled = onSchedule({
    schedule: '0 1 * * *', // Run at 1 AM UTC every day
    timeZone: 'UTC',
    // Add other v2 options like memory, timeout if needed
    // memory: "512MiB",
    // timeoutSeconds: 300,
  }, async (event) => {
    logger.info('Scheduled pricing update started for all services.', { event });
    try {
      await updateAllPricing(); // Call the master update function
      logger.info('Scheduled pricing update completed successfully for all services.');
      // No explicit return needed on success for v2 onSchedule
    } catch (error) {
      const errorMessage = (error instanceof Error) ? error.message : String(error);
      logger.error('Scheduled pricing update failed for all services:', { error: errorMessage });
      // Optionally, re-throw the error or handle it further (e.g., send notification)
      // throw error; // Re-throwing will cause the function execution to be marked as failed
    }
    // No explicit return value needed here. The function implicitly returns Promise<void>.
  });
  
// Export other billing functions if they exist and are needed
// export * from './billing/update-prices'; // Example: if this file exists and is needed elsewhere
// export { initCloudPricing } from './billing/init-cloud-pricing'; // Example
// export * from './billing/pricing-functions'; // Example

// --- Helper & Test Functions --- 

// Export helper function for testing
import { detectTextInImage } from './invoice-capture/image-detection';
import { analyzeDetectedText } from './invoice-capture/text-analysis';
import { onCall } from "firebase-functions/v2/https";

/**
 * Callable Cloud Function to test the configuration of API keys and environment variables.
 * Checks for the Gemini API key loaded via runtime configuration or environment variables.
 * Returns information about the key's presence and length, and lists non-sensitive env vars.
 * @param {CallableRequest} request - The request object (data not typically used here).
 * @returns {Promise<object>} An object indicating success, key presence, length, and env vars.
 */
export const testApiKeyConfig = onCall({
  enforceAppCheck: false, // Consider enabling App Check for production
  timeoutSeconds: 30,
  memory: "128MiB",
  maxInstances: 5
// eslint-disable-next-line @typescript-eslint/no-unused-vars
}, async (request) => { // Explicitly type or ignore request data if unused
  // Prefer reading sensitive keys from runtime config
  let geminiApiKey = process.env.FUNCTIONS_CONFIG ?
    JSON.parse(process.env.FUNCTIONS_CONFIG).gemini?.api_key ||
    JSON.parse(process.env.FUNCTIONS_CONFIG).gemini?.key :
    undefined; // Prioritize runtime config

  // Fallback to environment variable if not in runtime config
  if (!geminiApiKey) {
    geminiApiKey = process.env.GEMINI_API_KEY;
  }

  // Avoid logging sensitive environment variables
  const safeEnvVars = Object.keys(process.env).filter(key =>
    !key.toUpperCase().includes('KEY') &&
    !key.toUpperCase().includes('SECRET') &&
    !key.toUpperCase().includes('TOKEN') &&
    !key.toUpperCase().includes('PASSWORD')
    // Add other sensitive patterns if needed
  );

  return {
    success: true,
    hasGeminiKey: !!geminiApiKey,
    keySource: process.env.FUNCTIONS_CONFIG && (JSON.parse(process.env.FUNCTIONS_CONFIG).gemini?.api_key || JSON.parse(process.env.FUNCTIONS_CONFIG).gemini?.key) ? 'Runtime Config' : (process.env.GEMINI_API_KEY ? 'Environment Variable' : 'Not Found'),
    // Avoid returning key length directly, just presence is often enough
    // keyLength: geminiApiKey ? geminiApiKey.length : 0,
    envVars: safeEnvVars // Return only filtered env vars
  };
});

/**
 * Helper function primarily for testing the invoice scanning process.
 * Takes an image URL (or buffer), performs text detection, and optionally performs text analysis.
 * @param {string} imageUrl - The URL of the image to process.
 * @param {boolean} [skipAnalysis=false] - If true, skips the text analysis step.
 * @param {Buffer} [imageBuffer] - Optional image buffer to use instead of fetching the URL.
 * @returns {Promise<object>} An object containing detection results and, if analysis is performed, analysis results.
 */
export async function processScanImage(imageUrl: string, skipAnalysis = false, imageBuffer?: Buffer) {
  const detectResult = await detectTextInImage(imageUrl, imageBuffer);
  
  if (!detectResult.hasText || skipAnalysis) {
    return detectResult;
  }
  
  // Ensure detectedText is not null or undefined before passing to analysis
  if (!detectResult.detectedText) {
     logger.warn('No detected text found to analyze.', { imageUrl });
     return {
         ...detectResult,
         status: 'error',
         error: 'No text detected for analysis',
         invoiceAnalysis: null,
         isInvoice: false,
     };
  }
  
  const analysisResult = await analyzeDetectedText(detectResult.detectedText);
  
  return {
    ...detectResult,
    status: analysisResult.status,
    invoiceAnalysis: analysisResult.invoiceAnalysis,
    isInvoice: analysisResult.isInvoice
  };
}
