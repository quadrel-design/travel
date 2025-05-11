const admin = require('firebase-admin');
let dbAdminInstance = null;
const ADMIN_APP_NAME = 'splitbaseAdminApp'; // Define a name for the app

try {
  // Check if the app is already initialized to prevent re-initialization errors
  if (!admin.apps.find(app => app && app.name === ADMIN_APP_NAME)) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(), // Explicitly use ADC
      // projectId: process.env.GOOGLE_CLOUD_PROJECT, // GOOGLE_CLOUD_PROJECT should be picked up by ADC
    }, ADMIN_APP_NAME); // Give the app a specific name
    console.log(`✅ Firebase Admin SDK initialized successfully with name: ${ADMIN_APP_NAME}`);
  } else {
    console.log(`✅ Firebase Admin SDK app named '${ADMIN_APP_NAME}' already exists.`);
  }

  const adminApp = admin.app(ADMIN_APP_NAME); // Get the named app instance
  dbAdminInstance = adminApp.firestore(); // Get Firestore from the named app
  console.log(`✅ Firestore instance obtained from app '${ADMIN_APP_NAME}'.`);

  // TRY THIS: Explicitly pass projectId to the settings of this Firestore instance
  try {
    const projectIdEnv = process.env.GOOGLE_CLOUD_PROJECT;
    if (projectIdEnv) {
      dbAdminInstance.settings({
        projectId: projectIdEnv,
        // credentials: admin.credential.applicationDefault() // This might also be an option if projectId alone isn't enough
      });
      console.log(`✅ Explicitly set projectId: ${projectIdEnv} on dbAdminInstance settings.`);
    } else {
      console.warn('⚠️ GOOGLE_CLOUD_PROJECT env var not found when trying to set dbAdminInstance.settings()');
    }
  } catch (settingsError) {
    console.error('❌ Error trying to set explicit projectId on dbAdminInstance.settings():', settingsError);
  }

  // Test Firestore connection with a new collection name for this test
  dbAdminInstance.collection('admin-startup-test-named-app').limit(1).get()
    .then(snap => {
      console.log(`✅ [ADMIN-NAMED-APP] Firestore query SUCCEEDED. Count: ${snap.size}`);
    })
    .catch(err => {
      console.error('❌ [ADMIN-NAMED-APP] Firestore query FAILED:', err);
    });

} catch (e) {
  console.error('❌ CRITICAL ERROR initializing Firebase Admin SDK with named app:', e);
  // If dbAdminInstance is critical for app operation, consider throwing e to halt startup
}

// For debugging, let's ensure these are still logged to see what Cloud Run provides:
console.log('[ENV CHECK] GOOGLE_CLOUD_PROJECT:', process.env.GOOGLE_CLOUD_PROJECT);
console.log('[ENV CHECK] GOOGLE_APPLICATION_CREDENTIALS:', process.env.GOOGLE_APPLICATION_CREDENTIALS); // Should ideally be unset if relying on ADC

// The existing startup check using standalone @google-cloud/firestore
// can be kept for comparison or removed if admin.initializeApp() is preferred for all Firestore access.
console.log('[TOP] Attempting Firestore minimal check (standalone client)...');
try {
  const { Firestore } = require('@google-cloud/firestore');
  console.log('[TOP] Firestore library loaded.');
  const dbStandalone = new Firestore();
  console.log('[TOP] Firestore client initialized.');
  dbStandalone.collection('startup-test').limit(1).get()
    .then(snap => {
      console.log('✅ [TOP] Firestore startup-test query SUCCEEDED. Count:', snap.size);
    })
    .catch(err => {
      console.error('❌ [TOP] Firestore startup-test query FAILED:', err);
    });
} catch (e) {
  console.error('❌ [TOP] CRITICAL ERROR initializing/querying Firestore at startup:', e);
}

/**
 * Main entry point for the GCS backend API.
 * Sets up Express server, middleware, and routes.
 */

require('dotenv').config(); // <-- Load environment variables from .env

const express = require('express');
const cors = require('cors');
const app = express();
app.use(cors());
app.use(express.json());

// Debug log to check environment variables
console.log('GOOGLE_CLOUD_PROJECT (in index.js route setup):', process.env.GOOGLE_CLOUD_PROJECT);
console.log('GOOGLE_APPLICATION_CREDENTIALS:', process.env.GOOGLE_APPLICATION_CREDENTIALS);

// Minimal Firestore Write Test Endpoint
app.get('/test-firestore-write', async (req, res) => {
  console.log('[TEST ENDPOINT] /test-firestore-write called.');
  if (!dbAdminInstance) {
    console.error('[TEST ENDPOINT] dbAdminInstance is not available!');
    return res.status(500).send('Error: dbAdminInstance not initialized.');
  }
  try {
    const testDocRef = dbAdminInstance.collection('minimal-test-writes').doc('test-doc-' + Date.now());
    await testDocRef.set({
      message: 'Hello from minimal test endpoint!',
      timestamp: new Date()
    });
    console.log('[TEST ENDPOINT] Successfully wrote to Firestore collection minimal-test-writes.');
    res.status(200).send('Successfully wrote to Firestore!');
  } catch (error) {
    console.error('[TEST ENDPOINT] Error writing to Firestore:', error);
    // Send the specific error message and stack if possible
    const errorMessage = error.message || 'Unknown error';
    const errorStack = error.stack || 'No stack available';
    res.status(500).send(`Error writing to Firestore: ${errorMessage}\nStack: ${errorStack}`);
  }
});

// Pass the db instance to the routes/services
const ocrRoutes = require('./routes/ocr')(dbAdminInstance); // Pass db instance
const analysisRoutes = require('./routes/analysis')(dbAdminInstance); // Pass db instance
// Assuming gcs routes do not need db, or will be refactored similarly if they do
console.log('[INDEX.JS] Attempting to load gcsRoutes from ./routes/gcs...');
const gcsRoutes = require('./routes/gcs'); 
console.log('[DEBUG] typeof gcsRoutes:', typeof gcsRoutes);
console.log('[DEBUG] gcsRoutes object:', gcsRoutes); // Express routers are functions with properties

try {
  app.use('/api/gcs', gcsRoutes);
  console.log('[INDEX.JS] gcsRoutes loaded and mounted at /api/gcs.');
} catch (e) {
  console.error('[DEBUG] CRITICAL ERROR mounting /api/gcs routes:', e);
}

app.use(ocrRoutes);
app.use(analysisRoutes);

// Root health check
app.get('/', (req, res) => {
  res.send('API is running!');
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));