const firebaseAdmin = require('firebase-admin');
const logger = require('../config/logger');

/**
 * Middleware to authenticate users using Firebase ID tokens.
 * Verifies the Bearer token from the Authorization header.
 * Attaches the decoded token (including user UID and email) to `req.user`.
 *
 * @async
 * @param {import('express').Request} req - Express request object.
 * @param {import('express').Response} res - Express response object.
 * @param {import('express').NextFunction} next - Express next middleware function.
 */
const authenticateUser = async (req, res, next) => {
  if (firebaseAdmin.apps.length === 0) {
    logger.error('[AuthMiddleware] Firebase Admin SDK not initialized. Cannot authenticate.');
    return res.status(500).json({ error: 'Authentication service not configured.' });
  }
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      logger.warn('[AuthMiddleware] Unauthorized: No token provided or malformed header.', {
        ip: req.ip,
        method: req.method,
        url: req.originalUrl,
        headers: req.headers,
      });
      return res.status(401).json({ error: 'Unauthorized: No token provided' });
    }

    const token = authHeader.split(' ')[1];
    const decodedToken = await firebaseAdmin.auth().verifyIdToken(token);
    
    req.user = {
      id: decodedToken.uid,
      email: decodedToken.email,
      // Potentially add other useful fields from decodedToken if needed
    };
    
    logger.debug('[AuthMiddleware] User authenticated successfully.', { userId: req.user.id, email: req.user.email });
    next();
  } catch (error) {
    logger.error('[AuthMiddleware] Error authenticating user:', {
      message: error.message,
      code: error.code,
      stack: error.stack, // Be cautious logging full stack in production for security
      ip: req.ip,
      method: req.method,
      url: req.originalUrl,
    });
    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({ error: 'Unauthorized: Token expired', code: 'TOKEN_EXPIRED' });
    }
    if (error.code === 'auth/argument-error') {
      logger.error('[AuthMiddleware] Firebase ID token verification failed. This might be due to an emulator issue, misconfiguration, or an invalid token format.');
    }
    return res.status(401).json({ error: 'Unauthorized: Invalid token' });
  }
};

module.exports = authenticateUser; 