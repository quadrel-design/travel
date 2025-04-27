/**
 * Orchestrates the fetching of pricing information for various Google Cloud services
 * (like Vision API, Storage, etc.) using dedicated pricing modules and the
 * `CloudPricingService`. Updates the fetched pricing in the `pricing` Firestore collection.
 * Can also be run manually via `node update-all-pricing.ts`.
 */
import * as admin from 'firebase-admin';
import { logger } from "firebase-functions"; // Use v2 logger
import { CloudPricingService } from './cloud-pricing';
import { getFormattedVisionOcrPricing, FormattedCloudServicePricing } from './vision-api.pricing';
// Import functions for other services here as they are created
// import { getFormattedStoragePricing } from './cloud-storage.pricing'; 
// import { getFormattedFunctionsPricing } from './cloud-functions.pricing';
// import { getFormattedComputePricing } from './compute-engine.pricing';

// Initialize Firebase Admin SDK (handles potential re-initialization)
try {
  admin.initializeApp();
  logger.info('Firebase Admin initialized for update script.');
} catch (e) {
  logger.info('Firebase Admin already initialized.');
}

// Firestore database reference
const db = admin.firestore();
// Reference to the 'pricing' collection
const pricingCollectionRef = db.collection('pricing');

/**
 * Updates Firestore document with provided pricing data.
 * 
 * @param docId The Firestore document ID (e.g., 'google-vision-api')
 * @param pricingData The formatted pricing data for the service.
 */
async function updateServicePricingInFirestore(
  docId: string, 
  pricingData: FormattedCloudServicePricing | null
) {
  if (!pricingData) {
    logger.error(`Skipping Firestore update for ${docId} due to missing pricing data.`);
    return;
  }

  const docRef = pricingCollectionRef.doc(docId);
  
  // Prepare data for Firestore, replacing placeholder date with server timestamp
  const dataToSave = {
    ...pricingData,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp() 
  };

  try {
    logger.info(`Updating Firestore for ${docId}...`);
    await docRef.set(dataToSave, { merge: true });
    logger.info(`Successfully updated Firestore for ${docId}.`);
  } catch (error) {
    const errorMessage = (error instanceof Error) ? error.message : String(error);
    logger.error(`Failed to update Firestore for ${docId}:`, { error: errorMessage });
  }
}

/**
 * Main orchestration function.
 * Initializes `CloudPricingService`, calls individual service pricing functions,
 * and triggers Firestore updates for each service.
 */
async function updateAllPricing() {
  logger.info('Starting update process for all service pricing...');
  const pricingService = new CloudPricingService();

  // --- Vision API Pricing ---
  const visionPricing = await getFormattedVisionOcrPricing(pricingService);
  await updateServicePricingInFirestore('google-vision-api', visionPricing);

  // --- Cloud Storage Pricing (Example - uncomment when file exists) ---
  // const storagePricing = await getFormattedStoragePricing(pricingService);
  // await updateServicePricingInFirestore('google-cloud-storage', storagePricing);

  // --- Cloud Functions Pricing (Example - uncomment when file exists) ---
  // const functionsPricing = await getFormattedFunctionsPricing(pricingService);
  // await updateServicePricingInFirestore('google-cloud-functions', functionsPricing);
  
  // --- Compute Engine Pricing (Example - uncomment when file exists) ---
  // const computePricing = await getFormattedComputePricing(pricingService);
  // await updateServicePricingInFirestore('google-compute-engine', computePricing);

  logger.info('Finished update process for all service pricing.');
}

// --- Manual Execution Block ---
// Execute the update function if running this script directly
// e.g., using `node functions/lib/billing/update-all-pricing.js` after compiling
if (require.main === module) {
  updateAllPricing().then(() => {
    logger.info('Manual pricing update script finished successfully.');
    process.exit(0);
  }).catch(error => {
    const errorMessage = (error instanceof Error) ? error.message : String(error);
    logger.error('Manual pricing update script failed:', { error: errorMessage });
    process.exit(1);
  });
}

// Export the main function so it can be called by the scheduled task
export { updateAllPricing }; 