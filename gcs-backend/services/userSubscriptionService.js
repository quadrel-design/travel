/**
 * Subscription Service
 * 
 * Handles Firebase Auth custom claims management for user subscription status.
 * Provides methods to get, set, and toggle subscription status.
 */

const admin = require('firebase-admin');

/**
 * Create a service for managing user subscriptions via Firebase Auth custom claims
 * @returns {Object} Service object with methods for subscription management
 */
module.exports = function() {
  return {
    /**
     * Get the current subscription status for a user
     * @param {string} uid - Firebase user ID
     * @returns {Promise<string>} - 'pro' or 'free' subscription status
     */
    getUserSubscription: async (uid) => {
      const userRecord = await admin.auth().getUser(uid);
      const currentClaims = userRecord.customClaims || {};
      return currentClaims.subscription === 'pro' ? 'pro' : 'free';
    },
    
    /**
     * Set the subscription status for a user
     * @param {string} uid - Firebase user ID 
     * @param {string} status - 'pro' or 'free'
     * @returns {Promise<void>}
     */
    setUserSubscription: async (uid, status) => {
      const validStatus = status === 'pro' ? 'pro' : 'free';
      const userRecord = await admin.auth().getUser(uid);
      const currentClaims = userRecord.customClaims || {};
      
      await admin.auth().setCustomUserClaims(uid, {
        ...currentClaims,
        subscription: validStatus,
      });
    },
    
    /**
     * Toggle the subscription status between 'pro' and 'free'
     * @param {string} uid - Firebase user ID
     * @returns {Promise<string>} - The new subscription status
     */
    toggleUserSubscription: async (uid) => {
      const userRecord = await admin.auth().getUser(uid);
      const currentClaims = userRecord.customClaims || {};
      const currentStatus = currentClaims.subscription === 'pro' ? 'pro' : 'free';
      const newStatus = currentStatus === 'pro' ? 'free' : 'pro';
      
      await admin.auth().setCustomUserClaims(uid, {
        ...currentClaims,
        subscription: newStatus,
      });
      
      return newStatus;
    }
  };
}; 