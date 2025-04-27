/**
 * Handles text detection (OCR) using the Google Cloud Vision API.
 * Provides a helper function `detectTextInImage` and a callable Cloud Function `detectImage`
 * to process images, update user costs, and store results in Firestore.
 */
// Load environment variables from .env file (useful for local development)
import * as dotenv from 'dotenv';
dotenv.config();

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { ImageAnnotatorClient } from "@google-cloud/vision";
import { app } from '../init';

// Initialize Firestore
const db = getFirestore(app);

// Initialize Vision API client.
// It will automatically use application default credentials (ADC) in Cloud Functions.
// For local development, ensure GOOGLE_APPLICATION_CREDENTIALS env var is set.
const vision = new ImageAnnotatorClient();

// Define the fallback Vision API price per unit (EUR)
// Used if fetching the price from Firestore fails.
const VISION_API_PRICE_PER_UNIT_FALLBACK = 0.00025;

// Commented out unused variable
// const DEFAULT_VISION_PRICE_PER_1000_UNITS_FALLBACK = 1.50;
// Commented out unused variable
// const VISION_PRICE_PER_UNIT_FALLBACK = DEFAULT_VISION_PRICE_PER_1000_UNITS_FALLBACK / 1000;

// Commented out unused variable
// const OCR_COST_IN_CREDITS = 1;

/**
 * Performs OCR on an image using Google Cloud Vision API.
 * Extracts the full detected text, confidence, and individual text blocks with bounding boxes.
 * 
 * @param {string} imageUrl The URL of the image to process (used if imageBuffer is not provided).
 * @param {Buffer} [imageBuffer] Optional buffer containing the image data.
 * @returns {Promise<object>} A promise resolving to an object containing detection results:
 *  - success: boolean
 *  - hasText: boolean
 *  - detectedText: string (full text)
 *  - confidence: number (confidence of full text)
 *  - textBlocks: Array<object> (individual blocks with text, confidence, boundingBox)
 *  - status: string ("NoText", "PendingAnalysis", "Error")
 *  - error?: string (if an error occurred)
 */
export async function detectTextInImage(imageUrl: string, imageBuffer?: Buffer) {
  try {
    // Step 1: Perform OCR on the image
    const [result] = await vision.textDetection(imageBuffer || imageUrl);
    const detections = result.textAnnotations || [];

    if (!detections.length) {
      return {
        success: true,
        hasText: false,
        detectedText: "",
        confidence: 0,
        status: "NoText"
      };
    }

    // Get the full text and confidence score
    const fullText = detections[0].description || "";
    const confidence = detections[0].confidence || 0;

    // Get individual text blocks with their bounding boxes
    const textBlocks = detections.slice(1).map((block) => ({
      text: block.description || "",
      confidence: block.confidence || 0,
      boundingBox: block.boundingPoly?.vertices
        ? {
            left: Math.min(...block.boundingPoly.vertices.map((v) => v.x || 0)),
            top: Math.min(...block.boundingPoly.vertices.map((v) => v.y || 0)),
            right: Math.max(...block.boundingPoly.vertices.map((v) => v.x || 0)),
            bottom: Math.max(...block.boundingPoly.vertices.map((v) => v.y || 0)),
          }
        : undefined,
    }));

    return {
      success: true,
      hasText: true,
      detectedText: fullText,
      confidence,
      textBlocks,
      status: "PendingAnalysis"  // Set status as pending for analysis
    };

  } catch (error) {
    console.error("Error detecting text in image:", error);
    return {
      success: false,
      hasText: false,
      detectedText: "",
      confidence: 0,
      status: "Error",
      error: error instanceof Error ? error.message : "Unknown error occurred",
    };
  }
}

/**
 * Callable Cloud Function to orchestrate image text detection.
 * - Authenticates the user.
 * - Validates input data (image URL or base64 data, invoiceId, imageId).
 * - Calls `detectTextInImage` to perform OCR.
 * - If successful, updates estimated user costs in Firestore based on fetched or fallback pricing.
 * - Updates the corresponding invoice image document in Firestore with OCR results.
 * 
 * @param {CallableRequest} request The request object.
 * @param {object} request.data The data passed to the function:
 * @param {string} [request.data.imageUrl] URL of the image to process.
 * @param {string} [request.data.imageData] Base64 encoded image data.
 * @param {string} request.data.invoiceId The ID of the parent invoice document.
 * @param {string} request.data.imageId The ID of the image document to update.
 * @param {object} request.auth Authentication information for the calling user.
 * @param {string} request.auth.uid The UID of the authenticated user.
 * 
 * @returns {Promise<object>} A promise resolving to the result object from `detectTextInImage`.
 * @throws {HttpsError} Throws HttpsError on authentication, validation, or processing errors.
 */
export const detectImage = onCall({
  enforceAppCheck: false, // Consider enabling App Check for production
  timeoutSeconds: 120,
  memory: "1GiB",
  maxInstances: 20
}, async (request) => {
  console.log("detectImage function called with data:", {
    hasImageUrl: !!request.data.imageUrl,
    hasImageData: !!request.data.imageData,
    invoiceId: request.data.invoiceId,
    imageId: request.data.imageId
  });

  const userId = request.auth?.uid;
  if (!userId) {
    console.error("Authentication error: User not authenticated");
    throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
  }

  // Validate the request data
  if (!request.data.imageUrl && !request.data.imageData) {
    console.error("Invalid request: Neither image URL nor image data provided");
    throw new HttpsError("invalid-argument", "Must provide either an image URL or image data");
  }

  if (!request.data.invoiceId || !request.data.imageId) {
    console.error("Invalid request: Missing invoiceId or imageId");
    throw new HttpsError("invalid-argument", "invoiceId and imageId are required");
  }

  // Log that we're starting image processing
  console.log("Starting image text detection");
  
  try {
    let detectResult;
    if (request.data.imageData) {
      // Validate base64 image data
      try {
        // Check if it's a valid base64 string
        if (typeof request.data.imageData !== 'string') {
          throw new Error('Image data must be a string');
        }
        
        // Convert base64 image data to buffer
        const imageBuffer = Buffer.from(request.data.imageData, 'base64');
        
        // Check if the conversion worked (empty buffer means invalid base64)
        if (imageBuffer.length === 0) {
          throw new Error('Invalid base64 image data');
        }
        
        // Use a placeholder URL since we're using the buffer
        detectResult = await detectTextInImage("placeholder-url", imageBuffer);
      } catch (e) {
        console.error("Error processing base64 image data:", e);
        throw new HttpsError("invalid-argument", "Invalid image data: " + (e instanceof Error ? e.message : "Unknown error"));
      }
    } else {
      // Use the image URL
      detectResult = await detectTextInImage(request.data.imageUrl);
    }
    
    // Update Firestore with the OCR results
    if (detectResult.success) {
      const invoiceId = request.data.invoiceId;
      const imageId = request.data.imageId;

      // ---- Start: Update User Costs ----
      let priceToUse = VISION_API_PRICE_PER_UNIT_FALLBACK; // Start with fallback
      try {
        // Step 1: Get current price from Firestore
        try {
          // First try to get price from the new structure
          const visionPriceSnap = await db.collection('cloud-pricing').doc('Google Vision').get();
          if (visionPriceSnap.exists) {
            const visionData = visionPriceSnap.data();
            if (visionData?.pricePerUse) {
              priceToUse = visionData.pricePerUse;
              console.log(`Using Vision price from new cloud-pricing structure: ${priceToUse}`);
            } else {
              // Fallback to legacy pricing structure
          const pricesSnap = await db.collection('billing').doc('apiPrices').get(); 
          if (pricesSnap.exists && pricesSnap.data()?.google_vision_api_per_unit) {
            priceToUse = pricesSnap.data()?.google_vision_api_per_unit;
                console.log(`Using Vision price from legacy billing structure: ${priceToUse}`);
              } else {
                console.warn("API price not found in either location, using fallback price.");
              }
            }
          } else {
            // Fallback to legacy pricing structure
            const pricesSnap = await db.collection('billing').doc('apiPrices').get(); 
            if (pricesSnap.exists && pricesSnap.data()?.google_vision_api_per_unit) {
              priceToUse = pricesSnap.data()?.google_vision_api_per_unit;
              console.log(`Using Vision price from legacy billing structure: ${priceToUse}`);
            } else {
              console.warn("API price document not found in either location, using fallback price.");
            }
          }
        } catch (priceError) {
          console.error("Error fetching price from Firestore, using fallback:", priceError);
        }

        // Step 2: Increment estimated costs in the user document (under costs map)
        const userDocRef = db.collection('users').doc(userId);
        // Using set with merge: true initializes the `costs` map if it doesn't exist,
        // but will overwrite any other fields within `costs` if they exist.
        // If only incrementing is desired and `costs` might have other fields,
        // consider using `update({'costs.estimated_costs': FieldValue.increment(...)})`
        // but ensure the `costs` map is initialized elsewhere.
        await userDocRef.set({
          costs: {
            estimated_costs: FieldValue.increment(priceToUse)
          }
        }, { merge: true }); 
        console.log(`Incremented costs.estimated_costs for user ${userId} by ${priceToUse}`);

        // Step 3: Also update the costOverall in the Google Vision document
        try {
          const visionRef = db.collection('cloud-pricing').doc('Google Vision');
          await visionRef.update({
            costOverall: FieldValue.increment(priceToUse)
          });
          console.log(`Updated costOverall for Google Vision by ${priceToUse}`);
        } catch (costUpdateError) {
          console.error("Error updating costOverall for Google Vision:", costUpdateError);
          // Continue with processing even if this update fails
        }

      } catch (billingError) {
        console.error(`Failed during user cost update for user ${userId}:`, billingError);
        // Log error but continue with invoice image update
      }
      // ---- End: Update User Costs ----

      // ---- Start: Update Invoice Image ----
      try {
        const docRef = db.collection('users')
          .doc(userId)
          .collection('invoices')
          .doc(invoiceId)
          .collection('images')
          .doc(imageId);
        
        const updateData = {
          confidence: detectResult.confidence || 0,
          textBlocks: detectResult.textBlocks || [],
          status: detectResult.status,
          lastProcessedAt: FieldValue.serverTimestamp()
        };
        
        console.log("Updating Firestore invoice image with data:", JSON.stringify(updateData));
        await docRef.update(updateData);
        console.log(`Updated invoice image document with OCR results. Status: ${detectResult.status}`);
      } catch (dbError) {
        console.error("Error updating Firestore invoice image:", dbError);
      }
      // ---- End: Update Invoice Image ----
    }
    
    // Log processing result
    console.log("Image text detection completed:", {
      success: detectResult.success,
      status: detectResult.status
    });
    
    return detectResult;
  } catch (error) {
    // Handle errors from detectTextInImage or other processing
    console.error("Error during image processing stage:", error);
    // Ensure HttpsErrors are thrown correctly
    if (error instanceof HttpsError) {
        throw error;
    }
    throw new HttpsError("internal", "Error processing image: " + (error instanceof Error ? error.message : "Unknown error"));
  }
}); 