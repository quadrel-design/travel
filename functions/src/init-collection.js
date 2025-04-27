const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { initializeApp, getApps, getApp } = require('firebase-admin/app');

// Get existing app or initialize Firebase Admin
let app;
try {
  app = getApps().length === 0 ? initializeApp() : getApp();
  console.log("Firebase Admin initialized successfully");
} catch (error) {
  console.error("Firebase initialization error:", error);
  process.exit(1);
}

// Initialize Firestore
const db = getFirestore(app);

// Create cloud-pricing collection with metadata
async function createCloudPricingCollection() {
  try {
    // Create _metadata document
    await db.collection('cloud-pricing').doc('_metadata').set({
      collectionCreated: FieldValue.serverTimestamp(),
      lastUpdated: FieldValue.serverTimestamp(),
      purpose: "Store API pricing information for cost calculations",
      version: "1.0"
    });
    console.log("Created _metadata document in cloud-pricing collection");

    // Create default apiPrices document with fallback price
    await db.collection('cloud-pricing').doc('apiPrices').set({
      google_vision_api_per_unit: 0.00025, // Fallback price
      lastPriceUpdateTimestamp: FieldValue.serverTimestamp(),
      currency: 'EUR'
    });
    console.log("Created apiPrices document in cloud-pricing collection");

    console.log("Successfully created cloud-pricing collection in Firestore");
    return true;
  } catch (error) {
    console.error("Error creating cloud-pricing collection:", error);
    return false;
  }
}

// Run the function
createCloudPricingCollection().then((success) => {
  console.log("Script completed with status:", success ? "Success" : "Failed");
  process.exit(success ? 0 : 1);
}).catch(err => {
  console.error("Script failed:", err);
  process.exit(1);
}); 