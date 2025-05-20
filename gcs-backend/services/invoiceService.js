/**
 * @fileoverview Invoice Service Module.
 * This module provides functions to interact with image-related data (invoice_images) 
 * in the PostgreSQL database, associated with projects.
 * It handles CRUD operations for image metadata.
 * All functions assume that the PostgreSQL connection pool (`pool`) has been initialized and is available.
 * It also performs user authorization checks where applicable.
 * @module services/invoiceService
 */
const pool = require('../config/db'); // Import the pool
let sseServiceInstance; // For lazy loading
const logger = require('../config/logger'); // Added for logging
const { NotFoundError, NotAuthorizedError, ConflictError } = require('../utils/customErrors');

/**
 * @private
 * @function _transformDbImageToApiV1Format
 * @summary Transforms an image record from database format to API V1 format.
 * @description Converts a raw database row object for an image into a more client-friendly
 * structure, mapping snake_case column names to camelCase properties and performing
 * minor data transformations (e.g., ensuring `invoiceAnalysis` is an object).
 * 
 * @param {object} dbRow - The raw image object from the database.
 * @returns {object|null} The transformed image object for API response, or null if input is null.
 */
function _transformDbImageToApiV1Format(dbRow) {
  if (!dbRow) return null;
  return {
    id: dbRow.id,
    projectId: dbRow.project_id,
    userId: dbRow.user_id,
    status: dbRow.status,
    imagePath: dbRow.gcs_path,
    isInvoiceGuess: dbRow.is_invoice,
    ocrText: dbRow.ocr_text,
    ocrConfidence: dbRow.ocr_confidence,
    invoiceAnalysis: dbRow.gemini_analysis_json || {},
    analyzedInvoiceDate: dbRow.analyzed_invoice_date,
    invoiceSum: dbRow.invoice_sum,
    invoiceCurrency: dbRow.invoice_currency,
    invoiceTaxes: dbRow.invoice_taxes,
    invoiceLocation: dbRow.invoice_location,
    invoiceCategory: dbRow.invoice_category,
    invoiceTaxonomy: dbRow.invoice_taxonomy,
    errorMessage: dbRow.error_message,
    uploadedAt: dbRow.uploaded_at,
    createdAt: dbRow.created_at,
    updatedAt: dbRow.updated_at,
    originalFilename: dbRow.original_filename,
    contentType: dbRow.content_type,
    size: dbRow.size
  };
}

if (!pool) {
  const errorMessage = "invoiceService: CRITICAL ERROR - PostgreSQL pool was NOT imported or is undefined!";
  logger.error(errorMessage);
  logger.warn('invoiceService: Service will be non-functional as the DB pool is unavailable.');
}

logger.info('invoiceService: DB pool imported. Service getting initialized.');

class InvoiceService {
  /**
   * @async
   * @function getProjectImages
   * @summary Get all images associated with a specific project for a user.
   * @description Retrieves all image metadata records from the `invoice_images` table
   * that are linked to the given `projectId` and owned by the `userId`.
   * Results are transformed using `_transformDbImageToApiV1Format`.
   * 
   * @param {string} projectId - The UUID of the project whose images are to be fetched.
   * @param {string} userId - The UUID of the user who owns the project.
   * @returns {Promise<Array<object>>} A promise that resolves to an array of transformed image objects.
   * @throws {Error} If the DB pool is not available or the query fails.
   */
  async getProjectImages(projectId, userId) {
    if (!pool) { logger.error('[InvoiceService] DB Pool not available for getProjectImages'); throw new Error('DB Connection Error'); }
    const query = {
      text: `SELECT id, project_id, user_id, gcs_path, status, is_invoice, ocr_text, ocr_confidence, ocr_text_blocks, ocr_processed_at, analysis_processed_at, analyzed_invoice_date, invoice_sum, invoice_currency, invoice_taxes, invoice_location, invoice_category, invoice_taxonomy, gemini_analysis_json, error_message, uploaded_at, created_at, updated_at, original_filename, content_type, size 
             FROM invoice_images
             WHERE project_id = $1 AND user_id = $2
             ORDER BY created_at DESC`,
      values: [projectId, userId],
    };
    
    try {
      logger.info(`[InvoiceService] Fetching images for project ${projectId} and user ${userId}`);
      const res = await pool.query(query);
      const transformedImages = res.rows.map(row => _transformDbImageToApiV1Format(row));
      return transformedImages;
    } catch (err) {
      logger.error('[InvoiceService] Error fetching images for project:', { projectId, userId, error: err.message, stack: err.stack });
      throw err;
    }
  }
  
  /**
   * @async
   * @function getInvoiceImageById
   * @summary Get a specific image by its ID, project ID, and user ID.
   * @description Retrieves a single image metadata record from `invoice_images`.
   * Ensures the image belongs to the specified project and user.
   * The result is transformed by `_transformDbImageToApiV1Format`.
   * 
   * @param {string} imageId - The client-generated UUID of the image.
   * @param {string} projectId - The UUID of the project the image belongs to.
   * @param {string} userId - The UUID of the user who owns the image.
   * @param {boolean} [throwOnNotFound=true] - Whether to throw NotFoundError if image not found.
   * @returns {Promise<object>} A promise that resolves to the transformed image object.
   * @throws {NotFoundError} If the image is not found and throwOnNotFound is true.
   * @throws {Error} If the DB pool is not available or the query fails.
   */
  async getInvoiceImageById(imageId, projectId, userId, throwOnNotFound = true) {
    if (!pool) { 
      logger.error('[InvoiceService] DB Pool not available for getInvoiceImageById'); 
      throw new Error('DB Connection Error'); 
    }
    const query = {
      text: `SELECT id, project_id, user_id, gcs_path, status, is_invoice, ocr_text, ocr_confidence, ocr_text_blocks, ocr_processed_at, analysis_processed_at, analyzed_invoice_date, invoice_sum, invoice_currency, invoice_taxes, invoice_location, invoice_category, invoice_taxonomy, gemini_analysis_json, error_message, uploaded_at, created_at, updated_at, original_filename, content_type, size  
             FROM invoice_images
             WHERE id = $1 AND project_id = $2 AND user_id = $3`,
      values: [imageId, projectId, userId],
    };

    try {
      logger.info(`[InvoiceService] Fetching image ${imageId} for project ${projectId}, user ${userId}`);
      const res = await pool.query(query);
      if (res.rows.length === 0) {
        if (throwOnNotFound) {
          logger.warn(`[InvoiceService] Image ${imageId} not found for project ${projectId}, user ${userId}.`);
          throw new NotFoundError(`Image with id ${imageId} not found in project ${projectId} or not authorized for user ${userId}.`);
        }
        return null;
      }
      const row = res.rows[0];
      return _transformDbImageToApiV1Format(row);
    } catch (err) {
      logger.error('[InvoiceService] Error fetching image:', { imageId, projectId, userId, error: err.message, stack: err.stack });
      if (err instanceof NotFoundError) throw err;
      throw err;
    }
  }

  /**
   * @async
   * @function saveImageMetadata
   * @summary Save metadata for a new image associated with a project.
   * @description Inserts a new image metadata record into the `invoice_images` table.
   * 
   * @param {object} imageData - Metadata for the new image.
   * @param {string} imageData.id - Client-generated UUID for the image.
   * @param {string} imageData.projectId - UUID of the project this image belongs to.
   * @param {string} imageData.gcsPath - Full GCS object path of the image.
   * @param {string} userId - The UUID of the user uploading the image.
   * @returns {Promise<object>} A promise that resolves to the transformed newly created image object.
   * @throws {Error} If DB pool not available, required fields missing, or query fails.
   */
  async saveImageMetadata(imageData, userId) {
    if (!pool) { 
      logger.error('[InvoiceService] DB Pool not available for saveImageMetadata'); 
      throw new Error('DB Connection Error'); 
    }
    const {
      id, 
      projectId,
      gcsPath,
      status,
      originalFilename,
      size,
      contentType,
      uploaded_at
    } = imageData;

    if (!id || !projectId || !gcsPath || !userId) {
        logger.error('[InvoiceService] Missing required fields for saveImageMetadata:', { data: imageData, userId });
        throw new Error('Required image metadata (id, projectId, gcsPath) or userId is missing.');
    }
    
    const query = {
      text: `INSERT INTO invoice_images(
              id, project_id, user_id, gcs_path, status, 
              original_filename, size, content_type, uploaded_at
            ) VALUES($1, $2, $3, $4, $5, $6, $7, $8, $9) 
            RETURNING *`,
      values: [
        id, 
        projectId,
        userId, 
        gcsPath,
        status || 'uploaded',
        originalFilename, 
        size, 
        contentType, 
        uploaded_at || new Date()
      ],
    };

    try {
      logger.info(`[InvoiceService] Saving image metadata for image ${id} in project ${projectId} by user ${userId}`);
      const res = await pool.query(query);
      const savedImage = _transformDbImageToApiV1Format(res.rows[0]);

      if (savedImage) {
        try {
          if (!sseServiceInstance) sseServiceInstance = require('./sseService');
          const updatedImages = await this.getProjectImages(projectId, userId);
          sseServiceInstance.sendSseUpdateToProject(projectId, 'imagesUpdated', updatedImages);
        } catch (sseError) {
          logger.error('[InvoiceService] SSE Update failed after saving image:', { imageId: id, projectId, error: sseError.message, stack: sseError.stack });
        }
      }
      return savedImage;
    } catch (err) {
      logger.error('[InvoiceService] Error saving image metadata:', { projectId, imageId: id, error: err.message, stack: err.stack });
      if (err.code === '23503') {
        throw new NotFoundError(`Project with ID ${projectId} not found or user ${userId} is not authorized for it.`);
      }
      if (err.code === '23505') {
        throw new ConflictError(`Image with ID ${id} already exists for project ${projectId}.`);
      }
      throw err;
    }
  }

  /**
   * @async
   * @function deleteImageMetadata
   * @summary Delete image metadata from the database.
   * 
   * @param {string} imageId - The client-generated UUID of the image to delete.
   * @param {string} projectId - The UUID of the project the image belongs to.
   * @param {string} userId - The UUID of the user who owns the image.
   * @returns {Promise<object>} A promise that resolves to an object indicating deletion status.
   * @throws {Error} If DB pool not available or query fails.
   */
  async deleteImageMetadata(imageId, projectId, userId) {
    if (!pool) { 
      logger.error('[InvoiceService] DB Pool not available for deleteImageMetadata'); 
      throw new Error('DB Connection Error'); 
    }

    // Ensure image exists and user is authorized before attempting to delete
    await this.getInvoiceImageById(imageId, projectId, userId); // this will throw if not found/authorized

    const query = {
      text: 'DELETE FROM invoice_images WHERE id = $1 RETURNING id, gcs_path',
      values: [imageId],
    };

    try {
      logger.info(`[InvoiceService] Deleting image metadata for image ${imageId} in project ${projectId} by user ${userId}`);
      const res = await pool.query(query);
      if (res.rows.length === 0) {
        // This case should ideally be caught by getInvoiceImageById above.
        throw new NotFoundError(`Image with id ${imageId} not found during delete operation.`);
      }
      const deletedImage = res.rows[0];
      
      if (deletedImage) {
        try {
          if (!sseServiceInstance) sseServiceInstance = require('./sseService');
          const updatedImages = await this.getProjectImages(projectId, userId);
          sseServiceInstance.sendSseUpdateToProject(projectId, 'imagesUpdated', updatedImages);
        } catch (sseError) {
          logger.error('[InvoiceService] SSE Update failed after deleting image:', { imageId, projectId, error: sseError.message, stack: sseError.stack });
        }
      }
      return { id: deletedImage.id, gcsPath: deletedImage.gcs_path, message: 'Image metadata deleted successfully' };
    } catch (err) {
      logger.error('[InvoiceService] Error deleting image metadata:', { imageId, projectId, error: err.message, stack: err.stack });
      if (err instanceof NotFoundError) throw err;
      throw err;
    }
  }

  /**
   * @async
   * @function updateImageOcrResults
   * @summary Update an image record with OCR results.
   * @deprecated This method is now a wrapper around `updateImageMetadata` for backward compatibility or specific OCR update flow.
   *             Consider calling `updateImageMetadata` directly with the appropriate OCR fields.
   *
   * @param {string} projectId - The UUID of the project.
   * @param {string} imageId - The UUID of the image.
   * @param {object} ocrData - The OCR data to update.
   * @param {string} ocrData.status - New status (e.g., 'ocr_complete', 'ocr_failed').
   * @param {string} [ocrData.ocrText] - Extracted OCR text.
   * @param {number} [ocrData.ocrConfidence] - OCR confidence score.
   * @param {Array<object>} [ocrData.textBlocks] - Detailed text blocks from OCR (if any).
   * @param {string} [ocrData.errorMessage] - Error message if OCR failed.
   * @param {string} userId - The UUID of the user performing the update (for auditing/authorization).
   * @returns {Promise<object>} A promise that resolves to the transformed updated image object.
   */
  async updateImageOcrResults(projectId, imageId, ocrData, userId) {
    logger.info(`[InvoiceService] updateImageOcrResults (deprecated wrapper) called for image ${imageId}`);
    // Construct the imageData payload for updateImageMetadata
    const imageData = {
      status: ocrData.status,
      ocr_text: ocrData.ocrText,
      ocr_confidence: ocrData.ocrConfidence,
      // ocr_text_blocks: ocrData.textBlocks, // Consider if this should be directly set or handled differently
      error_message: ocrData.errorMessage,
      ocr_processed_at: new Date(), // Update the processed timestamp
    };
    return this.updateImageMetadata(projectId, imageId, imageData, userId);
  }

  /**
   * @async
   * @function updateImageMetadata
   * @summary Updates various metadata fields for an existing image.
   * @description This function allows partial updates to an image's metadata in the `invoice_images` table.
   * It dynamically builds the SQL query based on the fields provided in `imageData`.
   * Before updating, it verifies that the image exists and belongs to the user.
   * After a successful update, it sends an SSE notification.
   *
   * @param {string} projectId - The UUID of the project.
   * @param {string} imageId - The UUID of the image to update.
   * @param {object} imageData - An object containing the fields to update. 
   *                             Keys should match database column names (e.g., `status`, `ocr_text`, `gemini_analysis_json`).
   * @param {string} userId - The UUID of the user performing the update.
   * @returns {Promise<object>} A promise that resolves to the transformed updated image object.
   * @throws {NotFoundError} If the image is not found or user is not authorized.
   * @throws {Error} If no valid fields are provided for update, or if the DB query fails.
   */
  async updateImageMetadata(projectId, imageId, imageData, userId) {
    if (!pool) { 
      logger.error('[InvoiceService] DB Pool not available for updateImageMetadata'); 
      throw new Error('DB Connection Error'); 
    }

    // 1. Verify image exists and user is authorized by trying to fetch it first.
    // We pass false to not throw on not found here, as we want to handle it specifically in this function if needed.
    const existingImage = await this.getInvoiceImageById(imageId, projectId, userId, false);
    if (!existingImage) {
      throw new NotFoundError(`Image with id ${imageId} not found in project ${projectId} or not authorized for user ${userId}. Cannot update.`);
    }

    const validUpdateFields = [
      'status', 'is_invoice', 'ocr_text', 'ocr_confidence', 'ocr_text_blocks',
      'ocr_processed_at', 'analysis_processed_at', 'analyzed_invoice_date',
      'invoice_sum', 'invoice_currency', 'invoice_taxes', 'invoice_location',
      'invoice_category', 'invoice_taxonomy', 'gemini_analysis_json', 'error_message'
    ];

    const updates = [];
    const values = [];
    let valueCount = 1;

    for (const field of validUpdateFields) {
      if (imageData.hasOwnProperty(field)) {
        updates.push(`${field} = $${valueCount++}`);
        values.push(imageData[field]);
      }
    }
    
    // Always update the 'updated_at' timestamp
    updates.push(`updated_at = $${valueCount++}`);
    values.push(new Date());

    if (updates.length === 1) { // Only updated_at was added
      logger.warn('[InvoiceService] No valid fields provided for image metadata update other than timestamp.', { imageId, projectId, imageData });
      // Optionally, decide if this should be an error or just return the existing image
      // For now, proceed with the updated_at touch
      // throw new Error('No valid fields provided for image metadata update.');
    }

    values.push(imageId); // For the WHERE clause
    values.push(projectId); // For the WHERE clause
    values.push(userId);    // For the WHERE clause

    const queryText = `UPDATE invoice_images SET ${updates.join(', ')} 
                       WHERE id = $${valueCount++} AND project_id = $${valueCount++} AND user_id = $${valueCount++}
                       RETURNING *`;
    
    const query = {
      text: queryText,
      values: values,
    };

    try {
      logger.info(`[InvoiceService] Updating image metadata for image ${imageId} in project ${projectId} by user ${userId}. Fields: ${Object.keys(imageData).join(', ')}`);
      const res = await pool.query(query);
      if (res.rows.length === 0) {
        // This should ideally be caught by the initial getInvoiceImageById check, but as a safeguard:
        throw new NotFoundError(`Image with id ${imageId} not found during update, or not authorized.`);
      }
      const updatedImage = _transformDbImageToApiV1Format(res.rows[0]);

      if (updatedImage) {
        try {
          if (!sseServiceInstance) sseServiceInstance = require('./sseService');
          const updatedImages = await this.getProjectImages(projectId, userId);
          sseServiceInstance.sendSseUpdateToProject(projectId, 'imagesUpdated', updatedImages);
        } catch (sseError) {
          logger.error('[InvoiceService] SSE Update failed after updating image metadata:', { imageId, projectId, error: sseError.message, stack: sseError.stack });
        }
      }
      return updatedImage;
    } catch (err) {
      logger.error('[InvoiceService] Error updating image metadata:', { imageId, projectId, error: err.message, stack: err.stack });
      if (err instanceof NotFoundError) throw err;
      throw err;
    }
  }
}

module.exports = new InvoiceService(); 