const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

async function migrateUser(userId) {
  const oldInvoicesRef = db.collection('users').doc(userId).collection('invoices');
  const oldInvoicesSnap = await oldInvoicesRef.get();

  for (const invoiceDoc of oldInvoicesSnap.docs) {
    const projectId = invoiceDoc.id;
    const projectData = invoiceDoc.data();

    // 1. Create new project doc
    const newProjectRef = db.collection('users').doc(userId).collection('projects').doc(projectId);
    await newProjectRef.set(projectData);

    // 2. Migrate subcollections (images, expenses, etc.)
    // 2a. Images → invoices/{invoiceId}/invoice_images
    const oldImagesRef = oldInvoicesRef.doc(projectId).collection('images');
    const oldImagesSnap = await oldImagesRef.get();
    if (!oldImagesSnap.empty) {
      // Create a new invoice doc under the project
      const newInvoiceRef = newProjectRef.collection('invoices').doc(projectId);
      await newInvoiceRef.set({}); // You may want to copy invoice-level data if you have it

      for (const imageDoc of oldImagesSnap.docs) {
        await newInvoiceRef.collection('invoice_images').doc(imageDoc.id).set(imageDoc.data());
      }
    }

    // 2b. Expenses → invoices/{invoiceId}/expenses
    const oldExpensesRef = oldInvoicesRef.doc(projectId).collection('expenses');
    const oldExpensesSnap = await oldExpensesRef.get();
    if (!oldExpensesSnap.empty) {
      const newInvoiceRef = newProjectRef.collection('invoices').doc(projectId);
      for (const expenseDoc of oldExpensesSnap.docs) {
        await newInvoiceRef.collection('expenses').doc(expenseDoc.id).set(expenseDoc.data());
      }
    }

    // 2c. (Add more subcollections as needed)
  }
}

async function main() {
  const usersSnap = await db.collection('users').get();
  for (const userDoc of usersSnap.docs) {
    const userId = userDoc.id;
    console.log(`Migrating user: ${userId}`);
    await migrateUser(userId);
  }
  console.log('Migration complete!');
}

main().catch(console.error); 