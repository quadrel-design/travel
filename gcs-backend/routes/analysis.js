console.log('[ANALYSIS.JS MODULE] File loaded by Node.js');

/**
 * Analysis Routes.
 * Handles invoice text analysis using Gemini AI.
 */

const express = require('express');
const router = express.Router();
const geminiService = require('../services/geminiService');
// const firestoreService = require('../services/firestoreService'); // This will be initialized from the passed instance
// visionService might also need refactoring if it uses Firestore and isn't passed the db instance
// const { detectTextInImage } = require('../services/visionService'); 

module.exports = function(postgresService) { // MODIFIED: Removed firestoreDbInstance
  // REMOVED Firestore instance check and firestoreServiceInstance initialization
  // if (!firestoreDbInstance) { ... }
  // const firestoreServiceInstance = require('../services/firestoreService')(firestoreDbInstance);

  if (!postgresService) {
    // MODIFIED: Changed warning to an error
    const errorMessage = 'analysisRoutes: CRITICAL ERROR - postgresService was not provided. Analysis routes cannot function.';
    console.error(errorMessage);
    throw new Error(errorMessage);
  }

  /**
   * Analyze detected OCR text for invoice data.
   * @route POST /analyze-invoice
   * @body {string} ocrText
   * @body {string} projectId
   * @body {string} invoiceId
   * @body {string} imageId
   * @body {string} userId
   */
  router.post('/analyze-invoice', async (req, res) => {
    console.log('[ANALYSIS.JS] /analyze-invoice hit');
    const { projectId, invoiceId, imageId, ocrText, userId } = req.body;

    if (!projectId || !invoiceId || !imageId || !userId) {
      return res.status(400).json({ error: 'projectId, invoiceId, imageId, and userId are required' });
    }
    console.log(`[ANALYSIS ROUTE] Received /analyze-invoice for imageId: ${imageId}, userId: ${userId}`);

    try {
      // Also update PostgreSQL status if service is available
      if (postgresService) {
        try {
          await postgresService.updateInvoiceImageWithAnalysisData(imageId, { status: 'analysis_running' });
          console.log(`[ANALYSIS ROUTE] Status set to 'analysis_running' in PostgreSQL for imageId: ${imageId}`);
        } catch (pgErr) {
          console.error(`[ANALYSIS ROUTE] Error setting status to 'analysis_running' in PostgreSQL for imageId: ${imageId}.`, pgErr);
        }
      }

      const analysisResult = await geminiService.analyzeDetectedText(ocrText);
      console.log(`[ANALYSIS ROUTE] analysisResult for ${imageId}:`, analysisResult);

      let finalStatus = "analysis_failed";
      if (analysisResult.success && analysisResult.status === "Invoice") {
        finalStatus = "analysis_complete";
      }
      
      const firestoreTimestamp = new Date();
      // REMOVED: Firestore update data block
      // const firestoreUpdateData = { ... };
      // if (analysisResult.success && analysisResult.invoiceAnalysis) { ... }
      // await firestoreServiceInstance.updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, firestoreUpdateData);

      if (postgresService) {
        try {
          const analysisDataForPg = {
            status: finalStatus,
            is_invoice: analysisResult.isInvoice,
            analysis_processed_at: firestoreTimestamp,
          };
          if (analysisResult.success && analysisResult.invoiceAnalysis) {
            const ia = analysisResult.invoiceAnalysis;
            analysisDataForPg.analyzed_total_amount = ia.totalAmount;
            analysisDataForPg.analyzed_currency = ia.currency;
            analysisDataForPg.analyzed_merchant_name = ia.merchantName;
            analysisDataForPg.analyzed_merchant_location = ia.location;
            analysisDataForPg.analyzed_invoice_date = ia.date ? new Date(ia.date) : null; // Convert to Date for PG
          }
          // If analysis failed but there was an error message from Gemini
          if (!analysisResult.success && analysisResult.message) {
            analysisDataForPg.error_message = analysisResult.message;
          }
          await postgresService.updateInvoiceImageWithAnalysisData(imageId, analysisDataForPg);
          console.log(`[ANALYSIS ROUTE] Analysis data updated in PostgreSQL for imageId: ${imageId}`);
        } catch (pgErr) {
          console.error(`[ANALYSIS ROUTE] Error updating PostgreSQL with analysis data for imageId: ${imageId}.`, pgErr);
        }
      }

      console.log('[ANALYSIS_ROUTE] Data being sent to client:', JSON.stringify({
          success: analysisResult.success,
          message: analysisResult.message || (analysisResult.isInvoice ? 'Analysis successful' : 'Analyzed, not an invoice'),
          isInvoice: analysisResult.isInvoice,
          data: analysisResult.invoiceAnalysis,
          status: analysisResult.status
      }, null, 2));

      res.status(200).json({
        success: analysisResult.success,
        message: analysisResult.message || (analysisResult.isInvoice ? 'Analysis successful' : 'Analyzed, not an invoice'),
        isInvoice: analysisResult.isInvoice,
        data: analysisResult.invoiceAnalysis,
        status: analysisResult.status
      });
    } catch (error) {
      console.error(`[ANALYSIS ROUTE] CATCH BLOCK for imageId ${imageId}. Error:`, error.message, error.stack);
      const errorTimestamp = new Date();
      try {
        // REMOVED: Firestore updates in catch block
        // const firestoreErrorUpdatePayload = { ... };
        // await firestoreServiceInstance.setInvoiceImageStatus(userId, projectId, invoiceId, imageId, 'analysis_failed');
        // await firestoreServiceInstance.updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, firestoreErrorUpdatePayload);

        if (postgresService) {
          try {
            const analysisDataForPg = {
              status: 'analysis_failed',
              analysis_processed_at: errorTimestamp,
              error_message: error.message || 'Analysis failed in main catch'
            };
            await postgresService.updateInvoiceImageWithAnalysisData(imageId, analysisDataForPg);
            console.log(`[ANALYSIS ROUTE] Analysis error data updated in PostgreSQL (catch block) for imageId: ${imageId}`);
          } catch (pgErr) {
            console.error(`[ANALYSIS ROUTE] Error updating PostgreSQL with analysis error data (catch block) for imageId: ${imageId}.`, pgErr);
          }
        }
      } catch (serviceError) {
        // MODIFIED: Changed error message to reflect only potential PG error
        console.error(`[ANALYSIS ROUTE] PostgreSQL update FAILED in main catch for imageId ${imageId}:`, serviceError.message, serviceError.stack);
      }
      res.status(500).json({ success: false, error: error.message || 'Analysis failed overall' });
    }
  });

  return router;
};