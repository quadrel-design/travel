/**
 * Project Service
 * Provides functions to interact with projects and related data in PostgreSQL.
 */
const pool = require('../config/db'); // Import the pool

// Helper function to transform database row to the API V1 format for an invoice image
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
   * Get all projects for a user
   * @param {string} userId - The user ID
   * @returns {Promise<Array>} List of projects
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
   * Get a project by ID
   * @param {string} projectId - The project ID
   * @param {string} userId - The user ID (for authorization)
   * @returns {Promise<Object>} Project data
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
   * Create a new project
   * @param {Object} projectData - The project data
   * @returns {Promise<Object>} Created project
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
   * Update a project
   * @param {string} projectId - The project ID
   * @param {Object} projectData - The updated project data
   * @param {string} userId - The user ID (for authorization)
   * @returns {Promise<Object>} Updated project
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
   * Delete a project
   * @param {string} projectId - The project ID
   * @param {string} userId - The user ID (for authorization)
   * @returns {Promise<boolean>} Success status
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
   * Get all images for a project
   * @param {string} projectId - The project ID
   * @param {string} userId - The user ID (for authorization)
   * @returns {Promise<Array>} List of invoice images
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
   * Get an invoice image by ID
   * @param {string} projectId - The project ID
   * @param {string} imageId - The image ID
   * @param {string} userId - The user ID (for authorization)
   * @returns {Promise<Object>} Image data
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
   * Save image metadata to database
   * @param {Object} imageData - Image metadata
   * @param {string} userId - The user ID
   * @returns {Promise<Object>} Saved image metadata
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
   * Update image metadata in the database
   * @param {string} imageId - The image ID
   * @param {Object} imageData - Updated image metadata
   * @param {string} userId - The user ID for authorization
   * @returns {Promise<Object>} Updated image metadata
   */
  updateImageMetadata: async (imageId, imageData, userId) => {
    if (!pool) { console.error('[ProjectService] DB Pool not available for updateImageMetadata'); throw new Error('DB Connection Error'); }
    const {
      status,
      is_invoice,
      analyzed_invoice_date,
      gemini_analysis_json,
      ocr_text,
      ocr_confidence,
      ocr_text_blocks,
      ocr_processed_at,
      analysis_processed_at,
      invoice_sum,
      invoice_currency,
      invoice_taxes,
      invoice_location,
      invoice_category,
      invoice_taxonomy,
      error_message
    } = imageData;

    const columnsToUpdate = [];
    const values = [];
    let placeholderIndex = 1;

    if (status !== undefined) {
      columnsToUpdate.push(`status = $${placeholderIndex++}`);
      values.push(status);
    }
    if (is_invoice !== undefined) {
      columnsToUpdate.push(`is_invoice = $${placeholderIndex++}`);
      values.push(is_invoice);
    }
    if (analyzed_invoice_date !== undefined) {
      columnsToUpdate.push(`analyzed_invoice_date = $${placeholderIndex++}`);
      values.push(analyzed_invoice_date);
    }
    if (gemini_analysis_json !== undefined) {
      columnsToUpdate.push(`gemini_analysis_json = $${placeholderIndex++}`);
      values.push(gemini_analysis_json);
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
    if (ocr_processed_at !== undefined) {
      columnsToUpdate.push(`ocr_processed_at = $${placeholderIndex++}`);
      values.push(ocr_processed_at);
    }
    if (analysis_processed_at !== undefined) {
      columnsToUpdate.push(`analysis_processed_at = $${placeholderIndex++}`);
      values.push(analysis_processed_at);
    }
    if (invoice_sum !== undefined) {
      columnsToUpdate.push(`invoice_sum = $${placeholderIndex++}`);
      values.push(invoice_sum);
    }
    if (invoice_currency !== undefined) {
      columnsToUpdate.push(`invoice_currency = $${placeholderIndex++}`);
      values.push(invoice_currency);
    }
    if (invoice_taxes !== undefined) {
      columnsToUpdate.push(`invoice_taxes = $${placeholderIndex++}`);
      values.push(invoice_taxes);
    }
    if (invoice_location !== undefined) {
      columnsToUpdate.push(`invoice_location = $${placeholderIndex++}`);
      values.push(invoice_location);
    }
    if (invoice_category !== undefined) {
      columnsToUpdate.push(`invoice_category = $${placeholderIndex++}`);
      values.push(invoice_category);
    }
    if (invoice_taxonomy !== undefined) {
      columnsToUpdate.push(`invoice_taxonomy = $${placeholderIndex++}`);
      values.push(invoice_taxonomy);
    }
    if (error_message !== undefined) {
      columnsToUpdate.push(`error_message = $${placeholderIndex++}`);
      values.push(error_message);
    }

    columnsToUpdate.push(`updated_at = NOW()`);

    if (columnsToUpdate.length <= 1) { // Only updated_at or no fields
      console.warn(`[ProjectService] No fields to update for image ${imageId}. Or only updated_at.`);
      // Potentially fetch and return current image data if no actual change
      const currentImage = await projectService.getInvoiceImageById(imageData.projectId, imageId, userId); // Assuming projectId is in imageData
      if (!currentImage) throw new Error ('Image not found during no-op update attempt');
      return currentImage;
    }

    values.push(imageId);
    values.push(userId);

    const query = {
      text: `UPDATE invoice_images SET ${columnsToUpdate.join(', ')} 
             WHERE id = $${placeholderIndex++} AND user_id = $${placeholderIndex}
             RETURNING *`,
      values: values,
    };

    try {
      console.log(`[ProjectService] Updating image metadata for image ${imageId}`);
      const res = await pool.query(query);
      if (res.rows.length === 0) {
        throw new Error(`Image with id ${imageId} not found or not owned by user ${userId}`);
      }
      const updatedImageDbRow = res.rows[0];
      // Transform data to match expected client format
      return _transformDbImageToApiV1Format(updatedImageDbRow);
    } catch (err) {
      console.error(`[ProjectService] Error updating image metadata for ${imageId}:`, err.stack);
      throw err;
    }
  },

  /**
   * Delete an image metadata entry from the database
   * @param {string} imageId - The image ID
   * @param {string} projectId - The project ID for verification
   * @param {string} userId - The user ID for authorization
   * @returns {Promise<boolean>} Success status
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
        throw new Error(`Image with id ${imageId} (project: ${projectId}) not found or not owned by user ${userId}`);
      }
      return true;
    } catch (err) {
      console.error(`[ProjectService] Error deleting image metadata ${imageId}:`, err.stack);
      throw err;
    }
  }
  // ... (add other project-related functions as needed)
};

module.exports = projectService;

// Ensure all methods check for pool availability if it might be undefined at module load time.
// A more robust approach might involve a central service initialization that ensures pool is ready before services are used. 