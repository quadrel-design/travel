/**
 * Debug script for directly testing Vision API
 */
import * as dotenv from 'dotenv';
dotenv.config();

import { ImageAnnotatorClient } from "@google-cloud/vision";

// Initialize Vision API client
const vision = new ImageAnnotatorClient();

// URL from the failing request
const TEST_IMAGE_URL = "https://firebasestorage.googleapis.com/v0/b/splitbase-7ec0f.firebasestorage.app/o/users%2FydZrEkal6rTS6o5aZiE7fLlvjOD2%2Finvoices%2FvovckL0RDP9Q8O4EjQzn%2Fimages%2F1745789125860_0ab2f94b-20e7-4b2d-8fd6-22f72b307636?alt=media&token=eyJhbGciOiJSUzI1NiIsImtpZCI6IjkwOTg1NzhjNDg4MWRjMDVlYmYxOWExNWJhMjJkOGZkMWFiMzRjOGEiLCJ0eXAiOiJKV1QifQ.eyJuYW1lIjoiQ2hyaXMgV2lja21hbm4iLCJwaWN0dXJlIjoiaHR0cHM6Ly9saDMuZ29vZ2xldXNlcmNvbnRlbnQuY29tL2EvQUNnOG9jS19kUWpnaU9JQWg2dFpCMUkwdjNQZTJsQ1NUbVgtbkRGMUFSQUFfWDhBc3ROcWhBPXM5Ni1jIiwiaXNzIjoiaHR0cHM6Ly9zZWN1cmV0b2tlbi5nb29nbGUuY29tL3NwbGl0YmFzZS03ZWMwZiIsImF1ZCI6InNwbGl0YmFzZS03ZWMwZiIsImF1dGhfdGltZSI6MTc0NTc4MjU0MCwidXNlcl9pZCI6InlkWnJFa2FsNnJUUzZvNWFaaUU3ZkxsdmpPRDIiLCJzdWIiOiJ5ZFpyRWthbDZyVFM2bzVhWmlFN2ZMbHZqT0QyIiwiaWF0IjoxNzQ1Nzg5MDM1LCJleHAiOjE3NDU3OTI2MzUsImVtYWlsIjoiY2hyaXMud2lja21hbm5AZ21haWwuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsImZpcmViYXNlIjp7ImlkZW50aXRpZXMiOnsiZ29vZ2xlLmNvbSI6WyIxMDAzMjczNzkzNTYxODM5MTI5ODYiXSwiZW1haWwiOlsiY2hyaXMud2lja21hbm5AZ21haWwuY29tIl19LCJzaWduX2luX3Byb3ZpZGVyIjoicGFzc3dvcmQifX0.Jii_ZeT-X9xiSc9N4_tvK2C0GxCTRkquNMw9dUj7u_98RI86b57nCspNf3y4q2Swwmb2eaP1num8LsESLmu8n0DSPfFwA-bRWyVdT2SjTDWvzHzOKZXrPS7PDLkNVxxJrwRKpXIyzreY60uBGJOpXNzoy0VEvb1Tu6x6n-6NlqWyRaCCB5sgWzfrVEIvcXM0NFT_HmBYdNjIB2b-w1rIm0Y_y3zNs7oqcnYzNTY1HLgn0R8jjFa8VAmCkWkJCklVryNyJf3GTcbJ7YAMp77MdaCMcSVF3uE6NAv4SBSQXvePitK4vjIPQlXKffgzGy8hQuK5u-QZQpcua8H09lwc1w&cache-control=no-cache";

// Known working image for comparison
const KNOWN_GOOD_IMAGE = "https://assets-global.website-files.com/5efc0159f9a97ba05a8b7a8a/5f18a955264d7acbd6b51411_invoice-example-en-1.jpg";

/**
 * Main test function
 */
async function debugVisionAPI() {
  console.log("============ VISION API DEBUG ============");
  console.log("API Client initialized");
  console.log("Google Application Credentials:", process.env.GOOGLE_APPLICATION_CREDENTIALS || "Not set");
  
  try {
    // Test 1: Check Vision API with the failing image URL
    console.log("\n----- TEST 1: Testing with the failing image URL -----");
    console.log("URL:", TEST_IMAGE_URL);
    
    try {
      console.log("Calling Vision API...");
      const startTime = Date.now();
      
      const [result] = await vision.textDetection(TEST_IMAGE_URL);
      
      const endTime = Date.now();
      const elapsedTime = (endTime - startTime) / 1000;
      
      console.log(`Process completed in ${elapsedTime.toFixed(2)} seconds`);
      
      const annotations = result.textAnnotations || [];
      if (annotations.length > 0) {
        console.log("SUCCESS: Text found!");
        console.log(`Text detected: ${annotations[0].description?.substring(0, 200)}...`);
        console.log(`Number of text blocks: ${annotations.length}`);
      } else {
        console.log("No text was detected in the image");
      }
    } catch (error) {
      console.error("ERROR calling Vision API with failing URL:", error);
    }
    
    // Test 2: Check Vision API with a known working image
    console.log("\n----- TEST 2: Testing with a known working image -----");
    console.log("URL:", KNOWN_GOOD_IMAGE);
    
    try {
      console.log("Calling Vision API...");
      const startTime = Date.now();
      
      const [result] = await vision.textDetection(KNOWN_GOOD_IMAGE);
      
      const endTime = Date.now();
      const elapsedTime = (endTime - startTime) / 1000;
      
      console.log(`Process completed in ${elapsedTime.toFixed(2)} seconds`);
      
      const annotations = result.textAnnotations || [];
      if (annotations.length > 0) {
        console.log("SUCCESS: Text found!");
        console.log(`Text detected: ${annotations[0].description?.substring(0, 200)}...`);
        console.log(`Number of text blocks: ${annotations.length}`);
      } else {
        console.log("No text was detected in the image");
      }
    } catch (error) {
      console.error("ERROR calling Vision API with known good image:", error);
    }
    
    console.log("\n============ DEBUG COMPLETE ============");
  } catch (error) {
    console.error("Fatal error during debug:", error);
  }
}

// Run the debug
debugVisionAPI().catch(error => {
  console.error("Uncaught exception:", error);
  process.exit(1);
}); 