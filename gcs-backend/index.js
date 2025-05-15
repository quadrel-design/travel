/**
 * @file Main entry point for the GCS backend Express application.
 * This file initializes the Firebase Admin SDK, sets up the Express server with
 * necessary middleware (CORS, JSON parsing), loads environment variables,
 * mounts all API routes, initializes the PostgreSQL database schema,
 * and starts the HTTP server.
 * @author Your Name/Team
 * @version 1.0.0
 */

const admin = require('firebase-admin');

try {
  // Check if the app is already initialized to prevent re-initialization errors
  if (admin.apps.length === 0) {
    admin.initializeApp({
      // Using Application Default Credentials.
      // Ensure your Cloud Run service account has necessary Firebase permissions.
      // projectId: process.env.GOOGLE_CLOUD_PROJECT, // Usually inferred by ADC
    });
    console.log('✅ Firebase Admin SDK initialized successfully.');
  } else {
    console.log('✅ Firebase Admin SDK already initialized.');
  }
} catch (e) {
  console.error('❌ CRITICAL ERROR initializing Firebase Admin SDK:', e);
  // Consider how to handle this error; e.g., prevent app from fully starting
}

// PostgreSQL Pool is initialized in config/db.js and imported by services as needed.
const pool = require('./config/db'); // Import the pool to pass to init or check status
const initializeDatabase = require('./config/db-init');

// For debugging, let's ensure these are still logged to see what Cloud Run provides:
console.log('[ENV CHECK] GOOGLE_CLOUD_PROJECT:', process.env.GOOGLE_CLOUD_PROJECT);
console.log('[ENV CHECK] GOOGLE_APPLICATION_CREDENTIALS:', process.env.GOOGLE_APPLICATION_CREDENTIALS); // Should ideally be unset if relying on ADC

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

// Pass the db instances to the routes/services
// TODO: Refactor routes to accept and use postgresServiceInstance
const ocrRoutes = require('./routes/ocr');
const analysisRoutes = require('./routes/analysis');
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

const projectRoutes = require('./routes/projects');
app.use('/api/projects', projectRoutes);

/**
 * User Subscription Routes
 * 
 * These routes handle user subscription-related operations such as toggling
 * between 'pro' and 'free' subscription tiers. The routes use Firebase Auth
 * custom claims to store and retrieve the user's subscription status.
 * 
 * Mounted at: /api/user
 * Available endpoints:
 * - POST /api/user/toggle-subscription: Toggle between pro/free subscription
 */
const userSubscriptionRoutes = require('./routes/userSubscription');
app.use('/api/user', userSubscriptionRoutes);

// Root health check
app.get('/', (req, res) => {
  res.send('API is running!');
});

const PORT = process.env.PORT || 8080;

/**
 * Initializes the database schema and starts the Express server.
 * This function first checks if the PostgreSQL connection pool is available.
 * If so, it attempts to initialize/update the database schema using `initializeDatabase`.
 * Only if the schema initialization is successful does it start the Express server
 * to listen on the configured PORT.
 * If the pool is not available or schema initialization fails, critical errors are logged,
 * and the server does not start.
 * @async
 */
async function startServer() {
  if (pool) { // Check if pool was created successfully in db.js
    console.log('[INDEX.JS] Database pool available. Initializing schema...');
    const dbInitialized = await initializeDatabase(pool);
    if (dbInitialized) {
      console.log('[INDEX.JS] Database schema initialization successful or already up-to-date.');
      app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
    } else {
      console.error('[INDEX.JS] CRITICAL: Database schema initialization failed. Server will not start.');
      // process.exit(1); // Or handle more gracefully, e.g. keep trying or enter maintenance mode
    }
  } else {
    console.error('[INDEX.JS] CRITICAL: Database pool not available. Server will not start.');
    // process.exit(1);
  }
}

startServer();