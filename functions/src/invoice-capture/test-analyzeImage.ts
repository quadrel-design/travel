// This script uses the Firebase Client SDK to call the analyzeInvoice callable function as an authenticated user.
// To run: npm install firebase dotenv

import { initializeApp } from "firebase/app";
import { getFunctions, httpsCallable } from "firebase/functions";
import { getAuth, signInWithEmailAndPassword } from "firebase/auth";
import * as dotenv from "dotenv";
import path from "path";

dotenv.config({ path: path.resolve(__dirname, "../../../.env") });

const DEV_EMAIL = process.env.DEV_EMAIL;
const DEV_PASSWORD = process.env.DEV_PASSWORD;

console.log("DEV_EMAIL:", DEV_EMAIL);
console.log("DEV_PASSWORD:", DEV_PASSWORD);

if (!DEV_EMAIL || !DEV_PASSWORD) {
  throw new Error("DEV_EMAIL and DEV_PASSWORD must be set in your environment or .env file");
}

const firebaseConfig = {
  apiKey: "AIzaSyBRERzKYWUU8nzFiABYeNQO7dKoOuxx6vQ",
  authDomain: "splitbase-7ec0f.firebaseapp.com",
  projectId: "splitbase-7ec0f",
  storageBucket: "splitbase-7ec0f.firebasestorage.app",
  messagingSenderId: "213342165039",
  appId: "1:213342165039:web:bd145392404471fd458eda",
  measurementId: "G-BP4EW0YM44"
};

async function main() {
  // Initialize Firebase
  const app = initializeApp(firebaseConfig);
  const auth = getAuth(app);

  // Sign in with email and password from environment
  await signInWithEmailAndPassword(auth, DEV_EMAIL, DEV_PASSWORD);
  console.log("Signed in successfully");

  const functions = getFunctions(app, "us-central1");
  const analyzeInvoice = httpsCallable(functions, "analyzeInvoice");

  try {
    const result = await analyzeInvoice({
      projectId: "sYoHqiwIJEx1du1KsnpM",
      invoiceId: "YOUR_INVOICE_ID", // Replace with a real invoiceId for testing
      imageId: "8aa08e0d-28cd-4f1f-b0fc-865b116af086",
      extractedText:
        "[Company Name] [Street Address] [City, ST ZIP] Phone: (000) 000-0000 BILL TO [Name] [Company Name] [Street Address] [City, ST ZIP] [Phone] [Email Address] INVOICE INVOICE # [123456] DATE 5/1/2014 Thank you for your business! TOTAL $ 551.56 Invoice Template 2014 Vertex42.com If you have any questions about this invoice, please contact [Name, Phone, email@address.com]"
    });
    console.log("Function response:", result.data);
  } catch (error: any) {
    console.error("Function error response:", error);
  }
}

main(); 