/**
 * PostgreSQL Service.
 * Provides functions to interact with the PostgreSQL database.
 */
module.exports = function(pool) {
  if (!pool) {
    const errorMessage = "postgresService: CRITICAL ERROR - PostgreSQL pool was NOT PROVIDED!";
    console.error(errorMessage);
    throw new Error(errorMessage);
  }

  console.log('postgresService: PostgreSQL pool provided and service initialized.');

  return {
    /**
     * Adds an initial record for an invoice image.
     * This should be called when an image is first registered in the system,
     * likely before OCR or analysis processing.
     * @param {object} imageData 
     * @param {string} imageData.id - The imageId (primary key)
     * @param {string} imageData.invoice_id - Foreign key to invoices_metadata
     * @param {string} imageData.user_id - Foreign key to users
     * @param {string} imageData.project_id - Foreign key to projects
     * @param {string} imageData.gcs_path - Path to the image in GCS
     * @param {string} imageData.status - Initial status (e.g., 'uploaded', 'pending_ocr')
     * @param {Date} [imageData.uploaded_at] - Optional: if available, otherwise defaults to now
     * @param {Date} [imageData.created_at] - Optional: if available, otherwise defaults to now
     * @param {Date} [imageData.updated_at] - Optional: if available, otherwise defaults to now
     */
    addInitialInvoiceImage: async (imageData) => {
      const { 
        id, 
        invoice_id, 
        user_id, 
        project_id, 
        gcs_path, 
        status, 
        uploaded_at,
        created_at,
        updated_at 
      } = imageData;

      const now = new Date();

      const query = {
        text: `INSERT INTO invoice_images(
                  id, invoice_id, user_id, project_id, gcs_path, status, 
                  uploaded_at, created_at, updated_at
                ) VALUES($1, $2, $3, $4, $5, $6, $7, $8, $9) 
                ON CONFLICT (id) DO UPDATE SET
                  invoice_id = EXCLUDED.invoice_id,
                  user_id = EXCLUDED.user_id,
                  project_id = EXCLUDED.project_id,
                  gcs_path = EXCLUDED.gcs_path,
                  status = EXCLUDED.status,
                  -- uploaded_at keeps its original value from the first insert
                  -- created_at keeps its original value from the first insert
                  updated_at = NOW()
                RETURNING *`,
        values: [
          id, 
          invoice_id, 
          user_id, 
          project_id, 
          gcs_path, 
          status,
          uploaded_at || now, // Default to now if not provided for INSERT
          created_at || now,  // Default to now if not provided for INSERT
          updated_at || now   // Default to now if not provided for INSERT (for EXCLUDED.updated_at if used, but NOW() is preferred for update)
        ],
      };
      try {
        console.log('[PostgresService] Attempting to add/update initial invoice image (UPSERT):', { id, invoice_id, project_id, status });
        const res = await pool.query(query);
        console.log('[PostgresService] Initial invoice image added/updated in PostgreSQL:', res.rows[0]);
        return res.rows[0];
      } catch (err) {
        console.error('[PostgresService] Error adding/updating initial invoice image to PostgreSQL', err.stack);
        console.error('[PostgresService] Offending query values:', query.values);
        throw err;
      }
    },

    // Example function to add an invoice image (structure only)
    // We'll need to map the parameters to the columns in invoice_images table
    addInvoiceImage: async (imageData) => {
      // const { id, invoice_id, user_id, project_id, gcs_path, status, ...otherData } = imageData;
      // const query = {
      //   text: 'INSERT INTO invoice_images(id, invoice_id, user_id, project_id, gcs_path, status, ...) VALUES($1, $2, $3, $4, $5, $6, ...) RETURNING *',
      //   values: [id, invoice_id, user_id, project_id, gcs_path, status, ...],
      // };
      // try {
      //   const res = await pool.query(query);
      //   console.log('Image added to PostgreSQL:', res.rows[0]);
      //   return res.rows[0];
      // } catch (err) {
      //   console.error('Error adding image to PostgreSQL', err.stack);
      //   throw err;
      // }
      console.log('postgresService.addInvoiceImage called with:', imageData);
      return Promise.resolve({ message: "addInvoiceImage - not implemented" }); // Placeholder
    },

    // Example function to update status (structure only)
    updateInvoiceImageStatus: async (imageId, status, errorMessage = null) => {
      // const query = {
      //   text: 'UPDATE invoice_images SET status = $1, error_message = $2, updated_at = CURRENT_TIMESTAMP WHERE id = $3 RETURNING *',
      //   values: [status, errorMessage, imageId],
      // };
      // try {
      //   const res = await pool.query(query);
      //   if (res.rows.length === 0) {
      //     throw new Error(`Image with id ${imageId} not found in PostgreSQL for status update.`);
      //   }
      //   console.log('Image status updated in PostgreSQL:', res.rows[0]);
      //   return res.rows[0];
      // } catch (err) {
      //   console.error('Error updating image status in PostgreSQL', err.stack);
      //   throw err;
      // }
      console.log('postgresService.updateInvoiceImageStatus called for imageId:', imageId, 'to status:', status);
      return Promise.resolve({ message: "updateInvoiceImageStatus - not implemented" }); // Placeholder
    },

    // Add more functions here for users, projects, invoices_metadata, etc.
    // e.g., saveUser, createProject, getProjectById, createInvoiceMetadata

    // Example: getUserById
    getUserById: async (userId) => {
      // const query = {
      //   text: 'SELECT * FROM users WHERE id = $1',
      //   values: [userId],
      // };
      // try {
      //   const res = await pool.query(query);
      //   return res.rows[0]; // Returns the user or undefined if not found
      // } catch (err) {
      //   console.error('Error fetching user from PostgreSQL', err.stack);
      //   throw err;
      // }
      console.log('postgresService.getUserById called for userId:', userId);
      return Promise.resolve({ message: "getUserById - not implemented" }); // Placeholder
    },

    /**
     * Updates an invoice image record with data from OCR processing.
     * @param {string} imageId - The ID of the image record to update.
     * @param {object} ocrData
     * @param {string} [ocrData.ocr_text] - Extracted text.
     * @param {number} [ocrData.ocr_confidence] - OCR confidence score.
     * @param {object} [ocrData.ocr_text_blocks] - JSON object of text blocks.
     * @param {string} ocrData.status - New status (e.g., 'ocrFinished', 'ocrError').
     * @param {Date} [ocrData.ocr_processed_at] - Timestamp of OCR processing.
     * @param {string} [ocrData.error_message] - Error message if OCR failed.
     */
    updateInvoiceImageWithOcrData: async (imageId, ocrData) => {
      const { 
        ocr_text, 
        ocr_confidence, 
        ocr_text_blocks, 
        status,
        ocr_processed_at,
        error_message 
      } = ocrData;

      const now = new Date();
      const columnsToUpdate = [];
      const values = [];
      let placeholderIndex = 1;

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
      if (status) {
        columnsToUpdate.push(`status = $${placeholderIndex++}`);
        values.push(status);
      }
      columnsToUpdate.push(`ocr_processed_at = $${placeholderIndex++}`);
      values.push(ocr_processed_at || now);
      
      if (error_message !== undefined) {
        columnsToUpdate.push(`error_message = $${placeholderIndex++}`);
        values.push(error_message);
      }
      
      columnsToUpdate.push(`updated_at = $${placeholderIndex++}`);
      values.push(now); // Always update updated_at

      if (columnsToUpdate.length === 0) {
        console.warn('[PostgresService] updateInvoiceImageWithOcrData called with no data to update for imageId:', imageId);
        // Optionally, you could fetch and return the existing record or throw an error.
        // For now, just returning a message.
        return { message: "No fields to update for OCR data." }; 
      }

      values.push(imageId); // Add imageId as the last value for the WHERE clause

      const queryText = `UPDATE invoice_images SET ${columnsToUpdate.join(', ')} WHERE id = $${placeholderIndex} RETURNING *`;
      
      const query = {
        text: queryText,
        values: values,
      };

      try {
        console.log(`[PostgresService] Attempting to update OCR data for imageId: ${imageId} with status: ${status}`);
        const res = await pool.query(query);
        if (res.rows.length === 0) {
          throw new Error(`Image with id ${imageId} not found in PostgreSQL for OCR data update.`);
        }
        console.log('[PostgresService] OCR data updated in PostgreSQL:', res.rows[0]);
        return res.rows[0];
      } catch (err) {
        console.error(`[PostgresService] Error updating OCR data for imageId ${imageId} in PostgreSQL`, err.stack);
        console.error('[PostgresService] Offending query for updateInvoiceImageWithOcrData:', query);
        throw err;
      }
    },

    /**
     * Updates an invoice image record with data from AI analysis processing.
     * @param {string} imageId - The ID of the image record to update.
     * @param {object} analysisData
     * @param {string} analysisData.status - New status (e.g., 'analysis_complete', 'analysis_failed').
     * @param {boolean} [analysisData.is_invoice]
     * @param {number} [analysisData.analyzed_total_amount]
     * @param {string} [analysisData.analyzed_currency]
     * @param {string} [analysisData.analyzed_merchant_name]
     * @param {string} [analysisData.analyzed_merchant_location]
     * @param {Date} [analysisData.analyzed_invoice_date]
     * @param {Date} [analysisData.analysis_processed_at]
     * @param {string} [analysisData.error_message]
     */
    updateInvoiceImageWithAnalysisData: async (imageId, analysisData) => {
      const {
        status,
        is_invoice,
        analyzed_total_amount,
        analyzed_currency,
        analyzed_merchant_name,
        analyzed_merchant_location,
        analyzed_invoice_date,
        analysis_processed_at,
        error_message
      } = analysisData;

      const now = new Date();
      const columnsToUpdate = [];
      const values = [];
      let placeholderIndex = 1;

      if (status) {
        columnsToUpdate.push(`status = $${placeholderIndex++}`);
        values.push(status);
      }
      if (is_invoice !== undefined) {
        columnsToUpdate.push(`is_invoice = $${placeholderIndex++}`);
        values.push(is_invoice);
      }
      if (analyzed_total_amount !== undefined) {
        columnsToUpdate.push(`analyzed_total_amount = $${placeholderIndex++}`);
        values.push(analyzed_total_amount);
      }
      if (analyzed_currency !== undefined) {
        columnsToUpdate.push(`analyzed_currency = $${placeholderIndex++}`);
        values.push(analyzed_currency);
      }
      if (analyzed_merchant_name !== undefined) {
        columnsToUpdate.push(`analyzed_merchant_name = $${placeholderIndex++}`);
        values.push(analyzed_merchant_name);
      }
      if (analyzed_merchant_location !== undefined) {
        columnsToUpdate.push(`analyzed_merchant_location = $${placeholderIndex++}`);
        values.push(analyzed_merchant_location);
      }
      if (analyzed_invoice_date !== undefined) {
        // Ensure date is in YYYY-MM-DD format if it's coming as a string
        // Or handle Date objects appropriately for your pg driver
        columnsToUpdate.push(`analyzed_invoice_date = $${placeholderIndex++}`);
        values.push(analyzed_invoice_date);
      }
      columnsToUpdate.push(`analysis_processed_at = $${placeholderIndex++}`);
      values.push(analysis_processed_at || now);

      if (error_message !== undefined) {
        columnsToUpdate.push(`error_message = $${placeholderIndex++}`);
        values.push(error_message);
      }
      
      columnsToUpdate.push(`updated_at = $${placeholderIndex++}`);
      values.push(now); // Always update updated_at

      if (columnsToUpdate.length === 0) {
        console.warn('[PostgresService] updateInvoiceImageWithAnalysisData called with no data to update for imageId:', imageId);
        return { message: "No fields to update for analysis data." }; 
      }

      values.push(imageId); // Add imageId as the last value for the WHERE clause

      const queryText = `UPDATE invoice_images SET ${columnsToUpdate.join(', ')} WHERE id = $${placeholderIndex} RETURNING *`;
      
      const query = {
        text: queryText,
        values: values,
      };

      try {
        console.log(`[PostgresService] Attempting to update analysis data for imageId: ${imageId} with status: ${status}`);
        const res = await pool.query(query);
        if (res.rows.length === 0) {
          throw new Error(`Image with id ${imageId} not found in PostgreSQL for analysis data update.`);
        }
        console.log('[PostgresService] Analysis data updated in PostgreSQL:', res.rows[0]);
        return res.rows[0];
      } catch (err) {
        console.error(`[PostgresService] Error updating analysis data for imageId ${imageId} in PostgreSQL`, err.stack);
        console.error('[PostgresService] Offending query for updateInvoiceImageWithAnalysisData:', query);
        throw err;
      }
    }

  };
}; 