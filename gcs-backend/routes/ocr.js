/**
 * OCR Routes.
 * Handles OCR processing for invoice images.
 */

const express = require('express');
const router = express.Router();
const axios = require('axios');
const { detectTextInImage } = require('../services/visionService');

module.exports = function(dbInstance) {
  if (!dbInstance) {
    const errorMessage = "ocrRoutes: CRITICAL ERROR - Firestore db instance was not provided!";
    console.error(errorMessage);
    // This route module is unusable without a db instance for its services.
    throw new Error(errorMessage);
  }
  // Initialize firestoreService with the db instance
  const firestoreService = require('../services/firestoreService')(dbInstance);

  /**
   * Perform OCR on an invoice image.
   * @route POST /ocr-invoice
   * @body {string} imageUrl
   * @body {string} imageData
   * @body {string} projectId
   * @body {string} invoiceId
   * @body {string} imageId
   * @body {string} userId
   */
router.post('/ocr-invoice', async (req, res) => {
  const { imageUrl, imageData, projectId, invoiceId, imageId, userId } = req.body;
  if (!projectId || !invoiceId || !imageId || !userId) {
    return res.status(400).json({ error: 'projectId, invoiceId, imageId, and userId are required' });
  }
  if (!imageUrl && !imageData) {
    return res.status(400).json({ error: 'Must provide either imageUrl or imageData' });
  }
    console.log(`[OCR ROUTE ENTRY] imageId: ${imageId}, GOOGLE_CLOUD_PROJECT: '${process.env.GOOGLE_CLOUD_PROJECT}'`);

  try {
      await firestoreService.setInvoiceImageStatus(userId, projectId, invoiceId, imageId, 'ocrInProgress');
      console.log(`[OCR AFTER setInProgress] imageId: ${imageId}, GOOGLE_CLOUD_PROJECT: '${process.env.GOOGLE_CLOUD_PROJECT}'`);
    let detectResult = null;

    if (imageData) {
      return res.status(400).json({ error: 'imageData not yet supported in Cloud Run version' });
    } else {
      let retryCount = 0;
      const maxRetries = 2;
      let lastError = null;
      while (retryCount <= maxRetries) {
        try {
            console.log(`[OCR PRE-DOWNLOAD] imageId: ${imageId}, GOOGLE_CLOUD_PROJECT: '${process.env.GOOGLE_CLOUD_PROJECT}'`);
          const response = await axios.get(imageUrl, { responseType: 'arraybuffer', timeout: 15000 });
            console.log(`[OCR POST-DOWNLOAD] imageId: ${imageId}, GOOGLE_CLOUD_PROJECT: '${process.env.GOOGLE_CLOUD_PROJECT}'`);

          const imageBuffer = Buffer.isBuffer(response.data) ? response.data : Buffer.from(response.data);
            console.log(`[OCR PRE-detectTextInImage] imageId: ${imageId}, GOOGLE_CLOUD_PROJECT: '${process.env.GOOGLE_CLOUD_PROJECT}'`);
          detectResult = await detectTextInImage(imageUrl, imageBuffer);
            console.log(`[OCR POST-detectTextInImage] imageId: ${imageId}, GOOGLE_CLOUD_PROJECT: '${process.env.GOOGLE_CLOUD_PROJECT}'`);
          break;
        } catch (err) {
            if (err.response) {
              let responseData = '[binary or empty]';
              try {
                if (typeof err.response.data === 'string') {
                  responseData = err.response.data;
                } else if (Buffer.isBuffer(err.response.data)) {
                  const utf8 = err.response.data.toString('utf8');
                  responseData = /[^\x00-\x7F]/.test(utf8) ? err.response.data.toString('hex') : utf8;
                }
              } catch (e) {
                // ignore
              }
              console.error('[OCR] Error downloading image:', {
                status: err.response.status,
                headers: err.response.headers,
                data: responseData,
              });
            } else {
              console.error('[OCR] Error downloading image:', err.message);
            }
          lastError = err;
          if (retryCount === maxRetries) break;
          await new Promise(resolve => setTimeout(resolve, Math.pow(2, retryCount) * 1000));
          retryCount++;
        }
      }
        if (!detectResult && lastError) {
          console.error('[OCR ROUTE] No detectResult and lastError exists:', lastError);
          throw lastError;
    }
        if (!detectResult) {
          console.error('[OCR ROUTE] No detectResult and no lastError. Throwing generic error.');
          throw new Error('Image detection failed without specific error.');
        }
      }

      console.log(`[OCR PRE-FIRESTORE-SUCCESS-UPDATE] imageId: ${imageId}, GOOGLE_CLOUD_PROJECT: '${process.env.GOOGLE_CLOUD_PROJECT}'`);
    if (detectResult.success) {
        await firestoreService.setInvoiceImageStatus(userId, projectId, invoiceId, imageId, detectResult.extractedText ? 'ocrFinished' : 'ocrNoText');
      const updateData = {
        confidence: detectResult.confidence || 0,
        textBlocks: detectResult.textBlocks || [],
        lastProcessedAt: new Date(),
        updatedAt: new Date(),
        ocrText: detectResult.extractedText ?? ''
      };
      if (detectResult.error) updateData.errorMessage = detectResult.error;
        await firestoreService.updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, updateData);
    } else {
        await firestoreService.setInvoiceImageStatus(userId, projectId, invoiceId, imageId, 'ocrError');
      const updateData = {
        ocrText: '',
        lastProcessedAt: new Date(),
        updatedAt: new Date(),
          errorMessage: detectResult.error || 'OCR process failed in !detectResult.success'
      };
        await firestoreService.updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, updateData);
    }
      console.log(`[OCR POST-FIRESTORE-SUCCESS-UPDATE] imageId: ${imageId}, GOOGLE_CLOUD_PROJECT: '${process.env.GOOGLE_CLOUD_PROJECT}'`);

    res.json(detectResult);
  } catch (error) {
      console.error(`[OCR ROUTE CATCH BLOCK] imageId: ${imageId}, Error: ${error.message}, GOOGLE_CLOUD_PROJECT: '${process.env.GOOGLE_CLOUD_PROJECT}'`, error.stack);
      try {
        // Attempt to update Firestore even in case of error
        await firestoreService.setInvoiceImageStatus(userId, projectId, invoiceId, imageId, 'ocrError');
        await firestoreService.updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, {
      ocrText: '',
      lastProcessedAt: new Date(),
      updatedAt: new Date(),
          errorMessage: error.message || 'OCR process failed in main catch'
    });
      } catch (serviceError) {
        console.error(`[OCR ROUTE] Firestore update FAILED in main catch for imageId ${imageId}:`, serviceError.message, serviceError.stack);
      }
      res.status(500).json({ success: false, error: error.message || 'OCR process failed overall' });
  }
});

  return router;
}; 