/**
 * @file update-pricing-now.ts
 * @description One-time script to update the Google Vision API pricing in Firestore.
 * Run with: npx ts-node src/billing/update-pricing-now.ts
 */

import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { getCurrentVisionApiPrice } from "./google-vision-api-pricing";

// Initialize Firebase
const app = initializeApp();

// Initialize Firestore
const db = getFirestore(app);

/**
 * Configuration for Vision API pricing
 */
const VISION_API_CONFIG = {
  displayName: 'Cloud Vision API',
  documentName: 'Google Vision',
  description: 'Google Cloud Vision API OCR/Text Detection Service'
};

/**
 * Updates the Vision API pricing information in Firestore
 * This is a manual update script to run the same functionality as the scheduled function
 */
async function updateVisionApiPricing(): Promise<void> {
  console.log("Starting manual update of Vision API pricing in Firestore...");

  try {
    // Get the current pricing data
    const priceInfo = await getCurrentVisionApiPrice();
    
    // Create the Vision API pricing data
    const visionApiPricing = {
      serviceType: 'OCR/Text Detection',
      priceUnit: priceInfo.priceUnit,
      provider: 'Google Cloud',
      pricePerUse: priceInfo.pricePerUse,
      pricePerSingleUse: priceInfo.pricePerSingleUse,
      description: VISION_API_CONFIG.description,
      currency: priceInfo.currency,
      costOverall: 0, // This will be calculated elsewhere as usage accumulates
      currentPriceModel: 'Pay as you go',
      freeTierLimit: priceInfo.freeTierLimit,
      lastUpdate: FieldValue.serverTimestamp()
    };
    
    // Update Firestore
    const visionRef = db.collection('cloud-pricing').doc(VISION_API_CONFIG.documentName);
    await visionRef.set(visionApiPricing, { merge: true });
    console.log(`Successfully updated 'cloud-pricing/${VISION_API_CONFIG.documentName}' with current pricing: ${priceInfo.pricePerSingleUse} ${priceInfo.currency} per single request (${priceInfo.pricePerUse} ${priceInfo.currency} per ${priceInfo.priceUnit})`);
    console.log(`Free tier: ${priceInfo.freeTierLimit} requests per month`);
    
    console.log("Vision API pricing update completed successfully!");
  } catch (error) {
    console.error("Error updating Vision API pricing:", error);
  }
}

// Run the function and exit when complete
updateVisionApiPricing()
  .then(() => {
    console.log("Database update script completed.");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Error in database update script:", error);
    process.exit(1);
  }); 