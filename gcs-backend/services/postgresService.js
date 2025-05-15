/**
 * PostgreSQL Service.
 * Provides functions to interact with the PostgreSQL database.
 */
const pool = require('../config/db'); // Import the shared pool

if (!pool) {
  const errorMessage = "postgresService: CRITICAL ERROR - PostgreSQL pool was NOT imported or is undefined!";
  console.error(errorMessage);
  // This service will be non-functional. Depending on strategy, could throw.
  console.warn('postgresService: Service will be non-functional as the DB pool is unavailable.');
} else {
  console.log('postgresService: DB pool imported and service initialized.');
}

module.exports = {
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
      if (!pool) { 
        console.error('[PostgresService] DB Pool not available for updateInvoiceImageWithOcrData'); 
        throw new Error('DB Connection Error for OCR update'); 
      }
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
     * @param {object} [analysisData.gemini_analysis_json] - Full JSON result from Gemini analysis
     * @param {number} [analysisData.invoice_sum]
     * @param {string} [analysisData.invoice_location]
     * @param {string} [analysisData.invoice_currency]
     * @param {number} [analysisData.invoice_taxes]
     * @param {string} [analysisData.invoice_taxonomy]
     * @param {string} [analysisData.invoice_category]
     */
    updateInvoiceImageWithAnalysisData: async (imageId, analysisData) => {
      if (!pool) { 
        console.error('[PostgresService] DB Pool not available for updateInvoiceImageWithAnalysisData'); 
        throw new Error('DB Connection Error for Analysis update'); 
      }
      const {
        status,
        is_invoice,
        analyzed_total_amount,
        analyzed_currency,
        analyzed_merchant_name,
        analyzed_merchant_location,
        analyzed_invoice_date,
        analysis_processed_at,
        error_message,
        gemini_analysis_json,
        invoice_sum,
        invoice_location,
        invoice_currency,
        invoice_taxes,
        invoice_taxonomy,
        invoice_category
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
        columnsToUpdate.push(`analyzed_invoice_date = $${placeholderIndex++}`);
        values.push(analyzed_invoice_date);
      }
      if (gemini_analysis_json !== undefined) {
        columnsToUpdate.push(`gemini_analysis_json = $${placeholderIndex++}`);
        values.push(gemini_analysis_json);
      }
      if (invoice_sum !== undefined) {
        columnsToUpdate.push(`invoice_sum = $${placeholderIndex++}`);
        values.push(invoice_sum);
      }
      if (invoice_location !== undefined) {
        columnsToUpdate.push(`invoice_location = $${placeholderIndex++}`);
        values.push(invoice_location);
      }
      if (invoice_currency !== undefined) {
        columnsToUpdate.push(`invoice_currency = $${placeholderIndex++}`);
        values.push(invoice_currency);
      }
      if (invoice_taxes !== undefined) {
        columnsToUpdate.push(`invoice_taxes = $${placeholderIndex++}`);
        values.push(invoice_taxes);
      }
      if (invoice_taxonomy !== undefined) {
        columnsToUpdate.push(`invoice_taxonomy = $${placeholderIndex++}`);
        values.push(invoice_taxonomy);
      }
      if (invoice_category !== undefined) {
        columnsToUpdate.push(`invoice_category = $${placeholderIndex++}`);
        values.push(invoice_category);
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