// Load environment variables from .env file for tests
require('dotenv').config();

// Mock Firebase Admin if needed
/*
jest.mock('firebase-admin', () => {
  return {
    initializeApp: jest.fn(),
    credential: {
      applicationDefault: jest.fn(),
    },
    firestore: jest.fn().mockReturnValue({
      collection: jest.fn().mockReturnThis(),
      doc: jest.fn().mockReturnThis(),
      get: jest.fn(),
      set: jest.fn(),
      update: jest.fn(),
    }),
  };
});
*/ 