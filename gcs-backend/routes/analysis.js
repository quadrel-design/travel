console.log('[ANALYSIS.JS MODULE] File loaded by Node.js');

/**
 * Analysis Routes.
 * Handles invoice text analysis using Gemini AI.
 */

const express = require('express');
const router = express.Router();
const geminiService = require('../services/geminiService');
const firestoreService = require('../services/firestoreService');
// visionService might also need refactoring if it uses Firestore and isn't passed the db instance
// const { detectTextInImage } = require('../services/visionService'); 

module.exports = function(dbInstance) {
  if (!dbInstance) {
    const errorMessage = "analysisRoutes: CRITICAL ERROR - Firestore db instance was not provided!";
    console.error(errorMessage);
    throw new Error(errorMessage);
  }
  const firestoreServiceInstance = require('../services/firestoreService')(dbInstance);

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
    console.log('[ANALYSIS.JS] Full req.body:', JSON.stringify(req.body)); // Log the full body
    console.log('[ANALYSIS.JS] req.body.ocrText raw:', req.body.ocrText); // Log raw ocrText
    console.log('[ANALYSIS.JS] typeof req.body.ocrText:', typeof req.body.ocrText); // Log its type
    if (req.body.ocrText) {
      console.log('[ANALYSIS.JS] req.body.ocrText length:', req.body.ocrText.length); // Log its length
    }

    const { projectId, invoiceId, imageId, ocrText, userId } = req.body;
    if (!projectId || !invoiceId || !imageId || !userId) {
      return res.status(400).json({ error: 'projectId, invoiceId, imageId, and userId are required' });
    }
    console.log(`[ANALYSIS ROUTE] Received /analyze-invoice for imageId: ${imageId}, userId: ${userId}`);
    console.log(`[ANALYSIS ROUTE] ocrText received in request body:`, ocrText);
    console.log(`[ANALYSIS ROUTE] Full request body for /analyze-invoice:`, req.body);

    try {
      await firestoreServiceInstance.setInvoiceImageStatus(userId, projectId, invoiceId, imageId, 'analysis_running');

      const analysisResult = await geminiService.analyzeDetectedText(ocrText);
      console.log(`[ANALYSIS ROUTE] analysisResult for ${imageId}:`, analysisResult);

      let finalStatus = "analysis_failed";
      if (analysisResult.success && analysisResult.status === "Invoice") {
        finalStatus = "analysis_complete";
      }
      const updateData = {
        status: finalStatus,
        isInvoice: analysisResult.isInvoice,
        lastProcessedAt: new Date(),
        ocrText: ocrText // Persist the original OCR text that was analyzed
      };
      if (analysisResult.success && analysisResult.invoiceAnalysis) {
        const ia = analysisResult.invoiceAnalysis;
        updateData.totalAmount = ia.totalAmount;
        updateData.currency = ia.currency;
        updateData.merchantName = ia.merchantName;
        updateData.merchantLocation = ia.location;
        updateData.invoiceDate = ia.date;
      }
      await firestoreServiceInstance.updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, updateData);

      // Firestore update successful
      console.log(`Firestore update successful for imageId: ${imageId}`);

      // Add this log:
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
      try {
        await firestoreServiceInstance.setInvoiceImageStatus(userId, projectId, invoiceId, imageId, 'analysis_failed');
        await firestoreServiceInstance.updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, {
          status: 'analysis_failed',
          lastProcessedAt: new Date(),
          ocrText: ocrText, // Persist the original OCR text
          errorMessage: error.message || 'Analysis failed in main catch'
        });
      } catch (serviceError) {
        console.error(`[ANALYSIS ROUTE] Firestore update FAILED in main catch for imageId ${imageId}:`, serviceError.message, serviceError.stack);
      }
      res.status(500).json({ success: false, error: error.message || 'Analysis failed overall' });
    }
  });

  return router;
}; 