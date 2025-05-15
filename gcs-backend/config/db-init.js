/**
 * @file Database Schema Initialization Script
 * This script is responsible for applying the database schema defined in `schema.sql`.
 * It reads the SQL file and executes its content against the PostgreSQL database
 * using the provided connection pool.
 * This is typically run once at application startup to ensure the database
 * tables and structures are correctly set up.
 * It is designed to be idempotent due to the `IF NOT EXISTS` clauses in `schema.sql`.
 * @module config/db-init
 */

const fs = require('fs');
const path = require('path');

/**
 * Initializes the database by executing the `schema.sql` file.
 * Takes a PostgreSQL connection pool as input.
 * Logs success or detailed errors to the console.
 *
 * @async
 * @function initializeDatabase
 * @param {import('pg').Pool} pool - The PostgreSQL connection pool instance from `config/db.js`.
 * @returns {Promise<boolean>} True if schema initialization was successful, false otherwise.
 *                                 A return value of false indicates a critical failure and the application
 *                                 should typically not proceed to start the server.
 */
module.exports = async function initializeDatabase(pool) {
  if (!pool) {
    console.error('❌ Database initialization failed: No valid PostgreSQL pool provided');
    return false; // Return false to indicate critical failure to initialize pool
  }

  try {
    // Read the schema file
    const schemaPath = path.join(__dirname, 'schema.sql');
    const schemaSQL = fs.readFileSync(schemaPath, 'utf8');

    console.log('⏳ Initializing database schema by executing schema.sql...');
    
    // Execute the entire schema.sql content as a single query
    await pool.query(schemaSQL);
    
    console.log('✅ Database schema initialized successfully from schema.sql');
    return true; // Indicate success
  } catch (error) {
    console.error('❌❌❌ CRITICAL: Error initializing database schema from schema.sql:');
    console.error('Error Name:', error.name);
    console.error('Error Message:', error.message);
    console.error('Error Code:', error.code); // PostgreSQL error code if available
    console.error('Error Position:', error.position); // Position of error in query string
    console.error('Full Error:', error);
    // Do not continue execution if schema fails critically
    // This will allow the main application startup to halt or handle this failure
    return false; 
  }
}; 