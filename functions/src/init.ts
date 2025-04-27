// Firebase initialization file
import { getApp, initializeApp } from "firebase-admin/app";

// Get existing app or initialize Firebase Admin
export let app;
try {
  app = getApp();
  console.log("Using existing Firebase Admin app");
} catch (error) {
  app = initializeApp();
  console.log("Firebase Admin initialized");
} 