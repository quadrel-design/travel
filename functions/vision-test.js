const fs = require('fs');
const path = require('path');
const vision = require('@google-cloud/vision');

// Path to test invoice image
const imagePath = path.resolve('../assets/test/invoice-test.png');

// Initialize Vision API client
const client = new vision.ImageAnnotatorClient({
  keyFilename: "./splitbase-7ec0f-9618a4571647.json"
});

async function testVision() {
  try {
    console.log("Starting Vision API test with image:", imagePath);
    
    // Check if file exists
    if (!fs.existsSync(imagePath)) {
      console.error("Error: Test image not found at path:", imagePath);
      return;
    }
    
    console.log("Image exists, sending to Vision API...");
    
    // Perform OCR on the image
    const [result] = await client.textDetection(imagePath);
    const detections = result.textAnnotations || [];
    
    if (!detections.length) {
      console.log("No text detected in the image");
      return;
    }
    
    // Get the full text
    const fullText = detections[0].description || "";
    console.log("\nText extraction successful!");
    console.log(`Number of text blocks: ${detections.length - 1}`);
    console.log(`\nExtracted text:\n${fullText}`);
    
  } catch (error) {
    console.error("Error during Vision API test:", error);
  }
}

// Run the test
testVision(); 