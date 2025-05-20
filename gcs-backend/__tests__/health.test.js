const request = require('supertest');
const app = require('../index'); // Adjust path if your app export is elsewhere

describe('GET /api/health', () => {
  let server;

  // Start server before tests and close after tests if your app doesn't start automatically
  // For Express apps that immediately listen, this might not be strictly necessary
  // if 'app' itself is the server instance or can be passed to supertest directly.
  // However, if index.js starts a server on a port, you might need to handle it.
  // Given that index.js calls app.listen(), we might not need to explicitly start/stop here
  // if supertest can handle an already listening app or if it intelligently uses the app instance.

  // For now, we assume supertest(app) works correctly with the exported app instance from index.js
  // which already calls app.listen() via startServer().

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