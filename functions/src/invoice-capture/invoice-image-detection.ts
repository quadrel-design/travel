/**
 * Handles text detection (OCR) using the Google Cloud Vision API.
 * Provides a helper function `detectTextInImage` and a callable Cloud Function `ocrInvoice`
 * to process images, update user costs, and store results in Firestore.
 */
// Load environment variables from .env file (useful for local development)
import * as dotenv from "dotenv";
dotenv.config();

import * as functions from "firebase-functions/v1";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { ImageAnnotatorClient } from "@google-cloud/vision";
import { app } from "../init";
import axios from "axios";
import { setInvoiceImageStatus } from "./invoice_image_status_handler";

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
 *  - extractedText: string (full text)
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
        extractedText: "",
        confidence: 0,
        status: "no invoice"
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
      extractedText: fullText,
      confidence,
      textBlocks,
      status: "invoice"
    };

  } catch (error) {
    console.error("Error detecting text in image:", error);
    return {
      success: false,
      hasText: false,
      extractedText: "",
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
export const ocrInvoice = functions.region('us-central1').https.onCall(async (data: any, context: any) => {
  console.log("====== DETECT IMAGE CALLED ======");
  console.log("ocrInvoice function called with data:", {
    hasImageUrl: !!data.imageUrl,
    hasImageData: !!data.imageData,
    invoiceId: data.invoiceId,
    imageId: data.imageId
  });

  const userId = context.auth?.uid;
  if (!userId) {
    console.error("Authentication error: User not authenticated");
    throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
  }
  console.log("User authenticated:", userId);

  // Validate the request data
  if (!data.imageUrl && !data.imageData) {
    console.error("Invalid request: Neither image URL nor image data provided");
    throw new functions.https.HttpsError("invalid-argument", "Must provide either an image URL or image data");
  }

  if (!data.invoiceId || !data.imageId) {
    console.error("Invalid request: Missing invoiceId or imageId");
    throw new functions.https.HttpsError("invalid-argument", "invoiceId and imageId are required");
  }

  const projectId = data.projectId;
  if (!projectId) {
    throw new functions.https.HttpsError("invalid-argument", "projectId is required");
  }

  const invoiceId = data.invoiceId;
  const imageId = data.imageId;
  console.log(`Processing image (ID: ${imageId}) for invoice (ID: ${invoiceId})`);
  
  // Log that we're starting image processing
  console.log("Starting image text detection");
  
  try {
    // Set status to ocrInProgress at the start
    await setInvoiceImageStatus(userId, projectId, imageId, "ocrInProgress");
    let detectResult;
    
    if (data.imageData) {
      // Processing base64 image data
      console.log("Processing base64 image data");
      
      // ... existing code ...
    } else {
      // Process image URL
      try {
        // Added retry logic for URL-based processing
        let retryCount = 0;
        const maxRetries = 2;
        let lastError = null;
        
        while (retryCount <= maxRetries) {
          try {
            console.log(`Attempt ${retryCount + 1} to process image URL: ${data.imageUrl}`);
            
            // For URL-based processing, try to download image to buffer first
            console.log("Downloading image from URL for processing");
            const response = await axios.get(data.imageUrl, {
              responseType: "arraybuffer",
              timeout: 15000 // 15 second timeout for download
            });
            
            // Rename inner 'data' to 'imageData' to avoid shadowing
            const imageData = response.data as Buffer | string;
            const dataLength = typeof imageData === "string" ? Buffer.byteLength(imageData) : (Buffer.isBuffer(imageData) ? imageData.length : 0);
            console.log("Downloaded image size:", dataLength, "bytes");
            
            // Process the downloaded image buffer
            const imageBuffer = Buffer.isBuffer(imageData) ? imageData : Buffer.from(imageData);
            detectResult = await detectTextInImage(data.imageUrl, imageBuffer);
            console.log("Text detection completed with result:", {
              success: detectResult.success,
              hasText: detectResult.hasText,
              status: detectResult.status,
              textLength: detectResult.extractedText?.length || 0
            });
            break; // Success, exit retry loop
          } catch (err) {
            lastError = err;
            console.error(`Attempt ${retryCount + 1} failed:`, err);
            
            // If this was the last retry, don't wait
            if (retryCount === maxRetries) break;
            
            // Wait before retrying (exponential backoff)
            const waitTime = Math.pow(2, retryCount) * 1000;
            console.log(`Waiting ${waitTime}ms before retry...`);
            await new Promise(resolve => setTimeout(resolve, waitTime));
            retryCount++;
          }
        }
        
        // If we exited the loop with an error and no result, throw
        if (!detectResult && lastError) {
          throw lastError;
        }
      } catch (urlError) {
        console.error("Error processing image URL:", urlError);
        throw new functions.https.HttpsError("internal", "Error processing image URL: " + (urlError instanceof Error ? urlError.message : "Unknown error"));
      }
    }
    
    // Update Firestore with the OCR results
    if (detectResult.success) {
      // OCR finished successfully
      if (detectResult.extractedText && detectResult.extractedText.trim().length > 0) {
        await setInvoiceImageStatus(userId, projectId, imageId, "ocrFinished");
      } else {
        await setInvoiceImageStatus(userId, projectId, imageId, "ocrNoText");
      }
      // ---- Start: Update User Costs ----
      console.log("Updating user costs");
      await _updateUserCosts(userId);
      console.log("User costs updated successfully");
      // ---- End: Update User Costs ----

      // ---- Start: Update Invoice Image ----
      try {
        console.log("Preparing to update Firestore document");
        const docRef = db.collection("users")
          .doc(userId)
          .collection("projects")
          .doc(projectId)
          .collection("invoices")
          .doc("main")
          .collection("invoice_images")
          .doc(imageId);

        const updateData: { [key: string]: any } = {
          confidence: detectResult.confidence || 0,
          textBlocks: detectResult.textBlocks || [],
          lastProcessedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          extractedText: detectResult.extractedText ?? "",
          ocrText: detectResult.extractedText ?? ""
        };

        if (detectResult.error) {
          updateData.errorMessage = detectResult.error;
        }

        await docRef.update(updateData);
        console.log("Updated invoice image document with OCR results. Status:", updateData.status);
      } catch (dbError) {
        console.error("Error updating Firestore invoice image:", dbError);
      }
      // ---- End: Update Invoice Image ----
    } else {
      // OCR failed (technical error)
      await setInvoiceImageStatus(userId, projectId, imageId, "ocrError");
      // Handle failed OCR
      console.log("OCR process failed, updating status to error");
      const docRef = db.collection("users")
        .doc(userId)
        .collection("projects")
        .doc(projectId)
        .collection("invoices")
        .doc("main")
        .collection("invoice_images")
        .doc(imageId);
      await docRef.update({
        extractedText: "",
        ocrText: "",
        lastProcessedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        errorMessage: detectResult.error || "OCR process failed"
      });
    }
    
    // Log processing result
    console.log("Image text detection completed:", {
      success: detectResult.success,
      status: detectResult.status
    });
    console.log("====== DETECT IMAGE COMPLETED SUCCESSFULLY ======");
    
    return detectResult;
  } catch (error) {
    // Handle errors from detectTextInImage or other processing
    console.error("Error during image processing stage:", error);
    
    // Ensure HttpsErrors are thrown correctly
    if (error instanceof functions.https.HttpsError) {
        throw error;
    }
    throw new functions.https.HttpsError("internal", "Error processing image: " + (error instanceof Error ? error.message : "Unknown error"));
  }
});

// Helper function to update user costs
async function _updateUserCosts(userId: string) {
  let priceToUse = VISION_API_PRICE_PER_UNIT_FALLBACK; // Start with fallback
  try {
    // Step 1: Get current price from Firestore
    try {
      // First try to get price from the new structure
      const visionPriceSnap = await db.collection("cloud-pricing").doc("Google Vision").get();
      if (visionPriceSnap.exists) {
        const visionData = visionPriceSnap.data();
        if (visionData?.pricePerUse) {
          priceToUse = visionData.pricePerUse;
          console.log(`Using Vision price from new cloud-pricing structure: ${priceToUse}`);
        } else {
          // Fallback to legacy pricing structure
          const pricesSnap = await db.collection("billing").doc("apiPrices").get(); 
          if (pricesSnap.exists && pricesSnap.data()?.google_vision_api_per_unit) {
            priceToUse = pricesSnap.data()?.google_vision_api_per_unit;
            console.log(`Using Vision price from legacy billing structure: ${priceToUse}`);
          } else {
            console.warn("API price not found in either location, using fallback price.");
          }
        }
      } else {
        // Fallback to legacy pricing structure
        const pricesSnap = await db.collection("billing").doc("apiPrices").get(); 
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
    const userDocRef = db.collection("users").doc(userId);
    await userDocRef.set({
      costs: {
        estimated_costs: FieldValue.increment(priceToUse)
      }
    }, { merge: true }); 
    console.log(`Incremented costs.estimated_costs for user ${userId} by ${priceToUse}`);

    // Step 3: Also update the costOverall in the Google Vision document
    try {
      const visionRef = db.collection("cloud-pricing").doc("Google Vision");
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
}

// TEST FUNCTION: Run OCR on a hardcoded image for local testing
if (require.main === module) {
  (async () => {
    const userId = "YOUR_USER_ID"; // Replace with a real user ID
    const invoiceId = "YOUR_INVOICE_ID"; // Replace with a real invoice ID
    const imageId = "YOUR_IMAGE_ID"; // Replace with a real image ID
    const imageUrl = "YOUR_IMAGE_URL"; // Replace with a real image URL

    // Simulate a request object
    const request = {
      auth: { uid: userId },
      data: {
        imageUrl,
        invoiceId,
        imageId,
      },
    };
    try {
      const result = await (ocrInvoice as any)._callableHandler(request, {});
      console.log("Test OCR result:", result);
    } catch (e) {
      console.error("Test OCR error:", e);
    }
    process.exit(0);
  })();
} 