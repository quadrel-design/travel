const express = require('express');
const router = express.Router();
const { analyzeDetectedText } = require('../services/geminiService');
const { updateInvoiceImageFirestore } = require('../services/firestoreService');

router.post('/analyze-invoice', async (req, res) => {
  const { ocrText, projectId, invoiceId, imageId, userId } = req.body;
  if (!ocrText || !projectId || !invoiceId || !imageId || !userId) {
    return res.status(400).json({ error: 'ocrText, projectId, invoiceId, imageId, and userId are required' });
  }

  try {
    // Optionally: update status to 'analysis_running' in Firestore
    await updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, { status: 'analysis_running' });

    const analysisResult = await analyzeDetectedText(ocrText);

    // Prepare Firestore update
    let finalStatus = "analysis_failed";
    if (analysisResult.success && analysisResult.status === "Invoice") {
      finalStatus = "analysis_complete";
    }
    const updateData = {
      status: finalStatus,
      isInvoice: analysisResult.isInvoice,
      lastProcessedAt: new Date(),
      ocrText
    };
    if (analysisResult.success && analysisResult.invoiceAnalysis) {
      const ia = analysisResult.invoiceAnalysis;
      updateData.totalAmount = ia.totalAmount;
      updateData.currency = ia.currency;
      updateData.merchantName = ia.merchantName;
      updateData.merchantLocation = ia.location;
      updateData.invoiceDate = ia.date;
      // Optionally: write analysis to a subcollection
      // (implement if needed)
    }
    await updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, updateData);

    res.json(analysisResult);
  } catch (error) {
    await updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, {
      status: 'analysis_failed',
      lastProcessedAt: new Date(),
      ocrText,
      errorMessage: error.message || 'Analysis failed'
    });
    res.status(500).json({ error: error.message || 'Analysis failed' });
  }
});

module.exports = router; 