/**
 * Database Initialization Script
 * 
 * This script runs the schema.sql file to initialize the database tables
 * when the application starts up. It handles PL/pgSQL DO blocks correctly.
 */

const fs = require('fs');
const path = require('path');

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