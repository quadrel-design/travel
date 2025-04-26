// Load environment variables from .env file
import * as dotenv from 'dotenv';
dotenv.config();

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { ImageAnnotatorClient } from "@google-cloud/vision";
import { app } from './init';

// Initialize Firestore
const db = getFirestore(app);

// Initialize Vision API client
const vision = new ImageAnnotatorClient({
  keyFilename: "./splitbase-7ec0f-9618a4571647.json"
});

// Function to detect text in an image
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

// Firebase cloud function for the OCR detection
export const detectImage = onCall({
  enforceAppCheck: false,
  timeoutSeconds: 120,
  memory: "1GiB",
  maxInstances: 20
}, async (request) => {
  console.log("detectImage function called with data:", {
    hasImageUrl: !!request.data.imageUrl,
    hasImageData: !!request.data.imageData,
    journeyId: request.data.journeyId,
    imageId: request.data.imageId
  });

  // Check if the user is authenticated
  if (!request.auth) {
    console.error("Authentication error: User not authenticated");
    throw new HttpsError("unauthenticated", "The function must be called while authenticated.");
  }

  // Validate the request data
  if (!request.data.imageUrl && !request.data.imageData) {
    console.error("Invalid request: Neither image URL nor image data provided");
    throw new HttpsError("invalid-argument", "Must provide either an image URL or image data");
  }

  if (!request.data.journeyId || !request.data.imageId) {
    console.error("Invalid request: Missing journeyId or imageId");
    throw new HttpsError("invalid-argument", "journeyId and imageId are required");
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
      try {
        const docRef = db.collection('journeys')
          .doc(request.data.journeyId)
          .collection('images')
          .doc(request.data.imageId);
        
        // Log the detected text before updating to verify its value
        console.log("Detected text before updating Firestore:", {
          hasText: detectResult.hasText,
          detectedText: detectResult.detectedText,
          detectedTextLength: detectResult.detectedText ? detectResult.detectedText.length : 0
        });
        
        const updateData = {
          hasText: detectResult.hasText,
          detected_text: detectResult.detectedText || "", // Changed field name to match Firestore schema
          confidence: detectResult.confidence || 0,
          textBlocks: detectResult.textBlocks || [],
          status: detectResult.status,
          lastProcessedAt: new Date().toISOString()
        };
        
        // Log the update data being sent to Firestore
        console.log("Updating Firestore with data:", JSON.stringify(updateData));
        
        await docRef.update(updateData);
        
        console.log(`Updated journey image document with OCR results. Status: ${detectResult.status}`);
      } catch (dbError) {
        console.error("Error updating Firestore:", dbError);
        // Proceed with returning results even if the database update fails
      }
    }
    
    // Log processing result
    console.log("Image text detection completed:", {
      success: detectResult.success,
      hasText: detectResult.hasText,
      status: detectResult.status
    });
    
    return detectResult;
  } catch (error) {
    console.error("Error in detectImage function:", error);
    throw new HttpsError("internal", "Error detecting text in image: " + (error instanceof Error ? error.message : "Unknown error"));
  }
}); 