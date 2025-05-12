/**
 * OCR Routes.
 * Handles OCR processing for invoice images.
 */

const express = require('express');
const router = express.Router();
const axios = require('axios');
const { detectTextInImage } = require('../services/visionService');

module.exports = function(firestoreDbInstance, postgresService) {
  if (!firestoreDbInstance) {
    const errorMessage = "ocrRoutes: CRITICAL ERROR - Firestore db instance was not provided!";
    console.error(errorMessage);
    throw new Error(errorMessage);
  }
  const firestoreService = require('../services/firestoreService')(firestoreDbInstance);

  if (!postgresService) {
    console.warn('ocrRoutes: WARNING - postgresService was not provided. OCR routes will operate on Firestore only.');
  }

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
      // ***** BEGIN POSTGRESQL INITIAL RECORD INTEGRATION *****
      if (postgresService) {
        try {
          const initialImageData = {
            id: imageId,
            invoice_id: invoiceId,
            user_id: userId,
            project_id: projectId,
            gcs_path: imageUrl, // Tentative: using imageUrl. Review if this is the correct GCS object path.
            status: 'pending_ocr',
          };
          await postgresService.addInitialInvoiceImage(initialImageData);
          console.log(`[OCR ROUTE] Initial invoice image record created/verified in PostgreSQL for imageId: ${imageId}`);
        } catch (pgError) {
          console.error(`[OCR ROUTE] Error creating/verifying initial PostgreSQL record for imageId: ${imageId}. Continuing with Firestore.`, pgError);
        }
      } else {
        console.warn('[OCR ROUTE] postgresService not available, skipping PostgreSQL initial record creation.');
      }
      // ***** END POSTGRESQL INITIAL RECORD INTEGRATION *****

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
            const response = await axios.get(imageUrl, { responseType: 'arraybuffer', timeout: 15000 });
            const imageBuffer = Buffer.isBuffer(response.data) ? response.data : Buffer.from(response.data);
            detectResult = await detectTextInImage(imageUrl, imageBuffer);
            break;
          } catch (err) {
            if (err.response) {
              let responseData = '[binary or empty]';
              try {
                if (typeof err.response.data === 'string') responseData = err.response.data;
                else if (Buffer.isBuffer(err.response.data)) {
                  const utf8 = err.response.data.toString('utf8');
                  responseData = /[^\x00-\x7F]/.test(utf8) ? err.response.data.toString('hex') : utf8;
                }
              } catch (e) { /* ignore */ }
              console.error('[OCR] Error downloading image:', { status: err.response.status, headers: err.response.headers, data: responseData });
            } else console.error('[OCR] Error downloading image:', err.message);
            lastError = err;
            if (retryCount === maxRetries) break;
            await new Promise(resolve => setTimeout(resolve, Math.pow(2, retryCount) * 1000));
            retryCount++;
          }
        }
        if (!detectResult && lastError) throw lastError;
        if (!detectResult) throw new Error('Image detection failed without specific error.');
      }

      const firestoreTimestamp = new Date();
      if (detectResult.success) {
        const newStatus = detectResult.extractedText ? 'ocrFinished' : 'ocrNoText';
        await firestoreService.setInvoiceImageStatus(userId, projectId, invoiceId, imageId, newStatus);
        const firestoreUpdateData = {
          confidence: detectResult.confidence || 0,
          textBlocks: detectResult.textBlocks || [],
          lastProcessedAt: firestoreTimestamp,
          updatedAt: firestoreTimestamp,
          ocrText: detectResult.extractedText ?? '',
          errorMessage: detectResult.error || null
        };
        await firestoreService.updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, firestoreUpdateData);

        if (postgresService) {
          try {
            const pgOcrData = {
              ocr_text: detectResult.extractedText ?? '',
              ocr_confidence: detectResult.confidence || 0,
              ocr_text_blocks: detectResult.textBlocks || [],
              status: newStatus,
              ocr_processed_at: firestoreTimestamp,
              error_message: detectResult.error || null
            };
            await postgresService.updateInvoiceImageWithOcrData(imageId, pgOcrData);
            console.log(`[OCR ROUTE] OCR data success updated in PostgreSQL for imageId: ${imageId}`);
          } catch (pgErr) {
            console.error(`[OCR ROUTE] Error updating PostgreSQL with OCR success data for imageId: ${imageId}.`, pgErr);
          }
        }
      } else {
        await firestoreService.setInvoiceImageStatus(userId, projectId, invoiceId, imageId, 'ocrError');
        const firestoreUpdateData = {
          ocrText: '',
          lastProcessedAt: firestoreTimestamp,
          updatedAt: firestoreTimestamp,
          errorMessage: detectResult.error || 'OCR process failed or no text found'
        };
        await firestoreService.updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, firestoreUpdateData);

        if (postgresService) {
          try {
            const pgOcrData = {
              ocr_text: '',
              status: 'ocrError',
              ocr_processed_at: firestoreTimestamp,
              error_message: detectResult.error || 'OCR process failed or no text found'
            };
            await postgresService.updateInvoiceImageWithOcrData(imageId, pgOcrData);
            console.log(`[OCR ROUTE] OCR failure/no text data updated in PostgreSQL for imageId: ${imageId}`);
          } catch (pgErr) {
            console.error(`[OCR ROUTE] Error updating PostgreSQL with OCR failure/no text data for imageId: ${imageId}.`, pgErr);
          }
        }
      }
      res.json(detectResult);
    } catch (error) {
      console.error(`[OCR ROUTE CATCH BLOCK] imageId: ${imageId}, Error: ${error.message}, GOOGLE_CLOUD_PROJECT: '${process.env.GOOGLE_CLOUD_PROJECT}'`, error.stack);
      const errorTimestamp = new Date();
      try {
        await firestoreService.setInvoiceImageStatus(userId, projectId, invoiceId, imageId, 'ocrError');
        await firestoreService.updateInvoiceImageFirestore(userId, projectId, invoiceId, imageId, {
          ocrText: '',
          lastProcessedAt: errorTimestamp,
          updatedAt: errorTimestamp,
          errorMessage: error.message || 'OCR process failed in main catch'
        });

        if (postgresService) {
          try {
            const pgOcrData = {
              status: 'ocrError',
              ocr_processed_at: errorTimestamp,
              error_message: error.message || 'OCR process failed in main catch'
            };
            await postgresService.updateInvoiceImageWithOcrData(imageId, pgOcrData);
            console.log(`[OCR ROUTE] OCR error data updated in PostgreSQL (catch block) for imageId: ${imageId}`);
          } catch (pgErr) {
            console.error(`[OCR ROUTE] Error updating PostgreSQL with OCR error data (catch block) for imageId: ${imageId}.`, pgErr);
          }
        }
      } catch (serviceError) {
        console.error(`[OCR ROUTE] Firestore update FAILED in main catch for imageId ${imageId}:`, serviceError.message, serviceError.stack);
      }
      res.status(500).json({ success: false, error: error.message || 'OCR process failed overall' });
    }
  });

  return router;
};