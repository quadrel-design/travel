import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { InvoiceImageStatus, allowedTransitions } from "./invoice_image_status";

const db = getFirestore();

export async function setInvoiceImageStatus(
  userId: string,
  projectId: string,
  invoiceId: string,
  imageId: string,
  newStatus: InvoiceImageStatus
) {
  if (!invoiceId) throw new Error("invoiceId is required");
  const docRef = db
    .collection("users")
    .doc(userId)
    .collection("projects")
    .doc(projectId)
    .collection("invoices")
    .doc(invoiceId)
    .collection("invoice_images")
    .doc(imageId);

  // Fetch current status for validation
  const doc = await docRef.get();
  const currentStatus = doc.exists ? doc.data()?.status : undefined;

  if (
    currentStatus &&
    !allowedTransitions[currentStatus as InvoiceImageStatus]?.includes(newStatus)
  ) {
    throw new Error(
      `Invalid status transition: ${currentStatus} -> ${newStatus}`
    );
  }

  await docRef.update({
    status: newStatus,
    updatedAt: FieldValue.serverTimestamp(),
    // Optionally, append to a statusHistory array:
    // statusHistory: FieldValue.arrayUnion({ status: newStatus, at: FieldValue.serverTimestamp() })
  });
} 