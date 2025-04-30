/**
 * Main entry point for Firebase Functions
 * 
 * This file exports all functions from specialized modules in the invoice-capture folder.
 */

// Initialize Firebase Admin
import * as admin from "firebase-admin";
try {
  admin.initializeApp();
  console.log("Firebase Admin initialized successfully in index.ts");
} catch (e) {
  console.log(
    "Firebase Admin initialization error:",
    e instanceof Error ? e.message : String(e),
  );
}

// Load environment variables from .env file
import * as dotenv from "dotenv";
dotenv.config();

// Environment variables like GOOGLE_CLOUD_PROJECT
// should be set via Firebase Runtime Configuration or system environment variables.
// Removing hardcoded fallbacks. Ensure they are configured during deployment.
// Example: firebase functions:config:set other.setting="value"
// Or set via Google Cloud Functions environment variables settings.

// Export functions from migration directory
// export * from './migration/rename-projectss-to-invoices'; // Commented out if not present

// Export functions from invoice-capture directory
// export * from "./invoice-capture/invoice-image-detection";
// export * from "./invoice-capture/invoice-capture";
export * from "./invoice-capture/text-analysis";
export { detectImage } from "./invoice-capture/invoice-image-detection";

// --- Billing Functions --- 
// import * as functions from 'firebase-functions'; // Using v1 SDK - Removed as unused
// Import v2 scheduler
// import { onSchedule } from "firebase-functions/v2/scheduler";
// --- Helper & Test Functions --- 

// Export helper function for testing
// import { detectTextInImage } from "./invoice-capture/invoice-image-detection";
// import { analyzeDetectedText } from "./invoice-capture/text-analysis";
