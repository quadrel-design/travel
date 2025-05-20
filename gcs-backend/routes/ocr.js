/**
 * @fileoverview OCR (Optical Character Recognition) Routes.
 * Handles API endpoints related to OCR processing of images, typically invoices or receipts.
 * It uses the Vision API (via `visionService`) for text detection and updates
 * image metadata in the database (via invoiceService).
 * @module routes/ocr
 */

const express = require('express');
const router = express.Router();
const axios = require('axios');
const { detectTextInImage } = require('../services/visionService');
// const projectService = require('../services/projectService'); // Removed as it's not directly used
const invoiceService = require('../services/invoiceService'); // Changed from imageService, For Image DB interactions
// const firebaseAdmin = require('firebase-admin'); // Removed: Not directly used; auth is via middleware.
const logger = require('../config/logger'); // Import logger
const authenticateUser = require('../middleware/authenticateUser'); // Import shared middleware

// Apply shared authentication middleware to all routes in this router
router.use(authenticateUser);

// Check if projectService is available - REMOVED check as service is not used
// if (!projectService) { ... }

// Check if invoiceService is available
if (!invoiceService) {
  const errorMessage = '[Routes/OCR] CRITICAL ERROR - invoiceService was not imported or is unavailable. OCR routes cannot function with DB.';
    logger.error(errorMessage);
    // throw new Error(errorMessage); // Replaced with logger.error to prevent immediate crash
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
    logger.warn('[Routes/OCR] Missing projectId or imageId in /ocr-invoice request', { body: req.body });
    return res.status(400).json({ error: 'projectId and imageId are required.' });
    }
    if (!imageUrl && !imageData) {
    logger.warn('[Routes/OCR] Missing imageUrl and imageData in /ocr-invoice request', { body: req.body });
    return res.status(400).json({ error: 'Must provide either imageUrl or imageData.' });
    }
  logger.info(`[Routes/OCR] /ocr-invoice POST for imageId: ${imageId}, userId: ${userId}, projectId: ${projectId}`);

    try {
    // Update DB: Set status to pending_ocr for the imageId
    try {
      if (typeof invoiceService.updateImageMetadata !== 'function') {
        logger.error('[Routes/OCR] invoiceService.updateImageMetadata not available. OCR cannot proceed.');
        throw new Error('invoiceService.updateImageMetadata is not a function, OCR aborted.');
      } else {
        await invoiceService.updateImageMetadata(projectId, imageId, { status: 'pending_ocr', ocr_processed_at: new Date() }, userId);
        logger.info(`[Routes/OCR] Status set to 'pending_ocr' in DB for imageId: ${imageId}`);
      }
    } catch (dbError) {
      logger.error(`[Routes/OCR] Failed to set status to 'pending_ocr' for imageId: ${imageId}. Aborting OCR.`, { error: dbError.message, statusCode: dbError.statusCode, stack: dbError.stack });
      if (dbError.statusCode === 404 || dbError.statusCode === 403) {
        return res.status(dbError.statusCode).json({ success: false, error: dbError.message });
      }
      // For other errors during this critical initial update, treat as 500 for now or re-evaluate
      return res.status(500).json({ success: false, error: `Failed to initialize OCR process for image: ${dbError.message}` });
    }
      
      let detectResult = null;
      if (imageData) {
      // imageData (direct upload) is complex with Cloud Run scaling & GCS. For now, focusing on imageUrl from GCS.
      logger.warn('[Routes/OCR] imageData (direct base64 upload) processing is not fully supported in this version. Please use imageUrl.');
      return res.status(400).json({ error: 'imageData processing not yet fully supported. Please use imageUrl from GCS.' });
    } else { // Process imageUrl
        let retryCount = 0;
        const maxRetries = 2;
        let lastError = null;
      logger.info(`[Routes/OCR] Attempting to download image from URL: ${imageUrl} for imageId: ${imageId}`);
        while (retryCount <= maxRetries) {
          try {
          const response = await axios.get(imageUrl, { responseType: 'arraybuffer', timeout: 20000 }); // Increased timeout
            const imageBuffer = Buffer.isBuffer(response.data) ? response.data : Buffer.from(response.data);
          logger.info(`[Routes/OCR] Image downloaded successfully for imageId: ${imageId}. Buffer length: ${imageBuffer.length}. Initiating text detection.`);
          detectResult = await detectTextInImage(imageUrl, imageBuffer); // detectTextInImage expects buffer or imageUrl
          logger.info(`[Routes/OCR] Text detection complete for imageId: ${imageId}. Success: ${detectResult.success}`);
          break; // Success, exit retry loop
          } catch (err) {
          lastError = err;
          logger.error(`[Routes/OCR] Error during image download or OCR (Attempt ${retryCount + 1}/${maxRetries + 1}) for imageId: ${imageId}:`, { errorMessage: err.message });
            if (err.response) {
            logger.error('[Routes/OCR] Axios error response status:', { status: err.response.status });
          }
          if (retryCount === maxRetries) {
            logger.error(`[Routes/OCR] Max retries reached for imageId: ${imageId}. OCR failed.`);
            break; // Max retries reached, exit loop
          }
          await new Promise(resolve => setTimeout(resolve, Math.pow(2, retryCount) * 1500)); // Exponential backoff
            retryCount++;
          logger.info(`[Routes/OCR] Retrying OCR for imageId: ${imageId} (Attempt ${retryCount + 1})`);
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
        error_message: null // Clear previous errors if successful
      };
      logger.info(`[Routes/OCR] OCR successful for imageId: ${imageId}. Status: ${newStatus}`);
      } else {
      dbUpdatePayload = {
        status: 'ocr_failed',
              ocr_text: '',
        ocr_processed_at: ocrTimestamp,
              error_message: detectResult.error || 'OCR process failed or no text found'
            };
      logger.warn(`[Routes/OCR] OCR failed for imageId: ${imageId}. Error: ${dbUpdatePayload.error_message}`);
    }

    // Update DB with OCR results
    try {
      if (typeof invoiceService.updateImageMetadata !== 'function') {
        logger.error('[Routes/OCR] invoiceService.updateImageMetadata not available. Cannot save OCR results to DB.');
        throw new Error('invoiceService.updateImageMetadata is not a function, cannot save OCR results.');
      } else {
        await invoiceService.updateImageMetadata(projectId, imageId, dbUpdatePayload, userId);
        logger.info(`[Routes/OCR] OCR data updated in DB for imageId: ${imageId}`);
      }
    } catch (dbUpdateError) {
      // If this update fails (e.g. image deleted between pending_ocr and now), it's an issue.
      // The OCR itself might have finished, but we can't save. Log critically.
      logger.error(`[Routes/OCR] CRITICAL: Error updating DB with OCR data for imageId: ${imageId}. OCR result might be lost.`, { error: dbUpdateError.message, statusCode: dbUpdateError.statusCode, stack: dbUpdateError.stack });
      // Don't return a specific 404/403 here as the main operation (OCR) might have completed.
      // Let the overall catch block handle this as a general failure to complete the request flow.
      throw dbUpdateError; 
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
    logger.error(`[Routes/OCR] Overall CATCH BLOCK for imageId: ${imageId}. Error: ${error.message}`, { stack: error.stack });
      const errorTimestamp = new Date();
      try {
      if (typeof invoiceService.updateImageMetadata === 'function') {
        const errorDbPayload = {
          status: 'ocr_failed',
              ocr_processed_at: errorTimestamp,
          error_message: String(error.message || 'OCR process failed in main catch').substring(0, 500)
            };
        await invoiceService.updateImageMetadata(projectId, imageId, errorDbPayload, userId);
        logger.info(`[Routes/OCR] OCR error state (overall catch) updated in DB for imageId: ${imageId}`);
      } else {
        logger.warn('[Routes/OCR] invoiceService.updateImageMetadata not available in CATCH block. Cannot log OCR error to DB.');
        }
      } catch (serviceErrorInCatch) {
      // If updating DB in catch block fails, especially with 404/403, the image might be gone.
      logger.error(`[Routes/OCR] DB update FAILED in overall catch block for imageId ${imageId}:`, { error: serviceErrorInCatch.message, statusCode: serviceErrorInCatch.statusCode, stack: serviceErrorInCatch.stack });
      }
      // The original error that led to this catch block determines the response
      // If it was a NotFoundError or NotAuthorizedError from the initial pending_ocr update, it would have returned already.
      // Otherwise, it's likely a 500 from OCR process or subsequent DB update failure.
      if (error.statusCode === 404 || error.statusCode === 403) {
           return res.status(error.statusCode).json({ success: false, error: error.message });
      }
      res.status(500).json({ success: false, error: error.message || 'OCR process failed overall' });
    }
  });

logger.info('[Routes/OCR] Routes defined, exporting router.');
module.exports = router;