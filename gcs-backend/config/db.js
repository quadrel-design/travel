const { Pool } = require('pg');
require('dotenv').config(); // For local development, Cloud Run uses its own env var system

if (process.env.NODE_ENV !== 'production') {
  console.log('[DB Config] Loading .env variables for non-production environment.');
  // In development, ensure local .env file has these if you're not using Cloud SQL Proxy
  // For Cloud Run, these are set in the service configuration.
}

console.log(`[DB Config] DB_HOST: ${process.env.DB_HOST}`);
console.log(`[DB Config] DB_USER: ${process.env.DB_USER}`);
console.log(`[DB Config] DB_NAME: ${process.env.DB_NAME}`);
console.log(`[DB Config] DB_PORT: ${process.env.DB_PORT || 5432}`);
console.log(`[DB Config] NODE_ENV: ${process.env.NODE_ENV}`);

const requiredEnvVars = ['DB_HOST', 'DB_USER', 'DB_PASSWORD', 'DB_NAME'];
const missingEnvVars = requiredEnvVars.filter(v => !process.env[v]);

if (missingEnvVars.length > 0 && process.env.NODE_ENV === 'production') {
  // Only throw error in production if critical DB vars are missing.
  // For local dev, user might be using a different setup or expecting services to fail gracefully if DB is not up.
  console.error(`[DB Config] CRITICAL ERROR: Missing required database environment variables: ${missingEnvVars.join(', ')}`);
  // In a real production scenario, you might want to prevent the app from starting or throw a more specific error.
  // For Cloud Run, this would ideally cause the revision to fail deployment if essential vars aren't set.
}

const dbConfig = {
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  port: parseInt(process.env.DB_PORT || '5432', 10),
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false, // Basic SSL for production, adjust as needed
  max: 20, // Max number of clients in the pool
  idleTimeoutMillis: 30000, // How long a client is allowed to remain idle before being closed
  connectionTimeoutMillis: 5000, // How long to wait for a connection from the pool
};

console.log('[DB Config] Attempting to create PostgreSQL Pool...');
let pool;
try {
  pool = new Pool(dbConfig);
  console.log('[DB Config] PostgreSQL Pool created successfully.');

  pool.on('connect', client => {
    console.log('[DB Pool] Client connected to database.');
    // You can set session parameters here if needed, e.g.:
    // client.query('SET DATESTYLE = iso, mdy;');
  });

  pool.on('acquire', client => {
    console.log('[DB Pool] Client acquired from pool.');
  });

  pool.on('error', (err, client) => {
    console.error('[DB Pool] Unexpected error on idle client', err);
    // process.exit(-1); // Consider if critical enough to exit
  });

  // Test the connection (optional, but good for startup diagnostics)
  pool.query('SELECT NOW()', (err, res) => {
    if (err) {
      console.error('[DB Pool] Initial connection test query failed:', err.stack);
      // This might indicate a problem with DB connectivity or credentials
      // Depending on policy, you might want to throw an error here to stop app startup if DB is essential
    } else {
      console.log('[DB Pool] Initial connection test query successful:', res.rows[0]);
    }
  });

} catch (error) {
  console.error('[DB Config] CRITICAL ERROR creating PostgreSQL Pool:', error);
  // If the pool cannot be created, the application likely cannot function.
  // Consider throwing this error to halt startup, especially in production.
  // throw error; 
  // For now, we log and allow the app to continue starting, but services will fail.
  console.warn('[DB Config] Application will continue to start, but database services will likely fail.');
}

module.exports = pool; 