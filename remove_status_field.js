// Usage: node remove_status_field.js
// This script removes the 'status' field from all invoice_images documents in Firestore.

const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

async function removeStatusField() {
  const usersSnap = await db.collection('users').get();
  for (const userDoc of usersSnap.docs) {
    const projectsSnap = await userDoc.ref.collection('projects').get();
    for (const projectDoc of projectsSnap.docs) {
      const invoicesSnap = await projectDoc.ref.collection('invoices').get();
      for (const invoiceDoc of invoicesSnap.docs) {
        const imagesSnap = await invoiceDoc.ref.collection('invoice_images').get();
        for (const imageDoc of imagesSnap.docs) {
          if (imageDoc.get('status') !== undefined) {
            await imageDoc.ref.update({ status: admin.firestore.FieldValue.delete() });
            console.log(`Removed status from: users/${userDoc.id}/projects/${projectDoc.id}/invoices/${invoiceDoc.id}/invoice_images/${imageDoc.id}`);
          }
        }
      }
    }
  }
  console.log('Done removing all status fields.');
}

removeStatusField().catch(e => {
  console.error(e);
  process.exit(1);
}); 