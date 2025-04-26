/**
 * Invoice Capture Function
 * 
 * Cloud function for capturing invoice details from images
 */
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { app } from './init';
import { detectTextInImage } from './image-detection';
import { analyzeDetectedText } from './text-analysis';

// Initialize Firestore
const db = getFirestore(app);

// Function for invoice capture
export const scanImage = onCall({
  enforceAppCheck: false,
  timeoutSeconds: 300,
  memory: "2GiB",
  maxInstances: 10
}, async (request) => {
  console.log("scanImage function called with data:", {
    hasImageUrl: !!request.data.imageUrl,
    hasImageData: !!request.data.imageData,
    skipAnalysis: !!request.data.skipAnalysis,
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

  // Log that we're starting image processing
  console.log("Starting image processing for invoice capture");
  
  try {
    // Step 1: Detect text in the image
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
    
    // If no text was found or skipAnalysis is true, return early
    if (!detectResult.hasText || request.data.skipAnalysis) {
      return detectResult;
    }
    
    // Step 2: Analyze the detected text
    const analysisResult = await analyzeDetectedText(detectResult.detectedText);
    
    // Combine the results
    const combinedResult = {
      ...detectResult,
      status: analysisResult.status,
      invoiceAnalysis: analysisResult.invoiceAnalysis,
      isInvoice: analysisResult.isInvoice
    };
    
    // Update Firestore if journeyId and imageId are provided
    if (request.data.journeyId && request.data.imageId) {
      try {
        const docRef = db.collection('journeys')
          .doc(request.data.journeyId)
          .collection('images')
          .doc(request.data.imageId);
        
        const updateData: any = {
          hasText: detectResult.hasText,
          detectedText: detectResult.detectedText || "",
          confidence: detectResult.confidence || 0,
          textBlocks: detectResult.textBlocks || [],
          status: combinedResult.status,
          isInvoice: combinedResult.isInvoice,
          lastProcessedAt: new Date().toISOString()
        };
        
        // Add invoice analysis data if available
        if (analysisResult.invoiceAnalysis) {
          updateData.totalAmount = analysisResult.invoiceAnalysis.totalAmount;
          updateData.currency = analysisResult.invoiceAnalysis.currency;
          updateData.merchantName = analysisResult.invoiceAnalysis.merchantName;
          updateData.merchantLocation = analysisResult.invoiceAnalysis.location;
          updateData.invoiceDate = analysisResult.invoiceAnalysis.date;
          updateData.invoiceAnalysis = analysisResult.invoiceAnalysis;
        }
        
        await docRef.update(updateData);
        
        console.log(`Updated journey image document with combined results. Status: ${combinedResult.status}`);
      } catch (dbError) {
        console.error("Error updating Firestore in scanImage function:", dbError);
        // Proceed with returning results even if the database update fails
      }
    }
    
    // Log processing result
    console.log("Invoice capture processing completed successfully:", {
      success: combinedResult.success,
      hasText: combinedResult.hasText,
      status: combinedResult.status,
      isInvoice: combinedResult.isInvoice
    });
    
    return combinedResult;
  } catch (error) {
    console.error("Error in scanImage function:", error);
    throw new HttpsError("internal", "Error processing image: " + (error instanceof Error ? error.message : "Unknown error"));
  }
}); 