/**
 * @fileoverview User Subscription Routes.
 * Provides API endpoints for managing user subscription status (e.g., 'pro' vs 'free').
 * These routes interact with Firebase Authentication custom claims via the `userSubscriptionService`
 * to store and retrieve a user's subscription tier.
 * All endpoints require Firebase authentication.
 * @module routes/userSubscription
 * @basepath /api/user
 */

const express = require('express');
const router = express.Router();
// const firebaseAdmin = require('firebase-admin'); // Removed as it's not directly used here; service handles it.
const subscriptionService = require('../services/userSubscriptionService');
const logger = require('../config/logger');
const authenticateUser = require('../middleware/authenticateUser');

/**
 * @summary Toggle user subscription status between 'pro' and 'free'.
 * @description Retrieves the current user subscription status from Firebase Auth custom claims,
 * toggles it (pro -> free, free -> pro), and updates the custom claims.
 * The new subscription status is returned.
 * 
 * @route POST /api/user/toggle-subscription
 * @authentication Requires Firebase ID token in Authorization header (`Bearer <token>`)
 * @returns {object} 200 - JSON response containing success status and the new subscription value.
 *   @example response - 200 - Success
 *   {
 *     "success": true,
 *     "subscription": "pro"
 *   }
 * @returns {Error} 401 - Unauthorized if token is missing, invalid, or expired.
 * @returns {Error} 500 - Internal server error if subscription service is misconfigured or Firebase interaction fails.
 */
router.post('/toggle-subscription', authenticateUser, async (req, res) => {
  try {
    const uid = req.user.id;
    if (!subscriptionService || typeof subscriptionService.toggleUserSubscription !== 'function') {
      logger.error('[Routes/UserSubscription] subscriptionService.toggleUserSubscription is not available!');
      return res.status(500).json({ error: 'Subscription service not configured correctly.' });
    }
    const newStatus = await subscriptionService.toggleUserSubscription(uid);
    res.json({ success: true, subscription: newStatus });
  } catch (error) {
    logger.error('[Routes/UserSubscription] Error toggling subscription:', { message: error.message, stack: error.stack });
    res.status(500).json({ error: error.message || 'Failed to toggle subscription' });
  }
});

/**
 * @summary Get the current user's subscription status.
 * @description Retrieves the user's current subscription status (e.g., 'free' or 'pro')
 * from their Firebase Auth custom claims.
 * 
 * @route GET /api/user/subscription-status
 * @authentication Requires Firebase ID token in Authorization header (`Bearer <token>`)
 * @returns {object} 200 - JSON response containing the current subscription status.
 *   @example response - 200 - Success
 *   {
 *     "subscription": "free"
 *   }
 * @returns {Error} 401 - Unauthorized if token is missing, invalid, or expired.
 * @returns {Error} 500 - Internal server error if subscription service is misconfigured or Firebase interaction fails.
 */
router.get('/subscription-status', authenticateUser, async (req, res) => {
  try {
    const uid = req.user.id;
    if (!subscriptionService || typeof subscriptionService.getUserSubscription !== 'function') {
      logger.error('[Routes/UserSubscription] subscriptionService.getUserSubscription is not available!');
      return res.status(500).json({ error: 'Subscription service not configured correctly.' });
    }
    const status = await subscriptionService.getUserSubscription(uid);
    res.json({ success: true, subscription: status });
  } catch (error) {
    logger.error('[Routes/UserSubscription] Error getting subscription status:', { message: error.message, stack: error.stack });
    res.status(500).json({ error: error.message || 'Failed to get subscription status' });
  }
});

logger.info('[Routes/UserSubscription] Routes defined, exporting router.');
module.exports = router; 