/**
 * Analysis Routes.
 * Handles invoice text analysis using Gemini AI.
 */

const express = require('express');
const router = express.Router();
const { analyzeDetectedText } = require('../services/geminiService');
// visionService might also need refactoring if it uses Firestore and isn't passed the db instance
// const { detectTextInImage } = require('../services/visionService'); 

module.exports = function(dbInstance) {
  if (!dbInstance) {
    const errorMessage = "analysisRoutes: CRITICAL ERROR - Firestore db instance was not provided!";
    console.error(errorMessage);
    throw new Error(errorMessage);
  }
  const firestoreService = require('../services/firestoreService')(dbInstance);

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
    const { ocrText, projectId, invoiceId, imageId, userId } = req.body;
    if (!projectId || !invoiceId || !imageId || !userId) {
      return res.status(400).json({ error: 'projectId, invoiceId, imageId, and userId are required' });
    }
    console.log(`[ANALYSIS ROUTE] Received /analyze-invoice for imageId: ${imageId}, userId: ${userId}`);

    try {
      await firestoreService.setInvoiceImageStatus(userId, projectId, invoiceId, imageId, 'analysis_running');

      const analysisResult = await analyzeDetectedText(ocrText);
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
      await firestoreService.updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, updateData);

      res.json(analysisResult);
    } catch (error) {
      console.error(`[ANALYSIS ROUTE] CATCH BLOCK for imageId ${imageId}. Error:`, error.message, error.stack);
      try {
        await firestoreService.setInvoiceImageStatus(userId, projectId, invoiceId, imageId, 'analysis_failed');
        await firestoreService.updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, {
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