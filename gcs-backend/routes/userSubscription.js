/**
 * User Subscription Routes
 * 
 * This module provides endpoints for managing user subscription status in Firebase Auth.
 * It enables toggling between 'pro' and 'free' subscription tiers by updating
 * custom claims in the Firebase Auth user profile.
 */

const express = require('express');
const router = express.Router();
const firebaseAdmin = require('firebase-admin');
const subscriptionService = require('../services/userSubscriptionService');

/**
 * Middleware to verify Firebase ID token from request headers
 * 
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 * @returns {void}
 */
const verifyIdToken = async (req, res, next) => {
  if (firebaseAdmin.apps.length === 0) {
    console.error('[Routes/UserSubscription][AuthMiddleware] Firebase Admin SDK not initialized. Cannot authenticate.');
    return res.status(500).json({ error: 'Authentication service not configured.' });
  }
  const idToken = req.headers.authorization?.split('Bearer ')[1];
  if (!idToken) return res.status(401).json({ error: 'Unauthorized: No token provided' });

  try {
    const decodedToken = await firebaseAdmin.auth().verifyIdToken(idToken);
    req.user = decodedToken;
    next();
  } catch (error) {
    console.error('[Routes/UserSubscription][AuthMiddleware] Error verifying token:', error);
    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({ error: 'Unauthorized: Token expired', code: 'TOKEN_EXPIRED' });
    }
    return res.status(401).json({ error: 'Unauthorized: Invalid token' });
  }
};

/**
 * Toggle user subscription status between 'pro' and 'free'
 * 
 * This endpoint retrieves the current user subscription status from Firebase Auth
 * custom claims and toggles it between 'pro' and 'free'. The updated status is
 * stored back in the user's custom claims and returned in the response.
 * 
 * @route POST /toggle-subscription
 * @authentication Requires Firebase ID token in Authorization header
 * @returns {Object} JSON response containing success status and new subscription value
 */
router.post('/toggle-subscription', verifyIdToken, async (req, res) => {
  try {
    const uid = req.user.uid;
    if (!subscriptionService || typeof subscriptionService.toggleUserSubscription !== 'function') {
      console.error('[Routes/UserSubscription] subscriptionService.toggleUserSubscription is not available!');
      return res.status(500).json({ error: 'Subscription service not configured correctly.' });
    }
    const newStatus = await subscriptionService.toggleUserSubscription(uid);
    res.json({ success: true, subscription: newStatus });
  } catch (error) {
    console.error('[Routes/UserSubscription] Error toggling subscription:', error.message, error.stack);
    res.status(500).json({ error: error.message || 'Failed to toggle subscription' });
  }
});

/**
 * Get the current user's subscription status
 * 
 * @route GET /subscription-status
 * @authentication Requires Firebase ID token in Authorization header
 * @returns {Object} JSON response containing the current subscription status
 */
router.get('/subscription-status', verifyIdToken, async (req, res) => {
  try {
    const uid = req.user.uid;
    if (!subscriptionService || typeof subscriptionService.getUserSubscription !== 'function') {
      console.error('[Routes/UserSubscription] subscriptionService.getUserSubscription is not available!');
      return res.status(500).json({ error: 'Subscription service not configured correctly.' });
    }
    const status = await subscriptionService.getUserSubscription(uid);
    res.json({ subscription: status });
  } catch (error) {
    console.error('[Routes/UserSubscription] Error getting subscription status:', error.message, error.stack);
    res.status(500).json({ error: error.message || 'Failed to get subscription status' });
  }
});

console.log('[Routes/UserSubscription] Routes defined, exporting router.');
module.exports = router; 