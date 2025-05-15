/**
 * @fileoverview Project Service Module.
 * This module provides functions to interact with project-related data in the PostgreSQL database.
 * It handles CRUD operations for projects and their associated images (metadata).
 * It includes helper functions for data transformation between database and API formats.
 * All functions assume that the PostgreSQL connection pool (`pool`) has been initialized and is available.
 * It also performs user authorization checks where applicable by ensuring operations are performed
 * by the owner of the data.
 * @module services/projectService
 */
const pool = require('../config/db'); // Import the pool

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
 * @property {string} id - Image ID (client-generated UUID).
 * @property {string} projectId - ID of the project this image belongs to.
 * @property {string} userId - ID of the user who owns this image.
 * @property {string} status - Current processing status of the image (e.g., 'uploaded', 'ocr_complete', 'analysis_failed').
 * @property {string} imagePath - Full GCS object path for the image file.
 * @property {boolean|null} isInvoiceGuess - Boolean indicating if the image is likely an invoice (from AI analysis or manual override).
 * @property {string|null} ocrText - Extracted text from OCR processing.
 * @property {number|null} ocrConfidence - Confidence score from OCR.
 * @property {object} invoiceAnalysis - Structured analysis data from Gemini AI (e.g., total amount, date, merchant).
 * @property {string|null} analyzedInvoiceDate - Invoice date extracted from analysis (ISO 8601 format).
 * @property {number|null} invoiceSum - Total sum of the invoice extracted from analysis.
 * @property {string|null} invoiceCurrency - Currency of the invoice sum.
 * @property {number|null} invoiceTaxes - Taxes amount from the invoice.
 * @property {string|null} errorMessage - Error message if any processing step failed.
 * @property {string} uploadedAt - Timestamp of when the image was uploaded (ISO 8601 format).
 * @property {string} createdAt - Timestamp of when the image record was created (ISO 8601 format).
 * @property {string} updatedAt - Timestamp of when the image record was last updated (ISO 8601 format).
 * @property {string|null} originalFilename - Original filename of the uploaded image.
 * @property {string|null} contentType - MIME type of the image.
 * @property {number|null} size - Size of the image file in bytes.
 */
function _transformDbImageToApiV1Format(dbRow) {
  if (!dbRow) return null;
  return {
    id: dbRow.id,
    projectId: dbRow.project_id,
    userId: dbRow.user_id, // Included for completeness, client can ignore if not needed
    status: dbRow.status,
    imagePath: dbRow.gcs_path,
    isInvoiceGuess: dbRow.is_invoice, // Handles null/undefined implicitly
    ocrText: dbRow.ocr_text,
    ocrConfidence: dbRow.ocr_confidence,
    // ocr_text_blocks: dbRow.ocr_text_blocks, // Usually not directly needed by client
    // ocr_processed_at: dbRow.ocr_processed_at,
    // analysis_processed_at: dbRow.analysis_processed_at,
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
  // This check is more for immediate feedback during development.
  // The db.js itself has more robust logging if pool creation fails.
  const errorMessage = "projectService: CRITICAL ERROR - PostgreSQL pool was NOT imported or is undefined!";
  console.error(errorMessage);
  // Depending on the application's error handling strategy, you might:
  // 1. Throw an error to halt startup (safer for production if DB is essential).
  // throw new Error(errorMessage);
  // 2. Allow the app to start but this service will be non-functional (as it is now).
  //    Operations calling this service would then fail at runtime.
  console.warn('projectService: Service will be non-functional as the DB pool is unavailable.');
}

console.log('projectService: DB pool imported. Service getting initialized.');

const projectService = {
  /**
   * @async
   * @function getUserProjects
   * @summary Get all projects for a specific user.
   * @description Retrieves all projects associated with the given `userId` from the database,
   * ordered by creation date in descending order.
   * 
   * @param {string} userId - The UUID of the user whose projects are to be fetched.
   * @returns {Promise<Array<object>>} A promise that resolves to an array of project objects.
   *                                   Each project object contains all fields from the `projects` table.
   * @throws {Error} If the database pool is not available or if the query fails.
   */
  getUserProjects: async (userId) => {
    if (!pool) { console.error('[ProjectService] DB Pool not available for getUserProjects'); throw new Error('DB Connection Error'); }
    const query = {
      text: 'SELECT * FROM projects WHERE user_id = $1 ORDER BY created_at DESC',
      values: [userId],
    };
    
    try {
      console.log(`[ProjectService] Fetching projects for user ${userId}`);
      const res = await pool.query(query);
      return res.rows;
    } catch (err) {
      console.error('[ProjectService] Error fetching user projects:', err.stack);
      throw err;
    }
  },

  /**
   * @async
   * @function getProjectById
   * @summary Get a specific project by its ID for a given user.
   * @description Retrieves a single project from the database based on its `projectId`,
   * ensuring that it belongs to the specified `userId`.
   * 
   * @param {string} projectId - The UUID of the project to fetch.
   * @param {string} userId - The UUID of the user who should own the project.
   * @returns {Promise<object|undefined>} A promise that resolves to the project object if found
   *                                     and owned by the user, otherwise `undefined`.
   * @throws {Error} If the database pool is not available or if the query fails.
   */
  getProjectById: async (projectId, userId) => {
    if (!pool) { console.error('[ProjectService] DB Pool not available for getProjectById'); throw new Error('DB Connection Error'); }
    const query = {
      text: 'SELECT * FROM projects WHERE id = $1 AND user_id = $2',
      values: [projectId, userId],
    };
    
    try {
      console.log(`[ProjectService] Fetching project ${projectId} for user ${userId}`);
      const res = await pool.query(query);
      return res.rows[0]; // Returns undefined if not found
    } catch (err) {
      console.error(`[ProjectService] Error fetching project ${projectId}:`, err.stack);
      throw err;
    }
  },

  /**
   * @async
   * @function createProject
   * @summary Create a new project for a user.
   * @description Inserts a new project record into the database. The project ID is generated
   * automatically using `gen_random_uuid()`. Default values are used for optional fields
   * if not provided in `projectData`.
   * 
   * @param {object} projectData - Data for the new project.
   * @param {string} projectData.user_id - The UUID of the user creating the project.
   * @param {string} projectData.title - Title of the project.
   * @param {string} [projectData.description=''] - Description of the project.
   * @param {string} [projectData.location=''] - Location of the project.
   * @param {string|Date} [projectData.start_date=NOW()] - Start date of the project.
   * @param {string|Date} [projectData.end_date=NOW()+7days] - End date of the project.
   * @param {number} [projectData.budget=0.0] - Budget for the project.
   * @param {boolean} [projectData.is_completed=false] - Completion status of the project.
   * @returns {Promise<object>} A promise that resolves to the newly created project object.
   * @throws {Error} If the database pool is not available or if the query fails.
   */
  createProject: async (projectData) => {
    if (!pool) { console.error('[ProjectService] DB Pool not available for createProject'); throw new Error('DB Connection Error'); }
    const { 
      user_id, 
      title, 
      description, 
      location, 
      start_date, 
      end_date, 
      budget, 
      is_completed 
    } = projectData;

    // Use PostgreSQL's gen_random_uuid() function to generate the ID
    const query = {
      text: `INSERT INTO projects(
              id, user_id, title, description, location, start_date, end_date, budget, is_completed
            ) VALUES(gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8) 
            RETURNING *`,
      values: [
        user_id,
        title,
        description || '',
        location || '',
        start_date || new Date(),
        end_date || new Date(new Date().setDate(new Date().getDate() + 7)), // Default to 7 days from now
        budget || 0.0,
        is_completed || false
      ],
    };
    
    try {
      console.log(`[ProjectService] Creating new project for user ${user_id}`);
      const res = await pool.query(query);
      return res.rows[0];
    } catch (err) {
      console.error('[ProjectService] Error creating project:', err);
      throw err;
    }
  },

  /**
   * @async
   * @function updateProject
   * @summary Update an existing project.
   * @description Updates specific fields of an existing project in the database.
   * Only fields present in `projectData` are updated. The `updated_at` timestamp is always updated.
   * Ensures the project belongs to the specified `userId` before updating.
   * 
   * @param {string} projectId - The UUID of the project to update.
   * @param {object} projectData - An object containing the fields to update.
   * @param {string} userId - The UUID of the user who owns the project.
   * @returns {Promise<object>} A promise that resolves to the updated project object.
   * @throws {Error} If the project is not found, not owned by the user, if the DB pool is unavailable, or if the query fails.
   */
  updateProject: async (projectId, projectData, userId) => {
    if (!pool) { console.error('[ProjectService] DB Pool not available for updateProject'); throw new Error('DB Connection Error'); }
    const {
      title,
      description,
      location,
      start_date,
      end_date,
      budget,
      is_completed
    } = projectData;

    const columnsToUpdate = [];
    const values = [];
    let placeholderIndex = 1;

    if (title !== undefined) {
      columnsToUpdate.push(`title = $${placeholderIndex++}`);
      values.push(title);
    }
    if (description !== undefined) {
      columnsToUpdate.push(`description = $${placeholderIndex++}`);
      values.push(description);
    }
    if (location !== undefined) {
      columnsToUpdate.push(`location = $${placeholderIndex++}`);
      values.push(location);
    }
    if (start_date !== undefined) {
      columnsToUpdate.push(`start_date = $${placeholderIndex++}`);
      values.push(start_date);
    }
    if (end_date !== undefined) {
      columnsToUpdate.push(`end_date = $${placeholderIndex++}`);
      values.push(end_date);
    }
    if (budget !== undefined) {
      columnsToUpdate.push(`budget = $${placeholderIndex++}`);
      values.push(budget);
    }
    if (is_completed !== undefined) {
      columnsToUpdate.push(`is_completed = $${placeholderIndex++}`);
      values.push(is_completed);
    }

    // Always update the updated_at timestamp
    columnsToUpdate.push(`updated_at = NOW()`);

    if (columnsToUpdate.length === 1 && columnsToUpdate[0] === 'updated_at = NOW()') { // only updated_at would be set
      console.warn(`[ProjectService] No actual fields to update for project ${projectId}, only updated_at. Returning current project.`);
      // Fetch and return the current project if no actual data fields were changed.
      return projectService.getProjectById(projectId, userId);
    }

    // Add projectId and userId to values for the WHERE clause
    values.push(projectId);
    values.push(userId);

    const queryText = `UPDATE projects SET ${columnsToUpdate.join(', ')} 
             WHERE id = $${placeholderIndex++} AND user_id = $${placeholderIndex}
             RETURNING *`;
    
    const query = {
      text: queryText,
      values: values,
    };
    
    try {
      console.log(`[ProjectService] Updating project ${projectId} for user ${userId} with query: ${queryText} and values: ${JSON.stringify(values)}`);
      const res = await pool.query(query);
      if (res.rows.length === 0) {
        throw new Error(`Project with id ${projectId} not found or not owned by user ${userId}`);
      }
      return res.rows[0];
    } catch (err) {
      console.error(`[ProjectService] Error updating project ${projectId}:`, err.stack);
      throw err;
    }
  },

  /**
   * @async
   * @function deleteProject
   * @summary Delete a project.
   * @description Deletes a project from the database, ensuring it belongs to the specified `userId`.
   * Associated images and expenses are expected to be deleted via CASCADE constraints in the DB schema.
   * 
   * @param {string} projectId - The UUID of the project to delete.
   * @param {string} userId - The UUID of the user who owns the project.
   * @returns {Promise<boolean>} A promise that resolves to `true` if deletion was successful (row was deleted),
   *                            `false` otherwise (project not found or not owned by user).
   * @throws {Error} If the database pool is not available or if the query fails.
   */
  deleteProject: async (projectId, userId) => {
    if (!pool) { console.error('[ProjectService] DB Pool not available for deleteProject'); throw new Error('DB Connection Error'); }
    const query = {
      text: 'DELETE FROM projects WHERE id = $1 AND user_id = $2 RETURNING id',
      values: [projectId, userId],
    };
    
    try {
      console.log(`[ProjectService] Deleting project ${projectId} for user ${userId}`);
      const res = await pool.query(query);
      if (res.rows.length === 0) {
        throw new Error(`Project with id ${projectId} not found or not owned by user ${userId}`);
      }
      return true;
    } catch (err) {
      console.error(`[ProjectService] Error deleting project ${projectId}:`, err.stack);
      throw err;
    }
  },

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
  getProjectImages: async (projectId, userId) => {
    if (!pool) { console.error('[ProjectService] DB Pool not available for getProjectImages'); throw new Error('DB Connection Error'); }
    const query = {
      text: `SELECT id, project_id, user_id, gcs_path, status, is_invoice, ocr_text, ocr_confidence, ocr_text_blocks, ocr_processed_at, analysis_processed_at, analyzed_invoice_date, invoice_sum, invoice_currency, invoice_taxes, invoice_location, invoice_category, invoice_taxonomy, gemini_analysis_json, error_message, uploaded_at, created_at, updated_at 
             FROM invoice_images
             WHERE project_id = $1 AND user_id = $2
             ORDER BY created_at DESC`,
      values: [projectId, userId],
    };
    
    try {
      console.log(`[ProjectService] Fetching images for project ${projectId}`);
      const res = await pool.query(query);
      
      // Transform data to match expected format in Flutter app
      const transformedImages = res.rows.map(row => _transformDbImageToApiV1Format(row));
      
      return transformedImages;
    } catch (err) {
      console.error(`[ProjectService] Error fetching images for project ${projectId}:`, err.stack);
      throw err;
    }
  },
  
  /**
   * @async
   * @function getInvoiceImageById
   * @summary Get a specific image by its ID, project ID, and user ID.
   * @description Retrieves a single image metadata record from `invoice_images` based on `imageId`,
   * `projectId`, and `userId`. The result is transformed by `_transformDbImageToApiV1Format`.
   * 
   * @param {string} projectId - The UUID of the project the image belongs to.
   * @param {string} imageId - The client-generated UUID of the image.
   * @param {string} userId - The UUID of the user who owns the image.
   * @returns {Promise<object|null>} A promise that resolves to the transformed image object if found,
   *                                  otherwise `null`.
   * @throws {Error} If the DB pool is not available or the query fails.
   */
  getInvoiceImageById: async (projectId, imageId, userId) => {
    if (!pool) { console.error('[ProjectService] DB Pool not available for getInvoiceImageById'); throw new Error('DB Connection Error'); }
    const query = {
      text: `SELECT id, project_id, user_id, gcs_path, status, is_invoice, ocr_text, ocr_confidence, ocr_text_blocks, ocr_processed_at, analysis_processed_at, analyzed_invoice_date, invoice_sum, invoice_currency, invoice_taxes, invoice_location, invoice_category, invoice_taxonomy, gemini_analysis_json, error_message, uploaded_at, created_at, updated_at 
             FROM invoice_images
             WHERE id = $1 AND project_id = $2 AND user_id = $3`,
      values: [imageId, projectId, userId],
    };

    try {
      console.log(`[ProjectService] Fetching image ${imageId} for project ${projectId}`);
      const res = await pool.query(query);
      if (res.rows.length === 0) {
        return null; // Or throw an error: new Error('Image not found or not authorized');
      }
      
      // Transform data
      const row = res.rows[0];
      return _transformDbImageToApiV1Format(row);
    } catch (err) {
      console.error(`[ProjectService] Error fetching image ${imageId}:`, err.stack);
      throw err;
    }
  },

  /**
   * @async
   * @function saveImageMetadata
   * @summary Save metadata for a new image associated with a project.
   * @description Inserts a new image metadata record into the `invoice_images` table.
   * This is typically called after a client has uploaded an image file to GCS.
   * The `imageData.id` is expected to be a client-generated UUID.
   * 
   * @param {object} imageData - Metadata for the new image.
   * @param {string} imageData.id - Client-generated UUID for the image.
   * @param {string} imageData.projectId - UUID of the project this image belongs to.
   * @param {string} imageData.gcsPath - Full GCS object path of the image.
   * @param {string} [imageData.status='uploaded'] - Initial status of the image.
   * @param {string} [imageData.originalFilename] - Original filename of the image.
   * @param {string} [imageData.contentType] - MIME type of the image.
   * @param {number} [imageData.size] - Size of the image in bytes.
   * @param {string|Date} [imageData.uploaded_at=NOW()] - Timestamp of when the image was uploaded.
   * @param {string} userId - The UUID of the user uploading the image.
   * @returns {Promise<object>} A promise that resolves to the transformed newly created image object.
   * @throws {Error} If the DB pool is not available, required fields are missing, or the query fails (e.g., duplicate ID).
   */
  saveImageMetadata: async (imageData, userId) => {
    if (!pool) { console.error('[ProjectService] DB Pool not available for saveImageMetadata'); throw new Error('DB Connection Error'); }
    const {
      projectId,
      gcsPath,
      status,
      isInvoice,
      analyzed_invoice_date,
      originalFilename,
      size,
      contentType,
      gemini_analysis_json
    } = imageData;

    const id = imageData.id;
    if (!id) {
      console.error('[ProjectService] Image ID is missing in imageData for saveImageMetadata');
      throw new Error('Image ID is required to save image metadata.');
    }

    const query = {
      text: `INSERT INTO invoice_images(
              id, project_id, user_id, gcs_path, status, is_invoice, analyzed_invoice_date, original_filename, size, content_type, gemini_analysis_json
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            RETURNING *`,
      values: [
        id,
        projectId,
        userId,
        gcsPath,
        status || 'uploaded',
        isInvoice || null,
        analyzed_invoice_date || null,
        originalFilename || '',
        size || 0,
        contentType || 'application/octet-stream',
        gemini_analysis_json || null
      ],
    };

    try {
      console.log(`[ProjectService] Saving image metadata for id: ${id}, project ${projectId}, path: ${gcsPath}`);
      const res = await pool.query(query);
      const savedImageDbRow = res.rows[0];

      return _transformDbImageToApiV1Format(savedImageDbRow);
    } catch (err) {
      console.error('[ProjectService] Error saving image metadata:', err.stack);
      throw err;
    }
  },

  /**
   * @async
   * @function deleteImageMetadata
   * @summary Delete image metadata from the database.
   * @description Deletes an image metadata record from `invoice_images` based on `imageId`,
   * `projectId`, and `userId`. Does not delete the file from GCS itself.
   * 
   * @param {string} imageId - The client-generated UUID of the image to delete.
   * @param {string} projectId - The UUID of the project the image belongs to.
   * @param {string} userId - The UUID of the user who owns the image.
   * @returns {Promise<boolean>} A promise that resolves to `true` if deletion was successful (row was deleted),
   *                            `false` otherwise (image not found or not owned by user).
   * @throws {Error} If the DB pool is not available or the query fails.
   */
  deleteImageMetadata: async (imageId, projectId, userId) => {
    if (!pool) { console.error('[ProjectService] DB Pool not available for deleteImageMetadata'); throw new Error('DB Connection Error'); }
    const query = {
      text: 'DELETE FROM invoice_images WHERE id = $1 AND project_id = $2 AND user_id = $3 RETURNING id',
      values: [imageId, projectId, userId],
    };
    
    try {
      console.log(`[ProjectService] Deleting image metadata for image ${imageId}`);
      const res = await pool.query(query);
      if (res.rows.length === 0) {
        // To provide a boolean return that indicates if deletion occurred, 
        // we check if any rows were returned by RETURNING id.
        // If 0 rows, it means no record matched, so deletion didn't happen.
        console.warn(`[ProjectService] Image with id ${imageId} (project: ${projectId}) not found or not owned by user ${userId} for deletion.`);
        return false; 
      }
      return true; // Deletion was successful
    } catch (err) {
      console.error(`[ProjectService] Error deleting image metadata ${imageId}:`, err.stack);
      throw err;
    }
  },

  /**
   * @async
   * @function updateImageOcrResults
   * @summary Update OCR-specific fields for an image.
   * @description Updates fields like `status`, `ocr_text`, `ocr_confidence`, `ocr_text_blocks`,
   * and `error_message` for an image in the `invoice_images` table. Also sets `ocr_processed_at`.
   * Ensures the image belongs to the specified `projectId` and `userId`.
   * 
   * @param {string} projectId - The UUID of the project.
   * @param {string} imageId - The client-generated UUID of the image.
   * @param {object} ocrData - Data containing OCR results to update.
   * @param {string} [ocrData.status] - New status for the image.
   * @param {string} [ocrData.ocr_text] - Extracted OCR text.
   * @param {number} [ocrData.ocr_confidence] - OCR confidence score.
   * @param {object} [ocrData.ocr_text_blocks] - JSON object of text blocks.
   * @param {string} [ocrData.error_message] - Error message if OCR failed.
   * @param {string} userId - The UUID of the user who owns the image.
   * @returns {Promise<object|null>} A promise that resolves to the transformed updated image object, or `null` if not found.
   * @throws {Error} If the DB pool is not available or the query fails.
   */
  updateImageOcrResults: async (projectId, imageId, ocrData, userId) => {
    if (!pool) { console.error('[ProjectService] DB Pool not available for updateImageOcrResults'); throw new Error('DB Connection Error'); }
    const {
      status,
      ocr_text,
      ocr_confidence,
      ocr_text_blocks, 
      error_message
    } = ocrData;

    const columnsToUpdate = [];
    const values = [];
    let placeholderIndex = 1;

    if (status !== undefined) {
      columnsToUpdate.push(`status = $${placeholderIndex++}`);
      values.push(status);
    }
    if (ocr_text !== undefined) {
      columnsToUpdate.push(`ocr_text = $${placeholderIndex++}`);
      values.push(ocr_text);
    }
    if (ocr_confidence !== undefined) {
      columnsToUpdate.push(`ocr_confidence = $${placeholderIndex++}`);
      values.push(ocr_confidence);
    }
    if (ocr_text_blocks !== undefined) {
      columnsToUpdate.push(`ocr_text_blocks = $${placeholderIndex++}`);
      values.push(ocr_text_blocks);
    }
    if (error_message !== undefined) {
      columnsToUpdate.push(`error_message = $${placeholderIndex++}`);
      values.push(error_message);
    }
    
    columnsToUpdate.push(`ocr_processed_at = NOW()`);
    columnsToUpdate.push(`updated_at = NOW()`);

    if (columnsToUpdate.length <= 2) { // Only ocr_processed_at and updated_at would be set
      console.warn(`[ProjectService] No actual OCR data fields to update for image ${imageId}. Only timestamps.`);
      // To be consistent, we should still update the timestamps and return the updated record.
      // Or, if no data fields change, just return current data to avoid unnecessary DB write.
      // For now, let it proceed to update timestamps.
    }

    values.push(imageId);
    values.push(projectId);
    values.push(userId);

    const query = {
      text: `UPDATE invoice_images SET ${columnsToUpdate.join(', ')} 
             WHERE id = $${placeholderIndex++} AND project_id = $${placeholderIndex++} AND user_id = $${placeholderIndex}
             RETURNING *`,
      values: values,
    };

    try {
      console.log(`[ProjectService] Updating image OCR results for image ${imageId}`);
      const res = await pool.query(query);
      if (res.rows.length === 0) {
        console.warn(`[ProjectService] Image with id ${imageId} (project: ${projectId}) not found or not owned by user ${userId} for OCR update.`);
        return null;
      }
      return _transformDbImageToApiV1Format(res.rows[0]);
    } catch (err) {
      console.error(`[ProjectService] Error updating OCR results for image ${imageId}:`, err.stack);
      throw err;
    }
  },

  /**
   * @async
   * @function updateImageMetadata
   * @summary Update various metadata fields for an existing image.
   * @description This is a general-purpose function to update multiple fields of an image record
   * in the `invoice_images` table. It dynamically builds the SET clause based on the `imageData` provided.
   * It can update fields related to OCR, AI analysis, status, or any other mutable field in the `invoice_images` table.
   * The `updated_at` field is always set to the current timestamp.
   * Ensures the image belongs to the `userId` and, if `imageData.projectId` is supplied, also to that project.
   * 
   * @param {string} imageId - The client-generated UUID of the image to update.
   * @param {object} imageData - An object containing the fields to update. Keys should match column names 
   *                             (e.g., `status`, `is_invoice`, `gemini_analysis_json`, `analyzed_invoice_date`, 
   *                             `invoice_sum`, `invoice_currency`, `invoice_taxes`, `ocr_text`, `error_message`).
   *                             It can optionally include `projectId` for an additional check.
   * @param {string} userId - The UUID of the user who owns the image.
   * @returns {Promise<object|null>} A promise that resolves to the transformed updated image object if successful,
   *                                  or `null` if the image was not found or not owned by the user.
   * @throws {Error} If no updatable fields are provided (beyond `projectId`), if the DB pool is unavailable, or if the query fails.
   */
  updateImageMetadata: async (imageId, imageData, userId) => {
    if (!pool) { console.error('[ProjectService] DB Pool not available for updateImageMetadata'); throw new Error('DB Connection Error'); }

    const { projectId, ...fieldsToUpdate } = imageData; // Separate projectId if present

    const columnsToUpdate = [];
    const values = [];
    let placeholderIndex = 1;

    // Dynamically build the SET part of the query
    for (const key in fieldsToUpdate) {
      if (Object.prototype.hasOwnProperty.call(fieldsToUpdate, key) && fieldsToUpdate[key] !== undefined) {
        // Ensure key is a valid column name (basic protection, ideally use a whitelist)
        // For now, we assume keys match DB columns like: status, is_invoice, gemini_analysis_json, etc.
        columnsToUpdate.push(`${key} = $${placeholderIndex++}`);
        values.push(fieldsToUpdate[key]);
      }
    }

    if (columnsToUpdate.length === 0) {
      console.warn(`[ProjectService] No fields provided to update for image ${imageId}.`);
      // Fetch and return current image data if no change, or could throw error.
      // For consistency with PATCH, if no actual data fields to change, we might just return current state.
      // However, the calling route usually ensures there is something to update.
      // For now, let's throw, as this shouldn't typically be called with no fields.
      throw new Error('No updatable fields provided for image metadata.');
    }

    columnsToUpdate.push(`updated_at = NOW()`);

    // Base WHERE clause for user and image ID
    let whereClause = `id = $${placeholderIndex++} AND user_id = $${placeholderIndex++}`;
    values.push(imageId);
    values.push(userId);

    // Add projectId to WHERE clause if it was provided in imageData
    if (projectId) {
      whereClause += ` AND project_id = $${placeholderIndex++}`;
      values.push(projectId);
    }

    const query = {
      text: `UPDATE invoice_images SET ${columnsToUpdate.join(', ')} 
             WHERE ${whereClause}
             RETURNING *`,
      values: values,
    };

    try {
      console.log(`[ProjectService] Updating image metadata for image ${imageId} (user: ${userId}) with data:`, fieldsToUpdate);
      const res = await pool.query(query);
      if (res.rows.length === 0) {
        let notFoundMessage = `Image with id ${imageId} not found or not owned by user ${userId}`;
        if(projectId) notFoundMessage += ` (for project ${projectId})`;
        console.warn(`[ProjectService] ${notFoundMessage} during metadata update.`);
        return null; // Or throw an error: new Error(notFoundMessage);
      }
      return _transformDbImageToApiV1Format(res.rows[0]);
    } catch (err) {
      console.error(`[ProjectService] Error updating image metadata for ${imageId}:`, err.stack);
      throw err;
    }
  }
};

module.exports = projectService;

// Ensure all methods check for pool availability if it might be undefined at module load time.
// A more robust approach might involve a central service initialization that ensures pool is ready before services are used. 