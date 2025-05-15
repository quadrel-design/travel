/**
 * @fileoverview OCR (Optical Character Recognition) Routes.
 * Handles API endpoints related to OCR processing of images, typically invoices or receipts.
 * It uses the Vision API (via `visionService`) for text detection and updates
 * image metadata in the database (via `projectService`).
 * @module routes/ocr
 */

const express = require('express');
const router = express.Router();
const axios = require('axios');
const { detectTextInImage } = require('../services/visionService');
const projectService = require('../services/projectService'); // For DB interactions
const firebaseAdmin = require('firebase-admin'); // For authentication

/**
 * Middleware to authenticate users using Firebase ID tokens.
 * Verifies the Bearer token from the Authorization header.
 * Attaches the decoded token (including user UID and email) to `req.user`.
 * TODO: Refactor this to a shared middleware in the `middleware/` directory.
 *
 * @async
 * @param {import('express').Request} req - Express request object.
 * @param {import('express').Response} res - Express response object.
 * @param {import('express').NextFunction} next - Express next middleware function.
 */
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
    req.user = { // Attach user to request object with a consistent structure
      id: decodedToken.uid, 
      email: decodedToken.email
    }; 
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
 * @summary Performs OCR on an image specified by a GCS URL.
 * @description This endpoint initiates OCR processing for an image that presumably resides in Google Cloud Storage (GCS).
 * It first updates the image's status to `pending_ocr` in the database.
 * Then, it fetches the image from the provided `imageUrl` (GCS URI), sends it to the Vision API for text detection.
 * The OCR results (extracted text, confidence) and final status (`ocr_complete`, `ocr_no_text`, or `ocr_failed`)
 * are then saved to the image's database record.
 * The `imageData` (direct base64 upload) path is currently not fully supported and will result in an error.
 * Retries image download and OCR processing on failure with exponential backoff.
 *
 * @body {string} imageUrl - The GCS URI of the image to process (e.g., `gs://<bucket-name>/path/to/image.jpg`).
 * @body {string} projectId - The ID of the project to which the image belongs (for context and DB record consistency).
 * @body {string} imageId - The ID of the image record in the `invoice_images` table to update.
 *
 * @response {200} OK - OCR process completed (successfully or with no text found).
 *   @example response - 200 - OCR Successful
 *   {
 *     "success": true,
 *     "status": "ocr_complete",
 *     "message": "OCR successful",
 *     "ocrText": "Extracted text...",
 *     "ocrConfidence": 0.92
 *   }
 * @response {200} OK - OCR completed, no text found.
 *   @example response - 200 - No Text Found
 *   {
 *     "success": true,
 *     "status": "ocr_no_text",
 *     "message": "OCR successful, no text detected",
 *     "ocrText": "",
 *     "ocrConfidence": 0
 *   }
 * @response {400} Bad Request - Missing required fields (`projectId`, `imageId`, `imageUrl`) or `imageData` provided.
 * @response {500} Internal Server Error - If the OCR process encounters an unrecoverable error, or if database updates fail.
 *   The image status in the database is updated to `ocr_failed` with an error message.
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
    try {
      if (typeof projectService.updateImageMetadata !== 'function') {
        console.warn('[Routes/OCR] projectService.updateImageMetadata not available. OCR cannot proceed.');
        throw new Error('projectService.updateImageMetadata is not a function, OCR aborted.');
      } else {
        await projectService.updateImageMetadata(imageId, { status: 'pending_ocr', ocr_processed_at: new Date() }, userId);
        console.log(`[Routes/OCR] Status set to 'pending_ocr' in DB for imageId: ${imageId}`);
      }
    } catch (dbError) {
      console.error(`[Routes/OCR] CRITICAL: Failed to set status to 'pending_ocr' for imageId: ${imageId}. Aborting OCR.`, dbError);
      throw dbError; // Re-throw to be caught by the main catch block
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
        throw new Error('projectService.updateImageMetadata is not a function, cannot save OCR results.');
      } else {
        await projectService.updateImageMetadata(imageId, dbUpdatePayload, userId);
        console.log(`[Routes/OCR] OCR data updated in DB for imageId: ${imageId}`);
      }
    } catch (dbUpdateError) {
      console.error(`[Routes/OCR] CRITICAL: Error updating DB with OCR data for imageId: ${imageId}.`, dbUpdateError);
      throw dbUpdateError; // Re-throw to be caught by the main catch block
    }

    // Construct a standardized response
    const responsePayload = {
      success: detectResult.success,
      status: dbUpdatePayload.status, // This is our application-defined status
      message: detectResult.success ? (detectResult.extractedText ? 'OCR successful' : 'OCR successful, no text detected') : (detectResult.error || 'OCR failed'),
      ocrText: detectResult.extractedText || null,
      ocrConfidence: detectResult.confidence || null,
      // rawVisionResult: detectResult // Optionally include the full vision result if client needs it
    };
    res.json(responsePayload);

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