const request = require('supertest');
const app = require('../index'); // Adjust path if your app export is elsewhere
const { pool } = require('../config/db'); // Import the pool to close it after tests

describe('GET /api/health', () => {
  // let server; // server variable likely not needed if supertest(app) is used directly

  afterAll(async () => {
    await pool.end(); // Close the database pool to allow Jest to exit cleanly
  });

  it('should respond with 200 and a healthy status', async () => {
    const response = await request(app).get('/api/health');
    expect(response.statusCode).toBe(200);
    expect(response.body.status).toBe('healthy');
    expect(response.body).toHaveProperty('timestamp');
    // Check if the timestamp is a valid ISO string (optional, but good practice)
    expect(new Date(response.body.timestamp).toISOString()).toBe(response.body.timestamp);
  });

  // Add another test to check the root path as well, since it exists
  it('should respond with 200 and API is running! for the root path', async () => {
    const response = await request(app).get('/');
    expect(response.statusCode).toBe(200);
    expect(response.text).toBe('API is running!');
  });
}); 