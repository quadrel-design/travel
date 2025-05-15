/**
 * Subscription Service
 * 
 * Handles Firebase Auth custom claims management for user subscription status.
 * Provides methods to get, set, and toggle subscription status.
 */

const firebaseAdmin = require('firebase-admin');

// Ensure Firebase Admin SDK is initialized (usually done in main app entry point like index.js)
// This check is a safeguard.
if (firebaseAdmin.apps.length === 0) {
  console.error('[UserSubscriptionService] Firebase Admin SDK has not been initialized. Service may not function.');
  // Depending on strategy, could throw an error here to prevent app startup if Firebase is critical.
}

const userSubscriptionService = {
  /**
   * Get the current subscription status for a user
   * @param {string} uid - Firebase user ID
   * @returns {Promise<string>} - 'pro' or 'free' subscription status
   */
  getUserSubscription: async (uid) => {
    if (firebaseAdmin.apps.length === 0) throw new Error('Firebase Admin SDK not initialized');
    const userRecord = await firebaseAdmin.auth().getUser(uid);
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
    if (firebaseAdmin.apps.length === 0) throw new Error('Firebase Admin SDK not initialized');
    const validStatus = status === 'pro' ? 'pro' : 'free';
    const userRecord = await firebaseAdmin.auth().getUser(uid);
    const currentClaims = userRecord.customClaims || {};
    
    await firebaseAdmin.auth().setCustomUserClaims(uid, {
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
    if (firebaseAdmin.apps.length === 0) throw new Error('Firebase Admin SDK not initialized');
    const userRecord = await firebaseAdmin.auth().getUser(uid);
    const currentClaims = userRecord.customClaims || {};
    const currentStatus = currentClaims.subscription === 'pro' ? 'pro' : 'free';
    const newStatus = currentStatus === 'pro' ? 'free' : 'pro';
    
    await firebaseAdmin.auth().setCustomUserClaims(uid, {
      ...currentClaims,
      subscription: newStatus,
    });
    
    return newStatus;
  }
};

module.exports = userSubscriptionService; 