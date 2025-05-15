/**
 * @fileoverview User Subscription Service Module.
 * This module handles the management of user subscription status (e.g., 'pro' vs 'free')
 * by interacting with Firebase Authentication custom claims.
 * It provides functions to get, set, and toggle a user's subscription tier.
 * It assumes the Firebase Admin SDK has been initialized elsewhere in the application (e.g., in `index.js`).
 * @module services/userSubscriptionService
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
   * @async
   * @function getUserSubscription
   * @summary Get the current subscription status for a user.
   * @description Retrieves the user's record from Firebase Authentication, checks their custom claims
   * for a `subscription` field, and returns 'pro' or 'free' accordingly.
   * Defaults to 'free' if the claim is not set or has an unexpected value.
   * 
   * @param {string} uid - Firebase user ID (UID).
   * @returns {Promise<string>} A promise that resolves to the user's subscription status ('pro' or 'free').
   * @throws {Error} If the Firebase Admin SDK is not initialized or if `getUser` fails.
   */
  getUserSubscription: async (uid) => {
    if (firebaseAdmin.apps.length === 0) throw new Error('Firebase Admin SDK not initialized');
    const userRecord = await firebaseAdmin.auth().getUser(uid);
    const currentClaims = userRecord.customClaims || {};
    return currentClaims.subscription === 'pro' ? 'pro' : 'free';
  },
  
  /**
   * @async
   * @function setUserSubscription
   * @summary Set the subscription status for a user.
   * @description Sets a custom claim `subscription` on the Firebase user record to the specified status.
   * Input status is normalized to either 'pro' or 'free'.
   * 
   * @param {string} uid - Firebase user ID (UID).
   * @param {string} status - The desired subscription status ('pro' or 'free'). Any other value defaults to 'free'.
   * @returns {Promise<void>} A promise that resolves when the custom claims have been updated.
   * @throws {Error} If the Firebase Admin SDK is not initialized or if `setCustomUserClaims` fails.
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
   * @async
   * @function toggleUserSubscription
   * @summary Toggle the subscription status between 'pro' and 'free' for a user.
   * @description Fetches the current subscription status from custom claims, then sets it to the opposite value
   * ('pro' becomes 'free', and 'free' becomes 'pro').
   * 
   * @param {string} uid - Firebase user ID (UID).
   * @returns {Promise<string>} A promise that resolves to the new subscription status after toggling.
   * @throws {Error} If the Firebase Admin SDK is not initialized or if Firebase operations fail.
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