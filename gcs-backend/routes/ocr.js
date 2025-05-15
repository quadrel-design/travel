/**
 * OCR Routes.
 * Handles OCR processing for invoice images.
 */

const express = require('express');
const router = express.Router();
const axios = require('axios');
const { detectTextInImage } = require('../services/visionService');
const projectService = require('../services/projectService'); // For DB interactions
const firebaseAdmin = require('firebase-admin'); // For authentication

// Middleware to check if user is authenticated
const authenticateUser = async (req, res, next) => {
  if (firebaseAdmin.apps.length === 0) {
    console.error('[Routes/OCR][AuthMiddleware] Firebase Admin SDK not initialized. Cannot authenticate.');
    return res.status(500).json({ error: 'Authentication service not configured.' });
  }
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized: No token provided' });
    }
    const token = authHeader.split(' ')[1];
    const decodedToken = await firebaseAdmin.auth().verifyIdToken(token);
    req.user = decodedToken; // Attach user to request object (req.user.id, req.user.email)
    next();
  } catch (error) {
    console.error('[Routes/OCR][AuthMiddleware] Error authenticating user:', error);
    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({ error: 'Unauthorized: Token expired', code: 'TOKEN_EXPIRED' });
    }
    return res.status(401).json({ error: 'Unauthorized: Invalid token' });
  }
};

// Apply authentication middleware to all routes in this router
router.use(authenticateUser);

// Check if projectService is available
if (!projectService) {
  const errorMessage = '[Routes/OCR] CRITICAL ERROR - projectService was not imported or is unavailable. OCR routes cannot function with DB.';
    console.error(errorMessage);
    throw new Error(errorMessage);
  }

/**
 * @route POST /ocr-invoice
 * Performs OCR on an image (from URL or direct data), updates database record.
 * @body {string} [imageUrl] - URL of the image to process.
 * @body {string} [imageData] - Base64 encoded image data (not yet fully supported in this version).
 * @body {string} projectId - Project ID for context and DB record.
 * @body {string} imageId - The ID of the image record in 'invoice_images' table.
 * User ID is obtained from authentication token.
 */
  router.post('/ocr-invoice', async (req, res) => {
  // invoiceId from body was present but seems redundant if imageId is the primary key for invoice_images.
  // userId is now from req.user.id via authenticateUser middleware.
  const { imageUrl, imageData, projectId, imageId } = req.body;
  const userId = req.user.id; // Get from authenticated user

  if (!projectId || !imageId) {
    return res.status(400).json({ error: 'projectId and imageId are required.' });
    }
    if (!imageUrl && !imageData) {
    return res.status(400).json({ error: 'Must provide either imageUrl or imageData.' });
    }
  console.log(`[Routes/OCR] /ocr-invoice POST for imageId: ${imageId}, userId: ${userId}, projectId: ${projectId}`);

    try {
    // Update DB: Set status to pending_ocr for the imageId
    // This step might be optional if the image record is already created elsewhere with a pending status.
    // For now, we assume it might be the first time we are associating this imageId with OCR processing.
    try {
      if (typeof projectService.updateImageMetadata !== 'function') {
        console.warn('[Routes/OCR] projectService.updateImageMetadata not available. Skipping status update to pending_ocr.');
      } else {
        // Use updateImageMetadata; if image doesn't exist, it might fail or do nothing depending on service logic.
        // Consider if an addInitialInvoiceImage or similar is more appropriate if the record might not exist.
        await projectService.updateImageMetadata(imageId, { status: 'pending_ocr' }, userId);
        console.log(`[Routes/OCR] Status set to 'pending_ocr' in DB for imageId: ${imageId}`);
      }
    } catch (dbError) {
      console.error(`[Routes/OCR] Error setting status to 'pending_ocr' for imageId: ${imageId}. Continuing...`, dbError);
    }
      
      let detectResult = null;
      if (imageData) {
      // imageData (direct upload) is complex with Cloud Run scaling & GCS. For now, focusing on imageUrl from GCS.
      console.warn('[Routes/OCR] imageData (direct base64 upload) processing is not fully supported in this version. Please use imageUrl.');
      return res.status(400).json({ error: 'imageData processing not yet fully supported. Please use imageUrl from GCS.' });
    } else { // Process imageUrl
        let retryCount = 0;
        const maxRetries = 2;
        let lastError = null;
      console.log(`[Routes/OCR] Attempting to download image from URL: ${imageUrl} for imageId: ${imageId}`);
        while (retryCount <= maxRetries) {
          try {
          const response = await axios.get(imageUrl, { responseType: 'arraybuffer', timeout: 20000 }); // Increased timeout
            const imageBuffer = Buffer.isBuffer(response.data) ? response.data : Buffer.from(response.data);
          console.log(`[Routes/OCR] Image downloaded successfully for imageId: ${imageId}. Buffer length: ${imageBuffer.length}. Initiating text detection.`);
          detectResult = await detectTextInImage(imageUrl, imageBuffer); // detectTextInImage expects buffer or imageUrl
          console.log(`[Routes/OCR] Text detection complete for imageId: ${imageId}. Success: ${detectResult.success}`);
          break; // Success, exit retry loop
          } catch (err) {
          lastError = err;
          console.error(`[Routes/OCR] Error during image download or OCR (Attempt ${retryCount + 1}/${maxRetries + 1}) for imageId: ${imageId}:`, err.message);
            if (err.response) {
            console.error('[Routes/OCR] Axios error response status:', err.response.status);
          }
          if (retryCount === maxRetries) {
            console.error('[Routes/OCR] Max retries reached for imageId: ${imageId}. OCR failed.');
            break; // Max retries reached, exit loop
          }
          await new Promise(resolve => setTimeout(resolve, Math.pow(2, retryCount) * 1500)); // Exponential backoff
            retryCount++;
          console.log(`[Routes/OCR] Retrying OCR for imageId: ${imageId} (Attempt ${retryCount + 1})`);
          }
        }
      if (!detectResult && lastError) throw lastError; // If all retries failed, throw the last error
      if (!detectResult) throw new Error('OCR process failed after retries without specific error.');
      }

    const ocrTimestamp = new Date();
    let dbUpdatePayload = {};

      if (detectResult.success) {
      const newStatus = detectResult.extractedText ? 'ocr_complete' : 'ocr_no_text';
      dbUpdatePayload = {
        status: newStatus,
              ocr_text: detectResult.extractedText ?? '',
              ocr_confidence: detectResult.confidence || 0,
        // textBlocks are often too large for a simple DB field, consider if needed or how to store.
        // ocr_text_blocks: detectResult.textBlocks || [], 
        ocr_processed_at: ocrTimestamp,
        error_message: detectResult.error || null // Should be null if success is true
      };
      console.log(`[Routes/OCR] OCR successful for imageId: ${imageId}. Status: ${newStatus}`);
      } else {
      dbUpdatePayload = {
        status: 'ocr_failed',
              ocr_text: '',
        ocr_processed_at: ocrTimestamp,
              error_message: detectResult.error || 'OCR process failed or no text found'
            };
      console.warn(`[Routes/OCR] OCR failed for imageId: ${imageId}. Error: ${dbUpdatePayload.error_message}`);
    }

    // Update DB with OCR results
    try {
      if (typeof projectService.updateImageMetadata !== 'function') {
        console.warn('[Routes/OCR] projectService.updateImageMetadata not available. Cannot save OCR results to DB.');
      } else {
        await projectService.updateImageMetadata(imageId, dbUpdatePayload, userId);
        console.log(`[Routes/OCR] OCR data updated in DB for imageId: ${imageId}`);
      }
    } catch (dbUpdateError) {
      console.error(`[Routes/OCR] Error updating DB with OCR data for imageId: ${imageId}. Client will still get vision result.`, dbUpdateError);
          }

    res.json(detectResult); // Send the raw result from visionService back to the client
    } catch (error) {
    console.error(`[Routes/OCR] Overall CATCH BLOCK for imageId: ${imageId}. Error: ${error.message}`, error.stack);
      const errorTimestamp = new Date();
      try {
      if (typeof projectService.updateImageMetadata === 'function') {
        const errorDbPayload = {
          status: 'ocr_failed',
              ocr_processed_at: errorTimestamp,
          error_message: String(error.message || 'OCR process failed in main catch').substring(0, 500)
            };
        await projectService.updateImageMetadata(imageId, errorDbPayload, userId);
        console.log(`[Routes/OCR] OCR error state (overall catch) updated in DB for imageId: ${imageId}`);
      } else {
        console.warn('[Routes/OCR] projectService.updateImageMetadata not available in CATCH block. Cannot log OCR error to DB.');
        }
      } catch (serviceError) {
      console.error(`[Routes/OCR] DB update FAILED in overall catch block for imageId ${imageId}:`, serviceError.message);
      }
      res.status(500).json({ success: false, error: error.message || 'OCR process failed overall' });
    }
  });

console.log('[Routes/OCR] Routes defined, exporting router.');
module.exports = router;