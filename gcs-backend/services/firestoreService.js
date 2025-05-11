/**
 * Firestore Service.
 * Provides functions to update invoice image documents in Firestore.
 */

// const { Firestore } = require('@google-cloud/firestore'); // REMOVE THIS - We will use the passed db instance

console.log('firestoreService: Loading. GOOGLE_CLOUD_PROJECT (initial load):', process.env.GOOGLE_CLOUD_PROJECT);
console.log('firestoreService: Loading. GOOGLE_APPLICATION_CREDENTIALS (initial load):', process.env.GOOGLE_APPLICATION_CREDENTIALS);

module.exports = function(db) { // Changed back to accept 'db'
  // REMOVE LOG: console.log(`firestoreService (DIAGNOSTIC): Function called. GOOGLE_CLOUD_PROJECT (at request time): '${process.env.GOOGLE_CLOUD_PROJECT}'`);

  // const projectId = process.env.GOOGLE_CLOUD_PROJECT; // REMOVE THIS

  if (!db) { // Check the passed 'db' instance
    const errorMessage = "firestoreService: CRITICAL ERROR - Firestore db instance was NOT PROVIDED!"; // Updated error message
    console.error(errorMessage);
    throw new Error(errorMessage);
  }

  // REMOVE: const db = new Firestore({ projectId: projectId });
  // REMOVE LOG: console.log(`firestoreService: DIAGNOSTIC - Initialized NEW standalone Firestore client with projectId: ${projectId}`);
  console.log('firestoreService: Using provided db instance.'); // Add log to confirm

  return {
    updateInvoiceImageFirestore: async function(userId, projectId, invoiceId, imageId, updateData) {
      // REMOVE (DIAGNOSTIC) from log: console.log(`firestoreService (DIAGNOSTIC): Updating image ${imageId} for user ${userId}, project ${projectId} with data using NEWLY CREATED db instance:`, updateData);
      console.log(`firestoreService: Updating image ${imageId} for user ${userId}, project ${projectId} with data:`, updateData);
      const docRef = db.collection('users') // Uses the passed 'db'
        .doc(userId)
        .collection('projects')
        .doc(projectId)
        .collection('invoices')
        .doc(invoiceId)
        .collection('invoice_images')
        .doc(imageId);
      try {
        await docRef.update(updateData);
        // REMOVE (DIAGNOSTIC w/ new db) from log: console.log(` Firestore update successful for imageId: ${imageId} (DIAGNOSTIC w/ new db)`);
        console.log(` Firestore update successful for imageId: ${imageId}`);
      } catch (error) {
        // REMOVE (DIAGNOSTIC w/ new db) from log: console.error(` Firestore update FAILED for imageId: ${imageId} (DIAGNOSTIC w/ new db)`, error);
        console.error(` Firestore update FAILED for imageId: ${imageId}`, error);
        throw error; 
      }
    },

    setInvoiceImageStatus: async function(userId, projectId, invoiceId, imageId, status) {
      // REMOVE (DIAGNOSTIC) from log: console.log(`firestoreService (DIAGNOSTIC): Setting status for image ${imageId} to '${status}' for user ${userId}, project ${projectId} using NEWLY CREATED db instance`);
      console.log(`firestoreService: Setting status for image ${imageId} to '${status}' for user ${userId}, project ${projectId}`);
      await this.updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, { status }); 
      // REMOVE (DIAGNOSTIC w/ new db) from log: console.log(` Firestore status set for imageId: ${imageId} to ${status} (DIAGNOSTIC w/ new db)`);
      console.log(` Firestore status set for imageId: ${imageId} to ${status}`);
    }
  };
};