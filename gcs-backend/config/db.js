/**
 * @file PostgreSQL Database Configuration and Pool Setup
 * This module configures and initializes a connection pool for the PostgreSQL database.
 * It reads database connection parameters from environment variables (supports `.env` for local development).
 * Key responsibilities:
 *  - Load environment variables.
 *  - Validate presence of required DB environment variables in production.
 *  - Construct the `pg.Pool` configuration object, including SSL settings for production.
 *  - Create and export the PostgreSQL connection pool instance.
 *  - Set up event listeners for pool events (connect, acquire, error).
 *  - Perform an initial connection test query.
 * It handles errors during pool creation by logging them but allows the application to attempt to start
 * (services relying on the DB will fail if the pool is not available).
 * @module config/db
 */
const { Pool } = require('pg');
const logger = require('./logger'); // Import logger
require('dotenv').config(); // For local development, Cloud Run uses its own env var system

if (process.env.NODE_ENV !== 'production') {
  logger.info('[DB Config] Loading .env variables for non-production environment.');
  // In development, ensure local .env file has these if you're not using Cloud SQL Proxy
  // For Cloud Run, these are set in the service configuration.
}

logger.info(`[DB Config] DB_HOST: ${process.env.DB_HOST}`);
logger.info(`[DB Config] DB_USER: ${process.env.DB_USER}`);
logger.info(`[DB Config] DB_NAME: ${process.env.DB_NAME}`);
logger.info(`[DB Config] DB_PORT: ${process.env.DB_PORT || 5432}`);
logger.info(`[DB Config] NODE_ENV: ${process.env.NODE_ENV}`);

const requiredEnvVars = ['DB_HOST', 'DB_USER', 'DB_PASSWORD', 'DB_NAME'];
const missingEnvVars = requiredEnvVars.filter(v => !process.env[v]);

if (missingEnvVars.length > 0 && process.env.NODE_ENV === 'production') {
  // Only throw error in production if critical DB vars are missing.
  // For local dev, user might be using a different setup or expecting services to fail gracefully if DB is not up.
  logger.error(`[DB Config] CRITICAL ERROR: Missing required database environment variables: ${missingEnvVars.join(', ')}`);
  // In a real production scenario, you might want to prevent the app from starting or throw a more specific error.
  // For Cloud Run, this would ideally cause the revision to fail deployment if essential vars aren't set.
}

const isProduction = process.env.NODE_ENV === 'production';

// Base configuration
const dbConfig = {
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  host: process.env.DB_HOST, // Usually set for cloud or specific non-local setups
  port: process.env.DB_PORT ? parseInt(process.env.DB_PORT, 10) : 5432,
  ssl: isProduction ? { rejectUnauthorized: false } : false, // Use SSL in production
  // statement_timeout: 5000, // milliseconds, terminate any statement that takes >5s
  // query_timeout: 5000,    // milliseconds, terminate any query that takes >5s
  // idle_in_transaction_session_timeout: 10000, // milliseconds, terminate any session with an open transaction that has been idle for >10s
  // connectionTimeoutMillis: isProduction ? 2000 : 5000, // Time to wait for connection: 2s prod, 5s dev
  // idleTimeoutMillis: isProduction ? 10000 : 30000, // Close idle clients after 10s (prod) / 30s (dev)
  // max: 20, // Max number of clients in the pool
};

// Cloud SQL specific configuration (for production)
if (isProduction && process.env.DB_SOCKET_PATH) {
  dbConfig.host = process.env.DB_SOCKET_PATH;
  // logger.info('[DB Config] Using Cloud SQL Socket Path:', dbConfig.host); // This was already commented, removing for cleanliness
}

// Log the configuration being used (excluding password for security)
const loggableConfig = { ...dbConfig };
delete loggableConfig.password;
logger.info('[DB Config] Database configuration:', loggableConfig);

const pool = new Pool(dbConfig);

pool.on('connect', (client) => {
  logger.info('[DB Pool] Client connected to the database.');
  // You can set session parameters here if needed, e.g.:
  // client.query('SET SESSION CHARACTERISTICS AS TRANSACTION READ WRITE;');
});

pool.on('acquire', (client) => {
  logger.debug('[DB Pool] Client acquired from pool.');
});

pool.on('remove', (client) => {
  logger.debug('[DB Pool] Client removed from pool (released).');
});

pool.on('error', (err, client) => {
  logger.error('[DB Pool] Unexpected error on idle client', { error: err, clientInfo: client ? client.processID : 'N/A' });
  // Recommended to exit the process if a serious error occurs with the pool
  // process.exit(-1);
});

// Test the connection (optional, but good for startup diagnostics)
pool.query('SELECT NOW()', (err, res) => {
  if (err) {
    logger.error('[DB Pool] Initial connection test query failed:', err.stack);
    // This might indicate a problem with DB connectivity or credentials
    // Depending on policy, you might want to throw an error here to stop app startup if DB is essential
  } else {
    logger.info('[DB Pool] Initial connection test query successful:', res.rows[0]);
  }
});

module.exports = {
  query: (text, params) => pool.query(text, params),
  getClient: async () => {
    const client = await pool.connect();
    logger.debug('[DB Pool] Manual client checkout.');
    // The original query and release methods are preserved here if needed for direct use or restoration.
    // const originalQuery = client.query;
    // const originalRelease = client.release;
    // For now, we are not applying any monkey-patching or advanced timeout logic.
    // If specific needs arise, this section can be revisited.
    return client;
  },
  pool, // Export the pool itself if direct access is needed for specific pg features
}; 