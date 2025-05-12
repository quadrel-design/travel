import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

Future<void> main() async {
  final logger = Logger();
  await Firebase.initializeApp();
  await migrateInvoicesToBudgets(logger);
}

Future<void> migrateInvoicesToBudgets(Logger logger) async {
  final firestore = FirebaseFirestore.instance;

  final users = await firestore.collection('users').get();
  for (final userDoc in users.docs) {
    final userId = userDoc.id;
    final projects = await firestore
        .collection('users')
        .doc(userId)
        .collection('projects')
        .get();
    for (final projectDoc in projects.docs) {
      final projectId = projectDoc.id;
      final oldInvoices = await firestore
          .collection('users')
          .doc(userId)
          .collection('projects')
          .doc(projectId)
          .collection('invoices')
          .get();

      for (final invoiceDoc in oldInvoices.docs) {
        final data = invoiceDoc.data();
        final budgetId = data['budgetId'];
        if (budgetId == null) {
          logger.w(
              'Invoice ${invoiceDoc.id} in project $projectId has no budgetId. Skipping.');
          continue;
        }

        // Write to new location
        final newInvoiceRef = firestore
            .collection('users')
            .doc(userId)
            .collection('projects')
            .doc(projectId)
            .collection('budgets')
            .doc(budgetId)
            .collection('invoices')
            .doc(invoiceDoc.id);

        await newInvoiceRef.set(data);
        logger.i('Migrated invoice ${invoiceDoc.id} to budget $budgetId');

        // Optionally, delete from old location
        await invoiceDoc.reference.delete();
      }
    }
  }
  logger.i('Migration complete!');
}
