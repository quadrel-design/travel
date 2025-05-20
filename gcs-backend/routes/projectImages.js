/**
 * @fileoverview Project Image Management Routes.
 * Provides REST API endpoints for managing images associated with a specific project.
 * This router is intended to be mounted under a specific project ID (e.g., /api/projects/:projectId/images).
 * It handles CRUD operations for image metadata, including specific updates for OCR and Analysis.
 * Image file uploads are handled via client-side uploads to GCS; this module manages metadata.
 * @module routes/projectImages
 */
const express = require('express');
const router = express.Router({ mergeParams: true }); // Enable mergeParams to access projectId
const { Storage } = require('@google-cloud/storage');
const invoiceService = require('../services/invoiceService');
const logger = require('../config/logger');

// Google Cloud Storage client (similar to projects.js)
const storageBucketName = process.env.GCS_BUCKET_NAME || 'travel-app-invoices';
let storageClient;
let bucket;
try {
  storageClient = new Storage();
  bucket = storageClient.bucket(storageBucketName);
  logger.info(`[Routes/ProjectImages] Successfully connected to GCS bucket: ${storageBucketName}`);
} catch (error) {
  logger.error(`[Routes/ProjectImages] CRITICAL ERROR: Failed to initialize Google Cloud Storage client or bucket '${storageBucketName}':`, error);
  logger.warn('[Routes/ProjectImages] GCS operations related to file deletion might fail.');
}

// Check if invoiceService is available
if (!invoiceService) {
  logger.error('[Routes/ProjectImages] CRITICAL ERROR - invoiceService was not imported or is unavailable.');
  // throw new Error('[Routes/ProjectImages] invoiceService is critical and not available.'); // Optional: hard fail
}

// --- Image Routes ---

/**
 * @route GET /
 * @summary Get all images for the specified project.
 * @description (Mounted under /api/projects/:projectId/images) Retrieves metadata for all images associated with :projectId.
 * @returns {object[]} 200 - An array of image metadata objects.
 * @returns {Error} 500 - If there's an error.
 */
router.get('/', async (req, res) => {
  const userId = req.user.id; // Assumes authenticateUser middleware is applied by parent router
  const { projectId } = req.params;
  logger.info(`[Routes/ProjectImages] GET / (for project ${projectId}) - User: ${userId}`);

  try {
    if (!invoiceService || typeof invoiceService.getProjectImages !== 'function') {
      logger.error('[Routes/ProjectImages] invoiceService.getProjectImages is not available!');
      return res.status(500).json({ error: 'Image service not configured correctly.' });
    }
    const images = await invoiceService.getProjectImages(projectId, userId);
    res.status(200).json(images);
  } catch (error) {
    logger.error(`[Routes/ProjectImages] Error fetching images for project ${projectId}:`, error);
    res.status(500).json({ error: 'Failed to fetch images for project' });
  }
});

/**
 * @route GET /:imageId
 * @summary Get metadata for a specific image.
 * @description (Mounted under /api/projects/:projectId/images) Retrieves metadata for :imageId within :projectId.
 * @param {string} req.params.imageId - The client-generated ID of the image.
 * @returns {object} 200 - The image metadata object.
 * @returns {Error} 404 - If not found.
 * @returns {Error} 500 - If there's an error.
 */
router.get('/:imageId', async (req, res) => {
  const userId = req.user.id;
  const { projectId, imageId } = req.params;
  logger.info(`[Routes/ProjectImages] GET /${imageId} (for project ${projectId}) - User: ${userId}`);

  try {
    if (!invoiceService || typeof invoiceService.getInvoiceImageById !== 'function') {
      logger.error('[Routes/ProjectImages] invoiceService.getInvoiceImageById is not available!');
      return res.status(500).json({ error: 'Image service not configured correctly.' });
    }
    const image = await invoiceService.getInvoiceImageById(imageId, projectId, userId);
    res.status(200).json(image);
  } catch (error) {
    logger.error(`[Routes/ProjectImages] Error fetching image ${imageId} for project ${projectId}:`, { message: error.message, stack: error.stack, statusCode: error.statusCode });
    if (error.statusCode === 404) {
      return res.status(404).json({ error: error.message });
    }
    if (error.statusCode === 403) {
      return res.status(403).json({ error: error.message });
    }
    res.status(500).json({ error: 'Failed to fetch image' });
  }
});

/**
 * @route POST /metadata
 * @summary Create image metadata record after GCS upload.
 * @description (Mounted under /api/projects/:projectId/images) Called by client after GCS upload via signed URL.
 * Creates image metadata in PostgreSQL.
 * @body {object} imageMetadata - Object containing image metadata. Expected fields: `id` (client-generated imageId), `gcsPath` (full GCS path), `projectId`, `originalFilename`, `size`, `contentType`, `uploaded_at` (optional, defaults to now), `status` (optional, defaults to 'uploaded').
 * @returns {object} 201 - The newly created image metadata.
 */
router.post('/metadata', async (req, res) => {
  const userId = req.user.id;
  const { projectId } = req.params;
  const { id, gcsPath, originalFilename, size, contentType, uploaded_at, status: bodyStatus } = req.body;

  logger.info(`[Routes/ProjectImages] POST /metadata (for project ${projectId}) for imageId: ${id} by user ${userId}`);

  if (!id || !gcsPath || !projectId ) {
    return res.status(400).json({ error: 'Missing required fields: id (imageId), gcsPath, projectId' });
  }

  try {
    const imageData = {
      id, 
      projectId,
      gcsPath,
      originalFilename,
      size,
      contentType,
      uploaded_at: uploaded_at || new Date().toISOString(),
      status: bodyStatus || 'uploaded'
    };
    
    if (!invoiceService || typeof invoiceService.saveImageMetadata !== 'function') {
      logger.error('[Routes/ProjectImages] invoiceService.saveImageMetadata is not available!');
      return res.status(500).json({ error: 'Image service not configured correctly.' });
    }

    const savedImage = await invoiceService.saveImageMetadata(imageData, userId);
    res.status(201).json(savedImage);
  } catch (error) {
    logger.error(`[Routes/ProjectImages] Error saving image metadata for project ${projectId}, imageId ${id}:`, { message: error.message, stack: error.stack, statusCode: error.statusCode });
    if (error.statusCode === 404) {
      return res.status(404).json({ error: error.message });
    }
    if (error.statusCode === 409) {
      return res.status(409).json({ error: error.message });
    }
    if (error.statusCode === 403) {
        return res.status(403).json({ error: error.message });
    }
    res.status(500).json({ error: 'Failed to save image metadata' });
  }
});

/**
 * @route DELETE /:imageId
 * @summary Delete an image and its metadata.
 * @description (Mounted under /api/projects/:projectId/images) Deletes image file from GCS and metadata from DB.
 * @param {string} req.params.imageId - The client-generated ID of the image.
 * @query {boolean} [deleteFromGCS=false] - If true, attempts to delete from GCS.
 * @returns {object} 200 - JSON object with success message and GCS deletion status.
 *   @example response - 200 - Success (GCS file deleted)
 *   {
 *     "message": "Image metadata deleted successfully",
 *     "imageId": "client-img-uuid-123",
 *     "gcsFileDeleted": true
 *   }
 *   @example response - 200 - Success (GCS file not deleted or not requested)
 *   {
 *     "message": "Image metadata deleted successfully",
 *     "imageId": "client-img-uuid-123",
 *     "gcsFileDeleted": false
 *   }
 * @returns {Error} 404 - Not found.
 * @returns {Error} 500 - Server error.
 */
router.delete('/:imageId', async (req, res) => {
  const userId = req.user.id;
  const { projectId, imageId } = req.params;
  const deleteFromGCS = req.query.deleteFromGCS === 'true';

  logger.info(`[Routes/ProjectImages] DELETE /${imageId} (project ${projectId}) - User: ${userId}, Delete from GCS: ${deleteFromGCS}`);

  try {
    if (!invoiceService || typeof invoiceService.getInvoiceImageById !== 'function' || typeof invoiceService.deleteImageMetadata !== 'function') {
      logger.error('[Routes/ProjectImages] Image service function (getInvoiceImageById or deleteImageMetadata) is not available!');
      return res.status(500).json({ error: 'Image service not configured correctly.' });
    }

    const image = await invoiceService.getInvoiceImageById(imageId, projectId, userId);

    let gcsFileActuallyDeleted = false;
    if (deleteFromGCS) {
      if (!bucket) {
        logger.error('[Routes/ProjectImages] GCS bucket is not initialized. Cannot delete from GCS.');
        return res.status(500).json({ error: 'Storage service not configured, cannot delete file.' });
      }
      const gcsPath = image.imagePath; 
      if (gcsPath) {
        logger.info(`[Routes/ProjectImages] Attempting to delete GCS object: ${gcsPath}`);
        try {
          await bucket.file(gcsPath).delete();
          logger.info(`[Routes/ProjectImages] Successfully deleted GCS object: ${gcsPath}`);
          gcsFileActuallyDeleted = true;
        } catch (gcsError) {
          logger.error(`[Routes/ProjectImages] Error deleting GCS object ${gcsPath}:`, gcsError);
          return res.status(500).json({ error: `Failed to delete image file from storage: ${gcsError.message}` });
        }
      }
    }

    await invoiceService.deleteImageMetadata(imageId, projectId, userId);
    res.status(200).json({ message: 'Image metadata deleted successfully', imageId: imageId, gcsFileDeleted: gcsFileActuallyDeleted });

  } catch (error) {
    logger.error(`[Routes/ProjectImages] Error deleting image ${imageId} for project ${projectId}:`, { message: error.message, stack: error.stack, statusCode: error.statusCode });
    if (error.statusCode === 404) {
      return res.status(404).json({ error: error.message });
    }
    if (error.statusCode === 403) {
      return res.status(403).json({ error: error.message });
    }
    res.status(500).json({ error: 'Failed to delete image' });
  }
});

/**
 * @route PATCH /:imageId/metadata
 * @summary Update metadata for a specific image.
 * @description (Mounted under /api/projects/:projectId/images) Manually updates image metadata.
 * @param {string} req.params.imageId - The image ID.
 * @body {object} updateData - Fields to update (e.g., status, ocr_text).
 * @returns {object} 200 - Updated image metadata.
 */
router.patch('/:imageId/metadata', async (req, res) => {
  const userId = req.user.id;
  const { projectId, imageId } = req.params;
  const updateData = req.body;

  logger.info(`[Routes/ProjectImages] PATCH /${imageId}/metadata (project ${projectId}) by user ${userId} with data: ${JSON.stringify(updateData)}`);

  if (Object.keys(updateData).length === 0) {
    return res.status(400).json({ error: 'No update data provided.' });
  }

  const forbiddenFields = ['id', 'projectId', 'user_id', 'gcsPath', 'gcs_path', 'created_at', 'uploaded_at'];
  let cleanUpdateData = { ...updateData };
  for (const field of forbiddenFields) {
    if (cleanUpdateData.hasOwnProperty(field)) {
      delete cleanUpdateData[field];
      logger.warn(`[Routes/ProjectImages] Attempt to update forbidden field '${field}' was removed from /metadata update.`);
    }
  }
  
  if (Object.keys(cleanUpdateData).length === 0) {
    return res.status(400).json({ error: 'No updatable fields provided after filtering forbidden fields for /metadata update.' });
  }

  try {
    if (!invoiceService || typeof invoiceService.updateImageMetadata !== 'function') {
      logger.error('[Routes/ProjectImages] invoiceService.updateImageMetadata is not available!');
      return res.status(500).json({ error: 'Image service not configured correctly.' });
    }

    const updatedImage = await invoiceService.updateImageMetadata(projectId, imageId, cleanUpdateData, userId);
    
    res.status(200).json(updatedImage);
  } catch (error) {
    logger.error(`[Routes/ProjectImages] Error updating image metadata for ${imageId} in project ${projectId} (/metadata):`, { message: error.message, stack: error.stack, statusCode: error.statusCode });
    if (error.statusCode === 404) {
      return res.status(404).json({ error: error.message });
    }
    if (error.statusCode === 403) {
      return res.status(403).json({ error: error.message });
    }
    res.status(500).json({ error: 'Failed to update image metadata' });
  }
});

/**
 * @route PATCH /:imageId/analysis
 * @summary Update analysis details for a specific image.
 * @description (Mounted under /api/projects/:projectId/images) Updates analysis-related metadata.
 * @param {string} req.params.imageId - The image ID.
 * @body {object} analysisData - Data like invoiceAnalysis, isInvoiceGuess, status.
 * @returns {object} 200 - Updated image object.
 */
router.patch('/:imageId/analysis', async (req, res) => {
  const userId = req.user.id;
  const { projectId, imageId } = req.params;
  const { invoiceAnalysis, isInvoiceGuess, status } = req.body;

  logger.info(`[Routes/ProjectImages] PATCH /${imageId}/analysis (project ${projectId}) - User: ${userId}`);
  logger.debug(`[Routes/ProjectImages] Request body for /analysis: ${JSON.stringify(req.body)}`);

  try {
    if (!invoiceService || typeof invoiceService.updateImageMetadata !== 'function') {
      logger.error('[Routes/ProjectImages] invoiceService.updateImageMetadata is not available for /analysis update!');
      return res.status(500).json({ error: 'Image service not configured correctly.' });
    }

    const dbPayload = {};
    if (invoiceAnalysis !== undefined) {
      dbPayload.gemini_analysis_json = invoiceAnalysis;
    }
    if (isInvoiceGuess !== undefined) {
      dbPayload.is_invoice = isInvoiceGuess;
    }
    if (status !== undefined) {
      dbPayload.status = status;
    }
    dbPayload.analysis_processed_at = new Date(); // Always update this timestamp
    
    if (Object.keys(dbPayload).length === 1 && dbPayload.analysis_processed_at) {
        logger.warn(`[Routes/ProjectImages] PATCH /${imageId}/analysis - No actual analysis data fields to update. Will only update timestamps.`);
    }

    const updatedImage = await invoiceService.updateImageMetadata(projectId, imageId, dbPayload, userId);

    if (!updatedImage) {
      return res.status(404).json({ error: 'Image not found or /analysis update failed' });
    }

    logger.info(`[Routes/ProjectImages] Successfully updated analysis details for image ${imageId} in project ${projectId}`);
    res.status(200).json(updatedImage);
  } catch (error) {
    logger.error(`[Routes/ProjectImages] Error updating image analysis details for ${imageId} in project ${projectId} (/analysis):`, { message: error.message, stack: error.stack, statusCode: error.statusCode });
    if (error.statusCode === 404) {
        return res.status(404).json({ error: error.message || 'Image not found or not authorized for update.' });
    }
    if (error.statusCode === 403) {
        return res.status(403).json({ error: error.message || 'User not authorized for this operation.' });
    }
    res.status(500).json({ error: 'Failed to update image analysis details' });
  }
});

module.exports = router; 