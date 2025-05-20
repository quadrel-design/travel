/**
 * @fileoverview Google Cloud Vision API Service Module.
 * This module provides functionality to interact with Google Cloud Vision API, specifically for
 * performing text detection (OCR - Optical Character Recognition) on images.
 * It initializes the `ImageAnnotatorClient` which uses Application Default Credentials (ADC)
 * for authentication, typically configured via the `GOOGLE_APPLICATION_CREDENTIALS` environment variable.
 * @module services/visionService
 */
const { ImageAnnotatorClient } = require('@google-cloud/vision');
const logger = require('../config/logger'); // Import logger

// Debug log to verify project ID and credentials
logger.debug('[VisionService] GOOGLE_CLOUD_PROJECT:', process.env.GOOGLE_CLOUD_PROJECT);
logger.debug('[VisionService] GOOGLE_APPLICATION_CREDENTIALS:', process.env.GOOGLE_APPLICATION_CREDENTIALS);

// Initialize Vision client (uses ADC by default)
const vision = new ImageAnnotatorClient();

/**
 * @async
 * @function detectTextInImage
 * @summary Detects text in an image using Google Cloud Vision API.
 * @description Takes either an image URL or an image buffer as input and sends it to the
 * Google Cloud Vision API for text detection. It processes the API response to extract
 * the full detected text, individual text blocks with their confidence scores and bounding boxes,
 * and an overall confidence score for the primary detection.
 * 
 * @param {string} [imageUrl] - The URL of the image to process. One of `imageUrl` or `imageBuffer` must be provided.
 * @param {Buffer} [imageBuffer] - A Buffer containing the image data. One of `imageUrl` or `imageBuffer` must be provided.
 * @returns {Promise<object>} A promise that resolves to an object containing the OCR results.
 *   @property {boolean} success - True if the API call was successful, false on error.
 *   @property {boolean} hasText - True if text was detected in the image, false otherwise.
 *   @property {string} extractedText - The full text extracted from the image. Empty if no text or error.
 *   @property {number} confidence - The confidence score (0-1) of the primary text detection (usually the full text block).
 *                                   0 if no text or error.
 *   @property {Array<object>} textBlocks - An array of objects, each representing a detected block of text (words, lines).
 *     Each block has:
 *     @property {string} text - The text content of the block.
 *     @property {number} confidence - The confidence score for this specific block.
 *     @property {object} [boundingBox] - The bounding box coordinates of the block within the image.
 *       @property {number} left - X-coordinate of the top-left corner.
 *       @property {number} top - Y-coordinate of the top-left corner.
 *       @property {number} right - X-coordinate of the bottom-right corner.
 *       @property {number} bottom - Y-coordinate of the bottom-right corner.
 *   @property {string} status - A simple status string: 'invoice' if text found (placeholder, actual invoice determination is by Gemini),
 *                               'no invoice' if no text found, or 'Error' on API failure.
 *   @property {string} [error] - An error message if `success` is false.
 */
async function detectTextInImage(imageUrl, imageBuffer) {
  let lastApiError = null;
  const maxRetries = 2; // Max 2 retries (total 3 attempts)
  const retryDelay = 1500; // 1.5 seconds delay

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      logger.info(`[VisionService] Attempting text detection (Attempt ${attempt + 1}/${maxRetries + 1}) for image: ${imageUrl || 'buffer'}`);
      const [result] = await vision.textDetection(imageBuffer || imageUrl);
      const detections = result.textAnnotations || [];
      
      logger.info('[VisionService] Text detection API call successful.');

      if (!detections.length) {
        logger.info('[VisionService] No text detected in image.');
        return {
          success: true,
          hasText: false,
          extractedText: '',
          confidence: 0,
          textBlocks: [],
          status: 'no invoice', // Consistent with original JSDoc, means no text for OCR stage
        };
      }
      const fullText = detections[0].description || '';
      const confidence = detections[0].confidence || 0;
      const textBlocks = detections.slice(1).map((block) => ({
        text: block.description || '',
        confidence: block.confidence || 0,
        boundingBox: block.boundingPoly?.vertices
          ? {
              left: Math.min(...block.boundingPoly.vertices.map((v) => v.x || 0)),
              top: Math.min(...block.boundingPoly.vertices.map((v) => v.y || 0)),
              right: Math.max(...block.boundingPoly.vertices.map((v) => v.x || 0)),
              bottom: Math.max(...block.boundingPoly.vertices.map((v) => v.y || 0)),
            }
          : undefined,
      }));
      logger.info('[VisionService] Text successfully extracted and processed.');
      return {
        success: true,
        hasText: true,
        extractedText: fullText,
        confidence,
        textBlocks,
        status: 'invoice', // Consistent with original JSDoc, means text found for OCR stage
      };
    } catch (error) {
      lastApiError = error;
      logger.error(`[VisionService] Text detection API call failed (Attempt ${attempt + 1}/${maxRetries + 1}):`, { message: error.message, stack: error.stack });
      if (attempt < maxRetries) {
        logger.info(`[VisionService] Retrying in ${retryDelay / 1000}s...`);
        await new Promise(resolve => setTimeout(resolve, retryDelay));
      } else {
        logger.error("[VisionService] Max retries reached for Vision API call.");
      }
    }
  }
  
  // If loop finished due to retries failing, lastApiError will be set
  logger.error('[VisionService] Error detecting text after all retries:', lastApiError);
  return {
    success: false,
    hasText: false,
    extractedText: '',
    confidence: 0,
    textBlocks: [],
    status: 'Error',
    error: lastApiError instanceof Error ? lastApiError.message : 'Unknown error occurred during Vision API call',
  };
}

module.exports = {
  detectTextInImage,
}; 