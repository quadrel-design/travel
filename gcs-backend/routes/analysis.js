console.log('[ANALYSIS.JS MODULE] File loaded by Node.js');

/**
 * @fileoverview AI Analysis Routes.
 * Handles API endpoints for analyzing extracted OCR text using Google's Gemini AI.
 * Its primary purpose is to determine if the text is from an invoice/receipt and
 * extract structured data (total amount, date, merchant, etc.).
 * Uses `geminiService` for AI interaction and `projectService` for DB updates.
 * @module routes/analysis
 */

const express = require('express');
const router = express.Router();
const geminiService = require('../services/geminiService');
const projectService = require('../services/projectService'); // Using projectService for PostgreSQL interactions
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
    console.error('[Routes/Analysis][AuthMiddleware] Firebase Admin SDK not initialized. Cannot authenticate.');
    return res.status(500).json({ error: 'Authentication service not configured.' });
  }
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized: No token provided' });
    }

    const token = authHeader.split(' ')[1];
    const decodedToken = await firebaseAdmin.auth().verifyIdToken(token);
    
    req.user = { // Attach user to request object
      id: decodedToken.uid,
      email: decodedToken.email
    };
    
    next();
  } catch (error) {
    console.error('[Routes/Analysis] Error authenticating user:', error);
    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({ error: 'Unauthorized: Token expired', code: 'TOKEN_EXPIRED' });
    }
    if (error.code === 'auth/argument-error') {
        console.error('[Routes/Analysis][AuthMiddleware] Firebase ID token verification failed.');
    }
    return res.status(401).json({ error: 'Unauthorized: Invalid token' });
  }
};

// Apply authentication middleware to all routes in this router
router.use(authenticateUser);

if (!projectService) {
  const errorMessage = '[Routes/Analysis] CRITICAL ERROR - projectService was not imported correctly or is unavailable. Analysis routes cannot function.';
  console.error(errorMessage);
  // Throw an error during app startup if this critical dependency is missing.
  throw new Error(errorMessage); 
}

/**
 * @route POST /analyze-invoice
 * @summary Analyzes OCR text of an image using Gemini AI to extract invoice data.
 * @description This endpoint takes text previously extracted by OCR, sends it to the Gemini AI service
 * for analysis, and then stores the structured analysis results (or errors) in the database,
 * updating the corresponding image record. It first sets the image status to `analysis_running`.
 * After Gemini processing, it updates the status to `analysis_complete`, `analysis_not_invoice`,
 * or `analysis_failed`, and populates fields like `is_invoice`, `gemini_analysis_json`,
 * `analyzed_invoice_date`, `invoice_sum`, etc., in the `invoice_images` table.
 * It includes a robust `ensureNumeric` helper to parse monetary values from Gemini's output.
 *
 * @body {string} ocrText - The full text extracted from an image by an OCR process.
 * @body {string} projectId - The ID of the project to which the image belongs (for context).
 * @body {string} imageId - The ID of the image record in the `invoice_images` table that is being analyzed.
 *
 * @response {200} OK - Analysis process completed. The `isInvoice` field in the response indicates if Gemini classified it as an invoice.
 *   @example response - 200 - Analysis Successful (Invoice)
 *   {
 *     "success": true,
 *     "message": "Analysis successful",
 *     "isInvoice": true,
 *     "data": {
 *       "totalAmount": 123.45,
 *       "currency": "USD",
 *       "date": "2024-07-15",
 *       "merchantName": "Example Store",
 *       "isInvoice": true
 *     },
 *     "status": "analysis_complete"
 *   }
 *   @example response - 200 - Analysis Successful (Not an Invoice)
 *   {
 *     "success": true,
 *     "message": "Analyzed, not an invoice",
 *     "isInvoice": false,
 *     "data": { ... },
 *     "status": "analysis_not_invoice"
 *   }
 * @response {400} Bad Request - Missing required fields (`ocrText`, `projectId`, `imageId`).
 * @response {500} Internal Server Error - If the AI analysis encounters an unrecoverable error, or if database updates fail.
 *   The image status in the database is updated to `analysis_failed` with an error message.
 */
router.post('/analyze-invoice', async (req, res) => {
  console.log('[Routes/Analysis] /analyze-invoice hit');
  const { projectId, imageId, ocrText } = req.body; 
  const userId = req.user ? req.user.id : null; // Get userId from authenticated user, handle if req.user is undefined

  // Log received values for debugging
  console.log(`[Routes/Analysis] Received for /analyze-invoice - projectId: ${projectId}, imageId: ${imageId}, ocrText present: ${!!ocrText}, userId (from token): ${userId}`);
  console.log('[Routes/Analysis] Full req.body:', JSON.stringify(req.body));

  if (!projectId || !imageId || !ocrText || !userId) {
    console.error(`[Routes/Analysis] Validation failed: projectId=${projectId}, imageId=${imageId}, ocrText=${ocrText ? 'present' : 'absent'}, userId=${userId}`);
    return res.status(400).json({ error: 'projectId, imageId, ocrText, and authenticated userId are required' });
  }
  console.log(`[Routes/Analysis] Received /analyze-invoice for imageId: ${imageId}, userId: ${userId}, projectId: ${projectId}`);

  try {
    // Update PostgreSQL status to analysis_running using projectService
    if (typeof projectService.updateImageMetadata === 'function') { // Verify method exists, removed redundant projectService &&
      try {
        await projectService.updateImageMetadata(imageId, { status: 'analysis_running', analysis_processed_at: new Date() }, userId);
        console.log(`[Routes/Analysis] Status set to 'analysis_running' in PostgreSQL for imageId: ${imageId}`);
      } catch (pgErr) {
        console.error(`[Routes/Analysis] CRITICAL: Failed to set status to 'analysis_running' for imageId: ${imageId}. Aborting analysis.`, pgErr);
        // Re-throw to be caught by the main catch block, which will set status to 'analysis_failed'
        // and return a 500 error to the client.
        throw pgErr; 
      }
    } else {
      console.warn('[Routes/Analysis] projectService.updateImageMetadata is not available. Cannot update status before analysis. This is unexpected if initial checks passed.');
      // This case should ideally not be reached if the startup check for projectService is effective.
      // Consider throwing an error here as well, as it indicates a broken state.
      throw new Error('projectService not available mid-request, cannot update image status.');
    }

    const analysisResult = await geminiService.analyzeDetectedText(ocrText);
    console.log(`[Routes/Analysis] Gemini analysisResult for ${imageId}:`, JSON.stringify(analysisResult, null, 2));

    let finalStatus = analysisResult.success ? (analysisResult.isInvoice ? 'analysis_complete' : 'analysis_not_invoice') : 'analysis_failed';
    const analysisTimestamp = new Date();

    if (typeof projectService.updateImageMetadata === 'function') { // Removed redundant projectService &&
      try {
        const analysisDataForPg = {
          status: finalStatus,
          is_invoice: analysisResult.isInvoice, // from Gemini result
          analysis_processed_at: analysisTimestamp, // Corrected field name if needed
          gemini_analysis_json: analysisResult.invoiceAnalysis || {} // Store the full JSON from Gemini
        };

        // If analysis was successful and provided invoice details, map them
        if (analysisResult.success && analysisResult.invoiceAnalysis) {
          const ia = analysisResult.invoiceAnalysis;
          /**
           * Helper function to parse and clean a string value representing a number.
           * It handles currency symbols, and different decimal/thousand separators (European vs. US).
           * @param {string|number|null|undefined} val - The value to convert to a numeric type.
           * @returns {number|null} The parsed number, or null if parsing is not possible.
           */
          const ensureNumeric = (val) => {
            if (val === null || val === undefined) return null;

            let s = String(val).trim();
            if (s === "") return null;

            // Step 1: Remove common currency symbols (e.g., $, €, £). Add others if needed.
            s = s.replace(/[$\u20AC\u00A3]/g, '');

            // Step 2: Normalize number string for different decimal/thousand separators
            const lastCommaIdx = s.lastIndexOf(',');
            const lastPeriodIdx = s.lastIndexOf('.');

            if (lastCommaIdx !== -1 && (lastPeriodIdx === -1 || lastCommaIdx > lastPeriodIdx)) {
              // Comma is likely decimal separator (e.g., "1.234,50" or "123,45")
              // Remove periods (as they would be thousand separators in this case)
              s = s.replace(/\./g, '');
              // Convert the (first encountered) comma to a period for parseFloat
              s = s.replace(/,/, '.');
            }
            // If not European-style, commas are treated as thousand separators and will be removed in Step 3.
            // Periods are treated as decimal points and will be kept by Step 3.

            // Step 3: Clean the string to keep only digits, the decimal point, and a leading minus sign.
            // This effectively removes any remaining thousand separators (commas) and other non-numeric characters.
            s = s.replace(/[^\d.-]/g, '');

            // After cleaning, if string is empty or just a minus (e.g. "abc" or "$" or "-" became ""), it's not a valid number.
            if (s === "" || s === "-") return null;

            const num = parseFloat(s);
            return isNaN(num) ? null : num;
          };
          analysisDataForPg.analyzed_invoice_date = ia.date ? new Date(ia.date) : null;
          analysisDataForPg.invoice_sum = ensureNumeric(ia.totalAmount);
          analysisDataForPg.invoice_currency = ia.currency || null;
          analysisDataForPg.invoice_taxes = ensureNumeric(ia.taxes); 
          // The fields below might not be directly in your invoice_images table or might be part of gemini_analysis_json
          // For example: merchantName, location, category, taxonomy from ia would be in gemini_analysis_json
        }
        
        if (!analysisResult.success && analysisResult.error) { // Store error message from Gemini if analysis failed
          analysisDataForPg.error_message = String(analysisResult.error).substring(0, 255); // Truncate if too long
        }

        await projectService.updateImageMetadata(imageId, analysisDataForPg, userId);
        console.log(`[Routes/Analysis] Analysis data updated in PostgreSQL for imageId: ${imageId}`);
      } catch (pgErr) {
        console.error(`[Routes/Analysis] CRITICAL: Failed to save final analysis data to PostgreSQL for imageId: ${imageId}.`, pgErr);
        // Re-throw to be caught by the main catch block, which will attempt to set status to 'analysis_failed'
        // and return a 500 error to the client.
        throw pgErr; 
      }
    } else {
      console.warn('[Routes/Analysis] projectService.updateImageMetadata is not available. Cannot save analysis results to DB. This is unexpected.');
      // This indicates a problem, data will be lost. Client will get Gemini result but DB won't be updated.
      // To make this stricter, we should throw an error here as well.
      throw new Error('projectService not available mid-request, cannot save analysis results.');
    }

    console.log('[Routes/Analysis] Data being sent to client for imageId ${imageId}:', JSON.stringify({
        success: analysisResult.success,
        message: analysisResult.message || (analysisResult.isInvoice ? 'Analysis successful' : 'Analyzed, not an invoice'),
        isInvoice: analysisResult.isInvoice,
        data: analysisResult.invoiceAnalysis,
        status: finalStatus
    }, null, 2));

    res.status(200).json({
      success: analysisResult.success,
      message: analysisResult.message || (analysisResult.isInvoice ? 'Analysis successful' : 'Analyzed, not an invoice'),
      isInvoice: analysisResult.isInvoice,
      data: analysisResult.invoiceAnalysis,
      status: finalStatus
    });
  } catch (error) {
    console.error(`[Routes/Analysis] CATCH BLOCK for imageId ${imageId}. Error:`, error.message, error.stack);
    const errorTimestamp = new Date();
    try {
      if (typeof projectService.updateImageMetadata === 'function') { // Removed redundant projectService &&
        const errorDbPayload = {
          status: 'analysis_failed',
          analysis_processed_at: errorTimestamp,
          error_message: String(error.message || 'Analysis failed in main catch').substring(0, 500)
        };
        if (error.analysisResult && error.analysisResult.invoiceAnalysis) {
          errorDbPayload.gemini_analysis_json = error.analysisResult.invoiceAnalysis;
        }
        await projectService.updateImageMetadata(imageId, errorDbPayload, userId);
        console.log(`[Routes/Analysis] Error details (overall catch) updated in DB for imageId: ${imageId}`);
      } else {
        console.warn('[Routes/Analysis] projectService.updateImageMetadata not available in CATCH block. Cannot log error to DB.');
      }
    } catch (serviceError) {
      console.error(`[Routes/Analysis] DB update FAILED in overall catch block for imageId ${imageId}:`, serviceError.message, serviceError.stack);
    }
    res.status(500).json({ success: false, error: error.message || 'Overall analysis process failed' });
  }
});

module.exports = router;