console.log('[ANALYSIS.JS MODULE] File loaded by Node.js');

/**
 * Analysis Routes.
 * Handles invoice text analysis using Gemini AI.
 */

const express = require('express');
const router = express.Router();
const geminiService = require('../services/geminiService');
const projectService = require('../services/projectService'); // Using projectService for PostgreSQL interactions
const firebaseAdmin = require('firebase-admin'); // For authentication

// Middleware to check if user is authenticated (similar to other route files)
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
 * Analyze detected OCR text for invoice data.
 * @route POST /analyze-invoice
 * @body {string} ocrText - Text extracted from OCR
 * @body {string} projectId - Project ID (validation, context)
 * @body {string} imageId - The ID of the image/invoice being analyzed (from invoice_images table)
 * Note: userId is now derived from the authentication token via authenticateUser middleware.
 */
router.post('/analyze-invoice', async (req, res) => {
  console.log('[Routes/Analysis] /analyze-invoice hit');
  // userId is now on req.user.id from authenticateUser middleware
  const { projectId, imageId, ocrText } = req.body; 
  const userId = req.user.id; // Get userId from authenticated user

  // invoiceId from body seems redundant if imageId is the primary key for invoice_images
  // Assuming imageId refers to the id in invoice_images table.
  if (!projectId || !imageId || !ocrText || !userId) {
    return res.status(400).json({ error: 'projectId, imageId, ocrText, and authenticated userId are required' });
  }
  console.log(`[Routes/Analysis] Received /analyze-invoice for imageId: ${imageId}, userId: ${userId}, projectId: ${projectId}`);

  try {
    // Update PostgreSQL status to analysis_running using projectService
    if (projectService && typeof projectService.updateImageMetadata === 'function') { // Verify method exists
      try {
        // Assuming updateImageMetadata can handle updating status and analysis_processed_at
        await projectService.updateImageMetadata(imageId, { status: 'analysis_running' }, userId);
        console.log(`[Routes/Analysis] Status set to 'analysis_running' in PostgreSQL for imageId: ${imageId}`);
      } catch (pgErr) {
        console.error(`[Routes/Analysis] Error setting status to 'analysis_running' in PostgreSQL for imageId: ${imageId}.`, pgErr);
        // Decide if this should be a fatal error for the request
      }
    } else {
      console.warn('[Routes/Analysis] projectService.updateImageMetadata is not available. Cannot update status before analysis.');
    }

    const analysisResult = await geminiService.analyzeDetectedText(ocrText);
    console.log(`[Routes/Analysis] Gemini analysisResult for ${imageId}:`, JSON.stringify(analysisResult, null, 2));

    let finalStatus = analysisResult.success ? (analysisResult.isInvoice ? 'analysis_complete' : 'analysis_not_invoice') : 'analysis_failed';
    const analysisTimestamp = new Date();

    if (projectService && typeof projectService.updateImageMetadata === 'function') {
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
          const ensureNumeric = (val) => {
            if (val === null || val === undefined) return null;
            const num = parseFloat(String(val).replace(/[^\\d.-]/g, '')); // More robust parsing
            return isNaN(num) ? null : num;
          };
          analysisDataForPg.invoice_date = ia.date ? new Date(ia.date) : null;
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
        console.error(`[Routes/Analysis] Error updating PostgreSQL with analysis data for imageId: ${imageId}.`, pgErr);
        // Log this error but still attempt to return Gemini result to client if available
      }
    } else {
      console.warn('[Routes/Analysis] projectService.updateImageMetadata is not available. Cannot save analysis results to DB.');
    }

    console.log('[Routes/Analysis] Data being sent to client for imageId ${imageId}:', JSON.stringify({
        success: analysisResult.success,
        message: analysisResult.message || (analysisResult.isInvoice ? 'Analysis successful' : 'Analyzed, not an invoice'),
        isInvoice: analysisResult.isInvoice,
        data: analysisResult.invoiceAnalysis,
        status: analysisResult.status // This might be Gemini's status (e.g. Invoice, Text) or your finalStatus
    }, null, 2));

    res.status(200).json({
      success: analysisResult.success,
      message: analysisResult.message || (analysisResult.isInvoice ? 'Analysis successful' : 'Analyzed, not an invoice'),
      isInvoice: analysisResult.isInvoice,
      data: analysisResult.invoiceAnalysis,
      status: analysisResult.status
    });
  } catch (error) {
    console.error(`[Routes/Analysis] CATCH BLOCK for imageId ${imageId}. Error:`, error.message, error.stack);
    const errorTimestamp = new Date();
    try {
      if (projectService && typeof projectService.updateImageMetadata === 'function') {
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