const admin = require('firebase-admin');

if (!admin.apps || !admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

async function updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, updateData) {
  const docRef = db.collection('users')
    .doc(userId)
    .collection('projects')
    .doc(projectId)
    .collection('invoices')
    .doc(invoiceId)
    .collection('invoice_images')
    .doc(imageId);
  await docRef.update(updateData);
}

async function setInvoiceImageStatus(userId, projectId, invoiceId, imageId, status) {
  await updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, { status });
}

module.exports = {
  updateInvoiceImageFirestore,
  setInvoiceImageStatus,
}; 