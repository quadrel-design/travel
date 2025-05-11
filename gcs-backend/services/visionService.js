const { ImageAnnotatorClient } = require('@google-cloud/vision');

// Debug log to verify project ID and credentials
console.log('GOOGLE_CLOUD_PROJECT:', process.env.GOOGLE_CLOUD_PROJECT);
console.log('GOOGLE_APPLICATION_CREDENTIALS:', process.env.GOOGLE_APPLICATION_CREDENTIALS);

// Initialize Vision client (uses ADC by default)
const vision = new ImageAnnotatorClient();

async function detectTextInImage(imageUrl, imageBuffer) {
  try {
    const [result] = await vision.textDetection(imageBuffer || imageUrl);
    const detections = result.textAnnotations || [];
    if (!detections.length) {
      return {
        success: true,
        hasText: false,
        extractedText: '',
        confidence: 0,
        textBlocks: [],
        status: 'no invoice',
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
    return {
      success: true,
      hasText: true,
      extractedText: fullText,
      confidence,
      textBlocks,
      status: 'invoice',
    };
  } catch (error) {
    return {
      success: false,
      hasText: false,
      extractedText: '',
      confidence: 0,
      textBlocks: [],
      status: 'Error',
      error: error instanceof Error ? error.message : 'Unknown error occurred',
    };
  }
}

module.exports = {
  detectTextInImage,
}; 