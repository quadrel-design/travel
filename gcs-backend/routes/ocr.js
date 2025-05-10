const express = require('express');
const router = express.Router();
const axios = require('axios');
const { updateInvoiceImageFirestore, setInvoiceImageStatus } = require('../services/firestoreService');
const { detectTextInImage } = require('../services/visionService');

router.post('/ocr-invoice', async (req, res) => {
  const { imageUrl, imageData, projectId, invoiceId, imageId, userId } = req.body;
  if (!projectId || !invoiceId || !imageId || !userId) {
    return res.status(400).json({ error: 'projectId, invoiceId, imageId, and userId are required' });
  }
  if (!imageUrl && !imageData) {
    return res.status(400).json({ error: 'Must provide either imageUrl or imageData' });
  }

  try {
    await setInvoiceImageStatus(userId, projectId, invoiceId, imageId, 'ocrInProgress');
    let detectResult = null;

    if (imageData) {
      return res.status(400).json({ error: 'imageData not yet supported in Cloud Run version' });
    } else {
      let retryCount = 0;
      const maxRetries = 2;
      let lastError = null;
      while (retryCount <= maxRetries) {
        try {
          const response = await axios.get(imageUrl, { responseType: 'arraybuffer', timeout: 15000 });
          const imageBuffer = Buffer.isBuffer(response.data) ? response.data : Buffer.from(response.data);
          detectResult = await detectTextInImage(imageUrl, imageBuffer);
          break;
        } catch (err) {
          lastError = err;
          if (retryCount === maxRetries) break;
          await new Promise(resolve => setTimeout(resolve, Math.pow(2, retryCount) * 1000));
          retryCount++;
        }
      }
      if (!detectResult && lastError) throw lastError;
    }

    if (detectResult.success) {
      await setInvoiceImageStatus(userId, projectId, invoiceId, imageId, detectResult.extractedText ? 'ocrFinished' : 'ocrNoText');
      const updateData = {
        confidence: detectResult.confidence || 0,
        textBlocks: detectResult.textBlocks || [],
        lastProcessedAt: new Date(),
        updatedAt: new Date(),
        ocrText: detectResult.extractedText ?? ''
      };
      if (detectResult.error) updateData.errorMessage = detectResult.error;
      await updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, updateData);
    } else {
      await setInvoiceImageStatus(userId, projectId, invoiceId, imageId, 'ocrError');
      const updateData = {
        ocrText: '',
        lastProcessedAt: new Date(),
        updatedAt: new Date(),
        errorMessage: detectResult.error || 'OCR process failed'
      };
      await updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, updateData);
    }

    res.json(detectResult);
  } catch (error) {
    await setInvoiceImageStatus(userId, projectId, invoiceId, imageId, 'ocrError');
    await updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, {
      ocrText: '',
      lastProcessedAt: new Date(),
      updatedAt: new Date(),
      errorMessage: error.message || 'OCR process failed'
    });
    res.status(500).json({ error: error.message || 'OCR process failed' });
  }
});

module.exports = router; 