/**
 * User Subscription Routes
 * 
 * This module provides endpoints for managing user subscription status in Firebase Auth.
 * It enables toggling between 'pro' and 'free' subscription tiers by updating
 * custom claims in the Firebase Auth user profile.
 */

const express = require('express');
const router = express.Router();
const admin = require('firebase-admin');
const subscriptionService = require('../services/userSubscriptionService')();

/**
 * Middleware to verify Firebase ID token from request headers
 * 
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 * @returns {void}
 */
const verifyIdToken = async (req, res, next) => {
  const idToken = req.headers.authorization?.split('Bearer ')[1];
  if (!idToken) return res.status(401).json({ error: 'No token provided' });

  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    req.user = decodedToken;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid token' });
  }
};

/**
 * Toggle user subscription status between 'pro' and 'free'
 * 
 * This endpoint retrieves the current user subscription status from Firebase Auth
 * custom claims and toggles it between 'pro' and 'free'. The updated status is
 * stored back in the user's custom claims and returned in the response.
 * 
 * @route POST /api/user/toggle-subscription
 * @authentication Requires Firebase ID token in Authorization header
 * @returns {Object} JSON response containing success status and new subscription value
 */
router.post('/toggle-subscription', verifyIdToken, async (req, res) => {
  try {
    const uid = req.user.uid;
    const newStatus = await subscriptionService.toggleUserSubscription(uid);
    res.json({ success: true, subscription: newStatus });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * Get the current user's subscription status
 * 
 * @route GET /api/user/subscription-status
 * @authentication Requires Firebase ID token in Authorization header
 * @returns {Object} JSON response containing the current subscription status
 */
router.get('/subscription-status', verifyIdToken, async (req, res) => {
  try {
    const uid = req.user.uid;
    const status = await subscriptionService.getUserSubscription(uid);
    res.json({ subscription: status });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router; 