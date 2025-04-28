/**
 * Provides the main callable Cloud Function `scanImage` for the invoice capture process.
 * It orchestrates text detection and subsequent text analysis for an input image,
 * updating Firestore with the results.
 */
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { app } from '../init';
import { detectTextInImage } from './image-detection';
import { analyzeDetectedText } from './text-analysis';

// Initialize Firestore
const db = getFirestore(app);

/**
 * Callable Cloud Function that orchestrates the entire invoice scanning process.
 * - Authenticates the user.
 * - Validates input (image URL/data, invoiceId, imageId).
 * - Handles base64 image data conversion.
 * - Calls `detectTextInImage` for OCR.
 * - Calls `analyzeDetectedText` for analysis (unless skipped).
 * - Combines detection and analysis results.
 * - Updates the corresponding invoice image document in Firestore.
 * 
 * @param {CallableRequest} request The request object.
 * @param {object} request.data The data passed to the function:
 * @param {string} [request.data.imageUrl] URL of the image to process.
 * @param {string} [request.data.imageData] Base64 encoded image data.
 * @param {boolean} [request.data.skipAnalysis] Optional flag to skip text analysis.
 * @param {string} request.data.invoiceId The ID of the parent invoice document.
 * @param {string} request.data.imageId The ID of the image document to update.
 * @param {object} request.auth Authentication information for the calling user.
 * @param {string} request.auth.uid The UID of the authenticated user.
 * 
 * @returns {Promise<object>} A promise resolving to the combined result object (detection + analysis).
 * @throws {HttpsError} Throws HttpsError on authentication, validation, or processing errors.
 */
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
    invoiceId: request.data.invoiceId,
    imageId: request.data.imageId
  });

  // Defensive check for required IDs
  if (!request.data.invoiceId || !request.data.imageId) {
    console.error("Missing invoiceId or imageId in request:", request.data);
    throw new HttpsError("invalid-argument", "invoiceId and imageId are required");
  }

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
    
    // Step 2: Analyze the detected text if not skipped
    if (!detectResult.extractedText) {
      // Handle case where detectResult succeeded but text is empty (shouldn't happen if hasText is true, but safeguard)
      console.warn("Extracted text is empty despite hasText being true. Skipping analysis.");
      return {
        ...detectResult,
        status: "Text", // Set status to Text if analysis is skipped due to no text
        invoiceAnalysis: null,
        isInvoice: false
      };
    }
    const analysisResult = await analyzeDetectedText(detectResult.extractedText);
    
    // Combine the results
    const combinedResult = {
      ...detectResult,
      status: analysisResult.status,
      invoiceAnalysis: analysisResult.invoiceAnalysis,
      isInvoice: analysisResult.isInvoice
    };
    
    // Update Firestore if invoiceId and imageId are provided
    if (request.data.invoiceId && request.data.imageId) {
      try {
        const docRef = db.collection('users')
          .doc(request.auth.uid)
          .collection('invoices')
          .doc(request.data.invoiceId)
          .collection('images')
          .doc(request.data.imageId);
        
        // Keep compatibility with both field names
        const updateData: any = {
          hasText: detectResult.hasText,
          extractedText: detectResult.extractedText || "", // Primary field
          confidence: detectResult.confidence || 0,
          textBlocks: detectResult.textBlocks || [],
          status: combinedResult.status,
          isInvoice: combinedResult.isInvoice,
          lastProcessedAt: FieldValue.serverTimestamp()
        };
        
        // Add invoice analysis data if available
        if (analysisResult.invoiceAnalysis) {
          // Include location and merchant name which are still useful
          updateData.merchantName = analysisResult.invoiceAnalysis.merchantName;
          updateData.merchantLocation = analysisResult.invoiceAnalysis.location;
          updateData.invoiceDate = analysisResult.invoiceAnalysis.date;
          updateData.invoiceAnalysis = analysisResult.invoiceAnalysis;
        }
        
        await docRef.update(updateData);
        
        console.log(`Updated invoice image document with combined results. Status: ${combinedResult.status}`);
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