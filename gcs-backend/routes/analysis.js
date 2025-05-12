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

module.exports = function(firestoreDbInstance, postgresService) { // Accept both instances
  if (!firestoreDbInstance) {
    const errorMessage = "analysisRoutes: CRITICAL ERROR - Firestore db instance was not provided!";
    console.error(errorMessage);
    throw new Error(errorMessage);
  }
  // Initialize firestoreServiceInstance with the firestoreDbInstance
  const firestoreServiceInstance = require('../services/firestoreService')(firestoreDbInstance);

  if (!postgresService) {
    // Log a warning but allow the route to function with Firestore only for now
    console.warn('analysisRoutes: WARNING - postgresService was not provided. Analysis routes will operate on Firestore only.');
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
      // Update Firestore status
      await firestoreServiceInstance.setInvoiceImageStatus(userId, projectId, invoiceId, imageId, 'analysis_running');
      
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
      const firestoreUpdateData = {
        status: finalStatus,
        isInvoice: analysisResult.isInvoice,
        lastProcessedAt: firestoreTimestamp,
        ocrText: ocrText, // Persist the original OCR text that was analyzed
        updatedAt: firestoreTimestamp, // Add updatedAt for Firestore
      };

      if (analysisResult.success && analysisResult.invoiceAnalysis) {
        const ia = analysisResult.invoiceAnalysis;
        firestoreUpdateData.totalAmount = ia.totalAmount;
        firestoreUpdateData.currency = ia.currency;
        firestoreUpdateData.merchantName = ia.merchantName;
        firestoreUpdateData.merchantLocation = ia.location;
        firestoreUpdateData.invoiceDate = ia.date; // Presumes ia.date is Firestore compatible (e.g. ISO string or Timestamp)
      }
      await firestoreServiceInstance.updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, firestoreUpdateData);

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
        const firestoreErrorUpdatePayload = {
          status: 'analysis_failed',
          lastProcessedAt: errorTimestamp,
          updatedAt: errorTimestamp,
          ocrText: ocrText, 
          errorMessage: error.message || 'Analysis failed in main catch'
        };
        await firestoreServiceInstance.setInvoiceImageStatus(userId, projectId, invoiceId, imageId, 'analysis_failed');
        await firestoreServiceInstance.updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, firestoreErrorUpdatePayload);

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
        console.error(`[ANALYSIS ROUTE] Firestore update FAILED in main catch for imageId ${imageId}:`, serviceError.message, serviceError.stack);
      }
      res.status(500).json({ success: false, error: error.message || 'Analysis failed overall' });
    }
  });

  return router;
};